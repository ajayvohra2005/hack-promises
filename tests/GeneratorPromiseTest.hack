namespace HackPromises\Tests;

use HackPromises as P;
use HackPromises\CancellationException;
use HackPromises\GeneratorPromise;
use HackPromises\Promise;
use HackPromises\RejectionException;

use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};

use Generator;

class GeneratorPromiseTest extends HackTest
{
    private static mixed $_result;

    public function testReturnsGeneratorPromise(): void
    {
        $fn = (): Generator<arraykey, mixed, mixed>  ==> { yield 'foo'; };
        expect(GeneratorPromise::of($fn))->toBeInstanceOf(GeneratorPromise::class);
    }

    public function testWaitShouldResolveChainedGenerators(): void
    {
        $promisor =  (mixed $value): mixed ==> {
            return P\GeneratorPromise::of( () : Generator<arraykey, mixed, mixed> ==> {
                $promise = new Promise( (P\ResolveCallback $cb): void ==> {
                    $cb(1);
                });
                yield $promise;
            });
        };

        $promise = $promisor(null);
        
        if($promise is P\PromiseInterface) {
            $promise->then($promisor)->then($promisor);
             expect($promise->wait())->toBeSame(1);
        }
       
    }

    public function testWaitShouldHandleIntermediateErrors(): void
    {
        $promise = P\GeneratorPromise::of(() : Generator<arraykey, mixed, mixed> ==> {
            $promise = new Promise((P\ResolveCallback $cb): void ==>  {
                $cb(1);
            });
            yield $promise;
        })->then( (mixed $value): mixed ==> {
            return P\GeneratorPromise::of(() : Generator<arraykey, mixed, mixed> ==> {
                $promise = new Promise((P\ResolveCallback $cb): void ==> {
                    throw new \RuntimeException("Error");
                });
                yield $promise;
            });
        })
        ->otherwise( (mixed $reason): mixed ==> {
            if (!$reason) {
                throw new \RuntimeException(" 'Error' did not propagate.");
            }
            return 3;
        });

        expect($promise->wait())->toBeSame(3);
    }

    public function testCanYieldErrorsAndSuccessesWithoutRecursion(): void
    {
        $promises = vec[];
        for ($i = 0; $i < 20; $i++) {
            $promises[] = new Promise();
        }

        $gen = GeneratorPromise::of((): Generator<arraykey, mixed, mixed>  ==> {
            for ($i = 0; $i < 20; $i += 4) {
                try {
                    yield $promises[$i];
                    yield $promises[$i + 1];
                } catch (\Exception $e) {
                    yield $promises[$i + 2];
                    yield $promises[$i + 3];
                }
            }
        });

        for ($i = 0; $i < 20; $i += 4) {
            $promises[$i]->resolve($i);
            $promises[$i + 1]->reject($i + 1);
            $promises[$i + 2]->resolve($i + 2);
            $promises[$i + 3]->resolve($i + 3);
        }

        $gen->then( (mixed $value): void ==> { self::$_result = $value; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_result)->toBeSame(19);
    }
}
