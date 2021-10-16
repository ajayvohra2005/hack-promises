namespace HackPromises;

/**
 * A promise that is fulfilled on construction.
 *
 * If you call 'then' method on this promise, it will trigger the 'fulfilled' callback
 * immediately, and ignore 'rejected' callback.
 */
class FulfilledPromise implements PromiseInterface
{
    /** @var mixed resolved value*/
    private mixed $value;

    /** @var ?Promise internal use*/
    private ?Promise $promise;

    /** @var ?ThenCallback 'fulfilled' callback*/
    private ?ThenCallback $onFulfilled;

    /**
     * @param mixed $value Value to resolve the promise immediately. 
     */
    public function __construct(mixed $value)
    {
        if ($value is PromiseInterface) {
            throw new \InvalidArgumentException(
                'You cannot create a FulfilledPromise with a promise.'
            );
        }

        $this->value = $value;
    }

    /**
     * Calling this method will immediately trigger the 'fulfilled' callbacks
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
        // Return itself if there is no onFulfilled function.
        if (!$onFulfilled) {
            return $this;
        }

        $this->onFulfilled = $onFulfilled;

        $queue = TaskQueue::globalTaskQueue();

        $run_cb = (ResolveCallback $cb): void ==> {
            $queue->run();
        };

        $this->promise = new Promise($run_cb);
        $p = $this->promise;
        $value = $this->value;
        
        $task = (): void ==> {
            if (Is::pending($p)) {
                self::resolvePromise($p, $value, $onFulfilled);
            }
        };

        $queue->add($task);

        return $p;
    }

    /**
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
        // Don't run the queue to avoid deadlocks, instead directly resolve the promise.
        if ($this->promise && Is::pending($this->promise)) {
            if($this->promise is Promise && $this->onFulfilled is nonnull) {
                self::resolvePromise($this->promise, $this->value, $this->onFulfilled);
            }
        }

        return $unwrap ? $this->value : null;
    }

    /**
     * @return string Promise state, which is always'fulfilled'
     */
    public function getState(): string
    {
        return self::FULFILLED;
    }

    /**
     * Do not call this method. Promise is resolved on construction.
     * 
     * @param mixed $value Value to resolve the promise
     * @throws \LogicException "Cannot resolve a fulfilled promise"
     */
    public function resolve(mixed $value): void
    {
        if ($value !== $this->value) {
            throw new \LogicException("Cannot resolve a fulfilled promise");
        }
    }

    /**
     * Do not call this method. Promise is resolved on construction.
     * 
     * @param mixed $value Value to resolve the promise
     * @throws \LogicException "Cannot reject a fulfilled promise"
     */
    public function reject(mixed $reason): void
    {
        throw new \LogicException("Cannot reject a fulfilled promise");
    }

    /**
     * Calling this method has no effect.
     * 
     */
    public function cancel(): void
    {
        // pass
    }

    private static function resolvePromise(Promise $promise, mixed $value, ThenCallback $callback): void
    {
        try {
            $promise->resolve($callback($value));
        } catch (\Throwable $e) {
            $promise->reject($e);
        } 
    }
}
