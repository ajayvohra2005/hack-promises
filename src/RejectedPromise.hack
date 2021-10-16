namespace HackPromises;

/**
 * A promise that is rejected on construction.
 *
 * If you call 'then' method on this promise, it will trigger the 'rejected' callback
 * immediately, and ignore 'fulfilled' callback.
 */
class RejectedPromise implements PromiseInterface
{
    /** @var mixed Reason for rejection */
    private mixed $reason;

    /** @var ?Promise internal use*/
    private ?Promise $promise;

    /** @var ?ThenCallback 'rejected' callback */
    private ?ThenCallback $onRejected;

    /**
     * @param mixed $value Value to resolve the promise immediately. 
     */
    public function __construct(mixed $reason)
    {
        if ($reason is Promise) {
            throw new \InvalidArgumentException(
                'You cannot create a RejectedPromise with a promise.'
            );
        }

        $this->reason = $reason;
    }

    /**
     * Calling this method will immediately trigger the 'rejected' callbacks
     * 
     * @param ?ThenCallback $onFulfilled Optional 'fulfilled' callback.
     * @param ?ThenCallback $onRejected  Optional 'rejected' callback.
     *
     * @return PromiseInterface A new promise for promise chaining
     */
    public function then(
        ?ThenCallback $onFulfilled = null,
        ?ThenCallback $onRejected = null): PromiseInterface 
    {
        // If there's no onRejected callback then just return self.
        if (!$onRejected) {
            return $this;
        }

        $this->onRejected = $onRejected;

        $queue = TaskQueue::globalTaskQueue();
        $reason = $this->reason;
        $run_cb = (ResolveCallback $cb): void ==> {
            $queue->run();
        };

        $this->promise = new Promise($run_cb);
        $p = $this->promise;

        $task = (): void ==> {
             if (Is::pending($p)) {
                self::resolvePromise($p, $reason, $onRejected);
            }
        };

        $queue->add($task);

        return $p;
    }

    /**
     * Add the rejected callback.
     * 
     * @param ?ThenCallback $onRejected  The 'rejected' callback.
     *
     * @return PromiseInterface A new promise for promise chaining
     */
    public function otherwise(ThenCallback $onRejected): PromiseInterface
    {
        return $this->then(null, $onRejected);
    }

    /**
     * Call this method to synchronously resolve the promise.
     * 
     * @param bool $unwrap=true Pass false to not unwrap the promise
     *
     * @return mixed Unwrapped value
     */
    public function wait(bool $unwrap = true): mixed
    {
        if ($unwrap) {
            throw Create::exceptionFor($this->reason);
        }

        // Don't run the queue to avoid deadlocks, instead directly reject the promise.
        if ($this->promise && Is::pending($this->promise)) {
            
            if( $this->promise is Promise && $this->onRejected is nonnull) {
                self::resolvePromise($this->promise, $this->reason, $this->onRejected);
            }
        }

        return null;
    }

    /**
     * @return string Promise state, which is always 'rejected'
     */
    public function getState(): string
    {
        return self::REJECTED;
    }

    /**
     * Do not call this method. Promise is resolved on construction.
     * 
     * @param mixed $value Value to resolve the promise
     * @throws \LogicException "Cannot resolve a rejected promise"
     */
    public function resolve(mixed $value): void
    {
        throw new \LogicException("Cannot resolve a rejected promise");
    }

    /**
     * Do not call this method. Promise is rejected on construction.
     * 
     * @param mixed $value Value to resolve the promise
     * @throws \LogicException "Cannot reject a rejected promise"
     */
    public function reject(mixed $reason): void
    {
        if ($reason !== $this->reason) {
            throw new \LogicException("Cannot reject a rejected promise");
        }
    }

    /**
     * Calling this method has no effect.
     * 
     */
    public function cancel(): void
    {
        // pass
    }

    private static function resolvePromise(Promise $promise, mixed $reason, ThenCallback $callback): void
    {
        try {
            $promise->resolve($callback($reason));
        } catch (\Throwable $e) {
            $promise->reject($e);
        } 
    }
}
