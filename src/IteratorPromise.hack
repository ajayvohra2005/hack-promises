namespace HackPromises;

use namespace HH;
use namespace HH\Lib\Math;
use namespace HH\Lib\C;
use namespace HH\Lib\Vec;

/**
 * Represents an aggregated promise that iterates over an iterator of promises, or values, and triggers
 * callback functions in the process.
 */

type IteratorPromiseFunction = (function(mixed, arraykey, PromiseInterface): mixed);
type ConcurrencyFunction = (function(int): int);

type IteratorPromiseConfig = shape("fulfilled" => ?IteratorPromiseFunction, 
                            "rejected" => ?IteratorPromiseFunction, 
                            "concurrency" => ?ConcurrencyFunction);

class IteratorPromise implements PromisorInterface
{
    /** @var MutableDictIterator<int, PromiseInterface><int, PromiseInterface> */
    private MutableDictIterator<int, PromiseInterface> $pending;

    /** @var int Next pending index*/
    private int $nextPendingIndex = 0;

    /** @var HH\KeyedIterator<arraykey, mixed> Iterator */
    private ?HH\KeyedIterator<arraykey, mixed> $iterator;

    /** @var ?ConcurrencyFunction concurrency function */
    private ?ConcurrencyFunction $concurrency;

    /** @var ?EachPromiseFunction fulfilled callback */
    private ?IteratorPromiseFunction $onFulfilled;

    /** @var ?EachPromiseFunction rejected callback */
    private ?IteratorPromiseFunction $onRejected;

    /** @var ?Promise aggregated promise*/
    private ?PromiseInterface $aggregate;

    /** @var bool internal use */
    private bool $mutex = false;

    /**
     *
     * @param HH\KeyedIterator<arraykey, mixed> $iterator PromiseInterface or values to iterate.
     * @param ?EachPromiseConfig $config 'concurrency', 'fulfilled' and 'rejected' functions
     *                                  
     */
    public function __construct(HH\KeyedIterator<arraykey, mixed> $iterator, ?IteratorPromiseConfig $config=null)
    {
        $this->iterator = $iterator;
        $this->pending = new MutableDictIterator<int, PromiseInterface>(dict<int, Promise>[]);

        if($config) {
            $this->concurrency = $config['concurrency'];
            $this->onFulfilled = $config['fulfilled'];
            $this->onRejected = $config['rejected'];
        }
    }

    /**
     * Creates the aggregated promise, if not already created.
     * 
     * @return PromiseInterface  the aggregated promise
     */
    public function promise(): PromiseInterface
    {
        if ($this->aggregate is nonnull) {
            return $this->aggregate;
        }

        try {
            $this->createPromise();
            if (!$this->checkIfFinished()) {
                $this->refillPending();
            }
        } catch (\Throwable $e) {
            if($this->aggregate) {
                $this->aggregate->reject($e);
            }
        } 

        if($this->aggregate) {
            return $this->aggregate;
        }

        throw new \RuntimeException("Failed to create aggregate Promise");
    }

    private function waitOnPending(): void
    {
        $this->pending->rewind();
        $promise = ($this->pending->valid() ? $this->pending->current(): null);
        while ($promise is PromiseInterface) {
            $this->pending->next();
            $promise->wait();
            if ($this->aggregate is nonnull && Is::settled($this->aggregate)) {
                return;
            }
            $promise = ($this->pending->valid() ? $this->pending->current(): null);
        }
        
    }

    private function clearFunction(): void
    {
        $this->iterator = null;
        $this->concurrency = null;
        $this->pending = new MutableDictIterator<int, PromiseInterface>(dict<int, Promise>[]);
        $this->onFulfilled = null;
        $this->onRejected = null;
        $this->nextPendingIndex = 0;
    }

    private function createPromise(): void
    {
        $this->mutex = false;

        $wait_fn = (ResolveCallback $cb): void ==> {
            $this->waitOnPending();
        };

        $this->aggregate = new Promise($wait_fn);

        // Clear the references when the promise is resolved.
        $clearFn = (mixed $v): void ==> {
            $this->clearFunction();
        };

        $this->aggregate->then($clearFn, $clearFn);
    }

    private function refillPending(): void
    {
        if (!$this->concurrency) {
            // Add all pending promises.
            while ($this->addPending() && $this->advanceIterator());
            return;
        }

        // Add only up to N pending promises.
        $concurrency_cb = $this->concurrency;
        $concurrency_level = $concurrency_cb($this->pending->count());
        $concurrency_level = \max($concurrency_level - $this->pending->count(), 0);
        // Concurrency may be set to 0 to disallow new promises.
        if ($concurrency_level == 0) {
            return;
        }
        
        while ($this->addPending()) {
            --$concurrency_level;
            if($concurrency_level == 0 || !$this->advanceIterator()) {
                break;
            }
        }
    }

