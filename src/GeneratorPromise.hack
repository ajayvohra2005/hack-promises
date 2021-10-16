
namespace HackPromises;

use Generator;
use Throwable;

/**
 * Creates a promise that wraps generator that yields values, or
 * promises.
 *
 * @param $generatorFn Generator function to wrap into a promise.
 *
 * @return PromiseInterface
 *
 */

 type GeneratorFunction = (function():Generator<arraykey, mixed, mixed>);

final class GeneratorPromise implements PromiseInterface
{
    /**
     * @var ?PromiseInterface the wrapper promise
     */
    private ?PromiseInterface $currentPromise;

    /**
     * @var Generator generator function
     */
    private Generator<arraykey, mixed, mixed> $generator;

    /**
     * @var Promise result 
     */
    private Promise $result;

    /**
     * @param $generatorFn Generator function to wrap into a promise.
     */
    public function __construct(GeneratorFunction $generatorFn)
    {
        $this->generator = $generatorFn();
        $wait_fn = (ResolveCallback $cb): void ==> {
            $this->waitForCurrentPromise();
        };

        $this->result = new Promise($wait_fn);
        try {
            $this->generator->next();
            $nextYielded = $this->generator->current();
            $this->nextPromise($nextYielded);
        } catch (Throwable $throwable) {
            $this->result->reject($throwable);
        }
    }

    private function waitForCurrentPromise(): void 
    {
        while ($this->currentPromise is nonnull) {
            $this->currentPromise->wait();
        }
    }

    /**
     * Create a new GeneratorPromise for a generator function
     *
     * @return PromiseInterface
     */
    public static function of(GeneratorFunction $generatorFn): PromiseInterface
    {
        return new GeneratorPromise($generatorFn);
    }

     public function then(
        ?ThenCallback $onFulfilled = null,
        ?ThenCallback $onRejected = null): PromiseInterface 
    { 
        return $this->result->then($onFulfilled, $onRejected);
    }

    public function otherwise(ThenCallback $onRejected): PromiseInterface
    {
        return $this->result->otherwise($onRejected);
    }

    public function wait(bool $unwrap = true): mixed
    {
        return $this->result->wait($unwrap);
    }

    public function getState(): string
    {
        return $this->result->getState();
    }

    public function resolve(mixed $value): void
    {
        $this->result->resolve($value);
    }

    public function reject(mixed $reason): void
    {
        $this->result->reject($reason);
    }

    public function cancel(): void
    {
        if($this->currentPromise is nonnull) {
            $this->currentPromise->cancel();
        }

        $this->result->cancel();
    }

    private function nextPromise(mixed $yielded): void 
    {
        $onFulfilled = (mixed $value): mixed ==> {
                $this->_handleSuccess($value);
                return null;
            };

        $onRejected = (mixed $reason): mixed ==> {
                $this->_handleFailure($reason);
                return null;
            };

        $this->currentPromise = Create::promiseFor($yielded)
                ->then($onFulfilled, $onRejected);
    }
    /**
     * @internal
     */
    public function _handleSuccess(mixed $value): void
    {
        $this->currentPromise = null;
        try {
            $this->generator->send($value);
            $nextYielded = $this->generator->current();
            if ($this->generator->valid()) {
                $this->nextPromise($nextYielded);
            } else {
                $this->result->resolve($value);
            }
        } catch (Throwable $throwable) {
            $this->result->reject($throwable);
        }
    }

    /**
     * @internal
     */
    public function _handleFailure(mixed $reason): void
    {
        $this->currentPromise = null;
        try {
            $this->generator->raise(Create::exceptionFor($reason));
            // The throw was caught, so keep iterating on the generator
            $nextYielded = $this->generator->current();
            $this->nextPromise($nextYielded);
        } catch (Throwable $throwable) {
            $this->result->reject($throwable);
        }

    }
}
