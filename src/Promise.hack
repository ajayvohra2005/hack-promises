namespace HackPromises;

use namespace HH;
use namespace HH\Lib\Vec;
use namespace HH\Lib\C;

/**
 * Promises/A+ implementation that avoids recursion when possible.
 *
 * @link https://promisesaplus.com/
 */

class Promise implements PromiseInterface
{
     /** @var string state of promise*/
    private string $state = self::PENDING;

    /** @var result eventual result*/
    private mixed $result;

    /** @var ?WaitFunction optional wait function*/
    private ?WaitFunction $waitFn;

    /** @var ?WaitFunction optional cancle function*/
    private ?CancelFunction $cancelFn;

    /** @var vec<PromiseInterface> promise chain */
    private vec<PromiseInterface> $waitList = vec[];

    /** @var vec<PromiseInterface> handler chain */
    private vec<Handler> $handlers = vec[];

    /**
     * @param ?WaitFunction $waitFn  Callback function for when the 'wait' method is called. 
     * @param ?CancelFunction $cancelFn Callback function for when the 'cancel' method is called.
     */
    public function __construct(
        ?WaitFunction $waitFn = null,
        ?CancelFunction $cancelFn = null
    ) {
        $this->waitFn = $waitFn;
        $this->cancelFn = $cancelFn;
    }

    /**
     * @param ?ThenCallback $onFulfilled Optional 'fulfilled' callback.
     * @param ?ThenCallback $onRejected  Optional 'rejected' callback.
     *
     * @return PromiseInterface A new promise for promise chaining
     */
    public function then(
        ?ThenCallback $onFulfilled = null,
        ?ThenCallback $onRejected = null): PromiseInterface 
    {
        if ($this->state === self::PENDING) {
            $cancel_cb = (RejectCallback $cb): void ==> { $this->cancel(); return;};

            $p = new Promise(null, $cancel_cb);
            $this->handlers[] = new Handler($p, $onFulfilled, $onRejected);
            $p->waitList = $this->waitList;
            $p->waitList[] = $this;
            return $p;
        }

        // Return a fulfilled promise and immediately invoke any callbacks.
        if ($this->state === self::FULFILLED) {
            $promise = Create::promiseFor($this->result);
            return $onFulfilled ? $promise->then($onFulfilled) : $promise;
        }

        // It's either cancelled or rejected, so return a rejected promise
        // and immediately invoke any callbacks.
        $rejection = Create::rejectionFor($this->result);
        return $onRejected ? $rejection->then(null, $onRejected) : $rejection;
    }

    /**
     * @param ?ThenCallback $onRejected  Optional 'rejected' callback.
     *
     * @return PromiseInterface A new promise for promise chaining
     */
    public function otherwise(ThenCallback $onRejected): PromiseInterface
    {
        return $this->then(null, $onRejected);
    }

    /**
     * Call this method to synchronously resolve the promise,
     * if you constructed the promise with a 'wait' function.
     * 
     * @param bool $unwrap=true Pass false to not unwrap the promise
     *
     * @return mixed Unwrapped value
     */
    public function wait(bool $unwrap = true): mixed
    {
        $this->waitIfPending();

        if ($this->result is PromiseInterface) {
            return $this->result->wait($unwrap);
        }
        if ($unwrap) {
            if ($this->state === self::FULFILLED) {
                return $this->result;
            }
            // It's rejected so "unwrap" and throw an exception.
            throw Create::exceptionFor($this->result);
        }

        return null;
    }

    /**
     * @return string Promise state, one of 'fulfilled', 'rejected', or 'pending'
     */
    public function getState(): string
    {
        return $this->state;
    }

    /**
     * Call this method to synchronously cancel the promise.
     * 
     * @return void
     */
    public function cancel(): void
    {
        if ($this->state !== self::PENDING) {
            return;
        }

        $this->waitFn = null;
        $this->waitList = vec[];

        if ($this->cancelFn) {
            $fn = $this->cancelFn;
            $this->cancelFn = null;
            try {
                $reject_cb = (mixed $reason) ==> {
                    $this->reject($reason);
                    return;
                };
                $fn($reject_cb);
            } catch (\Throwable $e) {
                $this->reject($e);
            } 
        }

        if ($this->state === self::PENDING) {
            $this->reject(new CancellationException('Promise has been cancelled'));
        }
    }

    /**
     * Call this method to asynchronously resolve the promise.
     * 
     * @param mixed $value Value to resolve the promise
     * @return void
     */
    public function resolve(mixed $value): void
    {
        $this->settle(self::FULFILLED, $value);
    }

    /**
     * Call this method to asynchronously reject the promise.
     * 
     * @param mixed $reason Reason for rejecting the promise
     * @return void
     */
    public function reject(mixed $reason): void
    {
        $this->settle(self::REJECTED, $reason);
    }