    private function addPending(): bool
    {
        $it = $this->iterator;
        if ($it is null || !$it->valid()) {
            return false;
        }

        $promise = Create::promiseFor($it->current());
        $key = $it->key();

        $idx = $this->nextPendingIndex;
        $this->nextPendingIndex++;

        $onFullfilledFn = (mixed $value): void ==> {
            if ($this->onFulfilled is nonnull && $this->aggregate is nonnull) {
                $fn = $this->onFulfilled;
                $ret=$fn($value, $key, $this->aggregate);
            }
            $this->step($idx);
        };

        $onRejectedFn = (mixed $reason): void ==> {
            if ($this->onRejected is nonnull && $this->aggregate is nonnull) {
                $fn = $this->onRejected;
                $ret=$fn($reason, $key, $this->aggregate);
            }
            $this->step($idx);
        };

        return $this->pending->add($idx, $promise->then($onFullfilledFn, $onRejectedFn));
    }

    private function advanceIterator(): bool
    {
        // Place a lock on the iterator so that we ensure to not recurse,
        // preventing fatal generator errors.
        if ($this->mutex) {
            return false;
        }
        $this->mutex = true;

        try {
            $it = $this->iterator;
            if($it is nonnull) {
                $it->next();
                $this->mutex = false;
                return true;
            }
        } catch (\Throwable $e) {
            if($this->aggregate) {
                $this->aggregate->reject($e);
            }
            $this->mutex = false;
        } 

        $this->mutex = false;
        return false;
    }

    private function step(int $idx): void
    {
        // If the promise was already resolved, then ignore this step.
        if ($this->aggregate && Is::settled($this->aggregate)) {
            return;
        }

        $this->pending->unset($idx);

        // Only refill pending promises if we are not locked, preventing the
        // EachPromise to recursively invoke the provided iterator, which
        // cause a fatal error: "Cannot resume an already running generator"
        if ($this->advanceIterator() && !$this->checkIfFinished()) {
            // Add more pending promises if possible.
            $this->refillPending();
        }
    }

    private function checkIfFinished(): bool
    {
        if ($this->pending->empty() &&  ($this->iterator == null || !$this->iterator->valid())) {
                if($this->aggregate is PromiseInterface) {
                    $this->aggregate->resolve(null);
                }
                return true;
        }

        return false;
    }

    /**
     * Given an iterator that yields promises or values, returns a promise that
     * is fulfilled with a null value when the iterator has been consumed, or
     * the aggregate promise has been fulfilled, or rejected.
     *
     * $onFulfilled is a function that accepts the fulfilled value, iterator
     * index, and the aggregate promise. The callback can invoke any necessary
     * side effects and choose to resolve or reject the aggregate if needed.
     *
     * $onRejected is a function that accepts the rejection reason, iterator
     * index, and the aggregate promise. The callback can invoke any necessary
     * side effects and choose to resolve or reject the aggregate if needed.
     *
     * @param HH\KeyedIterator<arraykey, mixed>    $iterator    Iterator to iterate over.
     * @param ?EachPromiseFunction $onFulfilled Callback for 'fulfilled'
     * @param ?EachPromiseFunction $onRejected Callback for 'rejected'
     *
     * @return PromiseInterface
     */
    public static function of(HH\KeyedIterator<arraykey, mixed> $iterator,
                            ?IteratorPromiseFunction $onFulfilled = null,
                            ?IteratorPromiseFunction $onRejected = null): PromiseInterface
    {
        $config = shape('fulfilled' => $onFulfilled, 'rejected' => $onRejected, 'concurrency' => null);
        return (new IteratorPromise($iterator, $config))->promise();
    }

    /**
     * Like of method, but only allows a certain number of outstanding promises at any
     * given time.
     *
     * $concurrency must be a function that accepts the number of
     * pending promises and returns a numeric concurrency limit value to allow
     * for dynamic a concurrency size.
     *
     * @param HH\KeyedIterator<arraykey, mixed>  $iterator Iterator to iterate over. 
     * @param ?ConcurrencyFunction $concurrency Concurrency function
     * @param ?EachPromiseFunction     $onFulfilled Callback for 'fulfilled'
     * @param ?EachPromiseFunction     $onRejected Callback for 'rejected'
     *
     * @return PromiseInterface
     */
    public static function ofLimit(
        HH\KeyedIterator<arraykey, mixed> $iterator,
        ?ConcurrencyFunction $concurrency,
        ?IteratorPromiseFunction $onFulfilled = null,
        ?IteratorPromiseFunction $onRejected = null): PromiseInterface 
    {
        $config = shape('fulfilled' => $onFulfilled, 'rejected' => $onRejected, 'concurrency' => $concurrency);
        return (new IteratorPromise($iterator, $config))->promise();
    }

    /**
     * Like limit, but ensures that no promise in the given $iterator argument
     * is rejected. If any promise is rejected, then the aggregate promise is
     * rejected with the encountered rejection.
     *
     * @param HH\KeyedIterator<arraykey, mixed> $iterator Iterator to iterate over. 
     * @param ?ConcurrencyFunction $concurrency Concurrency function
     * @param ?IteratorPromiseFunction     $onFulfilled $onFulfilled Callback for 'fulfilled'
     *
     * @return PromiseInterface
     */
    public static function ofLimitAll(
        HH\KeyedIterator<arraykey, mixed> $iterator,
        ?ConcurrencyFunction $concurrency,
        ?IteratorPromiseFunction $onFulfilled = null) : PromiseInterface
    {
        $onRejected = (mixed $reason, arraykey $idx, PromiseInterface $aggregate): mixed ==> $aggregate->reject($reason);
        return IteratorPromise::ofLimit($iterator,$concurrency, $onFulfilled,$onRejected);
    }

}