    private function create_callbacks(vec<Handler> $handlers): ( ThenCallback, ThenCallback)
    {
        $fulfilled_cb = async (mixed $value): Awaitable<void> ==> {
                    foreach ($handlers as $handler) {
                        await self::callHandler(self::FULFILLED, $value, $handler);
                    }
                };

        $rejected_cb = async (mixed $reason): Awaitable<void> ==> {
                    foreach ($handlers as $handler) {
                        await self::callHandler(self::REJECTED, $reason, $handler);
                    }
                };

        return tuple($fulfilled_cb, $rejected_cb);
    }

    private function settle(string $state, mixed $value): void
    {
        if ($this->state !== self::PENDING) {
            // Ignore calls with the same resolution.
            if ($state === $this->state && $value === $this->result) {
                return;
            }
            throw $this->state === $state
                ? new \LogicException("The promise is already {$state}.")
                : new \LogicException("Cannot change a {$this->state} promise to {$state}");
        }

        if ($value === $this) {
            throw new \LogicException('Cannot fulfill or reject a promise with itself');
        }

        // Clear out the state of the promise but stash the handlers.
        $this->state = $state;
        $this->result = $value;
        $handlers = $this->handlers;
        $this->handlers = vec[];
        $this->waitList = vec[];
        $this->waitFn = null;
        $this->cancelFn = null;

        if (!$handlers) {
            return;
        }

        if ($value is Promise && Is::pending($value)) {
            // We can just merge our handlers onto the next promise.
            $value->handlers = vec(\array_merge($value->handlers, $handlers));
        } else if ($value is ThenableInterface) {
                // Resolve the handlers when the forwarded promise is resolved.
                $cbs = $this->create_callbacks($handlers);
                $fulfilled_cb = $cbs[0];
                $rejected_cb = $cbs[1];

                $value->then($fulfilled_cb , $rejected_cb);
        } else {
            // Resolve the handlers by running a task in the queue.
            $task = async (): Awaitable<void> ==> {
                foreach ($handlers as $handler) {
                    await self::callHandler($state, $value, $handler);
                }
            };

            TaskQueue::globalTaskQueue()->add($task);
        }
    }

    /**
     * Call a stack of handlers using a specific callback state and value.
     *
     * @param string  $state   "Fufilled", or "Rejected"
     * @param mixed $value   Value to pass to the callback.
     * @param Handler $handler Handler
     */
    private static async function callHandler(string $state, mixed $value, Handler $handler): Awaitable<void>
    {
        /** @var PromiseInterface $promise */
        $promise = $handler->getPromise();

        // The promise may have been cancelled or resolved before placing
        // this thunk in the queue.
        if (Is::settled($promise)) {
            return;
        }

        try {
            if($value is Awaitable<_>) {
                $value = await $value;
            }
            $callback = $handler->getCallback($state);

            if($callback is nonnull) {
                $promise->resolve($callback($value));
            } elseif($state == self::FULFILLED) {
                $promise->resolve($value);
            } else {
                $promise->reject($value);
            }

        } catch (\Throwable $reason) {
            $promise->reject($reason);
        } 
    }

    private function waitIfPending(): void
    {
        if ($this->state !== self::PENDING) {
            return;
        } elseif ($this->waitFn) {
            $this->invokeWaitFn();
        } elseif ($this->waitList) {
            $this->invokeWaitList();
        } else {
            // If there's no wait function, then reject the promise.
            $this->reject('Cannot wait on a promise that has '
                . 'no internal wait function. You must provide a wait '
                . 'function when constructing the promise to be able to '
                . 'wait on a promise.');
        }

        TaskQueue::globalTaskQueue()->run();

        /** @psalm-suppress RedundantCondition */
        if ($this->state === self::PENDING) {
            $this->reject('Invoking the wait callback did not resolve the promise');
        }
    }

    private function invokeWaitFn(): void
    {
        try {
            $wait_function = $this->waitFn;
            $this->waitFn = null;
            if($wait_function is nonnull) {
                $resolve_cb = (mixed $value): void ==> {
                    $this->resolve($value);
                    return;
                };
                $wait_function($resolve_cb);
            }

        } catch (\Exception $reason) {
            if ($this->state === self::PENDING) {
                // The promise has not been resolved yet, so reject the promise
                // with the exception.
                $this->reject($reason);
            } else {
                // The promise was already resolved, so there's a problem in
                // the application.
                throw $reason;
            }
        }
    }

    private function invokeWaitList(): void
    {
        $waitList = $this->waitList;
        $this->waitList = vec[];

        foreach ($waitList as $result) {
            while ($result is Promise) {
                $result->waitIfPending();
                $result = $result->result;
            } ;

            if ($result is PromiseInterface) {
                $result->wait(false);
            }
        }
    }

}
