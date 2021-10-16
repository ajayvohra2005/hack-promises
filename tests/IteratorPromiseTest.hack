namespace HackPromises\Tests;

use HackPromises as P;
use HackPromises\CancellationException;
use HackPromises\FulfilledPromise;
use HackPromises\IteratorPromise;
use HackPromises\PromiseInterface;
use HackPromises\Promise;
use HackPromises\RejectedPromise;
use HackPromises\RejectionException;

use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};

/**
 * @covers HackPromises\EachPromise
 */
class IteratorPromiseTest extends HackTest
{
    private static mixed $_called;
    private static vec<mixed> $_values = vec[];

    public function testReturnsSameInstance(): void
    {
        $each = new IteratorPromise(P\Create::iterFor(dict[]), 
            shape('fulfilled' => null, 'rejected' => null, 'concurrency' => (int $v): int ==> {return 100;}));
        expect($each->promise())->toBeSame($each->promise());
    }

    public function testResolvesInCaseOfAnEmptyList(): void
    {
        $values = P\Create::iterFor(dict[]);
        $each = new IteratorPromise($values);
        $p = $each->promise();
        expect($p->wait())->toBeNull();
        expect(P\Is::fulfilled($p))->toBeTrue();
    }

    public function testInvokesAllPromises(): void
    {
        $promises = vec<P\PromiseInterface>[ new Promise(),  new Promise(),  new Promise()];
        self::$_values = vec[];
        $each = new IteratorPromise(P\Create::iterFor($promises), shape(
            'rejected' => null,
            'concurrency' => null,
            'fulfilled' => (mixed $value, arraykey $key, PromiseInterface $p): void ==> {
                self::$_values[] = $value;
            }
        ));
        $p = $each->promise();
        $promises[0]->resolve('a');
        $promises[1]->resolve('c');
        $promises[2]->resolve('b');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_values)->toBeSame(vec['a', 'c', 'b']);
        expect(P\Is::fulfilled($p))->toBeTrue();
    }

    public function testIsWaitable(): void
    {
        $a = $this->createSelfResolvingPromise('a');
        $b = $this->createSelfResolvingPromise('b');
        self::$_values = vec[];
        $each = new IteratorPromise(P\Create::iterFor(vec<PromiseInterface>[ $a, $b]), shape(
            'fulfilled' => (mixed $value, arraykey $key, PromiseInterface $p): void ==> 
            { self::$_values[] = $value; },
            'rejected' => null,
            'concurrency' => null
        ));
        $p = $each->promise();
        expect($p->wait())->toBeNull();
        expect(P\Is::fulfilled($p))->toBeTrue();
        expect(self::$_values)->toBeSame(vec['a', 'b']);
    }

    public function testCanResolveBeforeConsumingAll(): void
    {
        self::$_called = 0;
        $a = $this->createSelfResolvingPromise('a');
        $b = new Promise( (P\ResolveCallback $cb): void ==> {  });
        $each = new IteratorPromise(P\Create::iterFor(vec<PromiseInterface>[$a, $b]), 
        shape(
            'fulfilled' => (mixed $value, arraykey $idx, PromiseInterface $aggregate): void ==> {
                expect($idx)->toBeSame(0);
                expect($value)->toBeSame('a');
                $aggregate->resolve(null);
                if(self::$_called is int) {
                    self::$_called++;
                }
            },
            'rejected' => null,
            'concurrency' => null
        ));
        $p = $each->promise();
        expect($p->wait())->toBeNull();
        expect(self::$_called)->toBeSame(1);
        expect(P\Is::fulfilled($a))->toBeTrue();
        expect(P\Is::pending($b))->toBeTrue();
        // Resolving $b has no effect on the aggregate promise.
        $b->resolve('foo');
        expect(self::$_called)->toBeSame(1);
    }

    public function testClearsReferencesWhenResolved(): void
    {
        self::$_called = false;
        $a = new Promise((P\ResolveCallback $cb): void ==> {
            $cb('a');
            self::$_called = true;
        });
        $each = new IteratorPromise(P\Create::iterFor(vec[$a]), shape(
            'concurrency' => (int $i): int ==> { return 1; },
            'fulfilled' => (mixed $value, arraykey $key, PromiseInterface $p): void ==>  {},
            'rejected'  => (mixed $value, arraykey $key, PromiseInterface $p): void ==>  {}
        ));
        $each->promise()->wait();
        expect(self::$_called)->toBeTrue();
    }

    public function testCanBeCancelled(): void
    {
        self::$_called = false;
        $a = new FulfilledPromise('a');
        $b = new Promise((P\ResolveCallback $cb) ==> { self::$_called = true; });
        $each = new IteratorPromise(P\Create::iterFor(vec<PromiseInterface>[$a, $b]), shape(
            'fulfilled' => (mixed $value, arraykey $idx, PromiseInterface $aggregate): void ==> {
                $aggregate->cancel();
            },
            'rejected' => (mixed $reason, arraykey $idx, PromiseInterface $aggregate): void ==> {
                self::$_called = true;
            },
            'concurrency' => null
        ));
        $p = $each->promise();
        $p->wait(false);
        expect(P\Is::fulfilled($a))->toBeTrue();
        expect(P\Is::pending($b))->toBeTrue();
        expect(P\Is::rejected($p))->toBeTrue();
        expect(self::$_called)->toBeFalse();
    }

    public function testDoesNotBlowStackWithFulfilledPromises(): void
    {
        $pending = vec[];
        for ($i = 0; $i < 100; $i++) {
            $pending[] = new FulfilledPromise($i);
        }
        self::$_values = vec[];
        $each = new IteratorPromise(P\Create::iterFor($pending), shape(
            'fulfilled' => (mixed $value, arraykey $idx, PromiseInterface $aggregate): void ==> {
                self::$_values[] = $value;
            },
            'rejected' => null,
            'concurrency' => null
        ));
        self::$_called = false;
        $each->promise()->then( (mixed $value): void ==> {self::$_called = true;});
        expect(self::$_called)->toBeFalse();
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_called)->toBeTrue();
        expect(self::$_values)->toNotBeEmpty();
    }

    public function testDoesNotBlowStackWithRejectedPromises(): void
    {
        $pending = vec[];
        for ($i = 0; $i < 100; $i++) {
            $pending[] = new RejectedPromise($i);
        }
        self::$_values = vec[];
        $each = new IteratorPromise(P\Create::iterFor($pending), shape(
            'rejected' => (mixed $reason, arraykey $k, PromiseInterface $p) : void ==> {
                self::$_values[] = $reason;
            },
            'fulfilled' => null,
            'concurrency' => null
        ));
        self::$_called = false;
        $each->promise()->then(
            (mixed $value): void ==> { self::$_called = true; },
            (mixed $reason): void ==> { throw new \RuntimeException("Should not have rejected"); }
        );
        expect(self::$_called)->toBeFalse();
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_called)->toBeTrue();
        expect(self::$_values)->toNotBeEmpty();
    }

    public function testReturnsPromiseForWhatever(): void
    {
        self::$_values = vec[];
        $arr = vec['a', 'b'];
        $each = new IteratorPromise(P\Create::iterFor($arr), shape(
            'fulfilled' => (mixed $value, arraykey $k, PromiseInterface $p) : void ==> 
                { self::$_values[] = $value; },
            'rejected' => null,
            'concurrency' => null
        ));
        $p = $each->promise();
        expect($p->wait())->toBeNull();
        expect( self::$_values)->toBeSame(vec['a', 'b']);
    }

    private function createSelfResolvingPromise(mixed $value): Promise
    {
        $p = new Promise((P\ResolveCallback $cb) : void ==> {$cb($value);});
        return $p;
    }

    public function testIsWaitableWhenLimited(): void
    {
        $promises = vec[
            $this->createSelfResolvingPromise('a'),
            $this->createSelfResolvingPromise('c'),
            $this->createSelfResolvingPromise('b'),
            $this->createSelfResolvingPromise('d')
        ];
        self::$_values = vec[];
        $each = new IteratorPromise(P\Create::iterFor($promises), shape(
            'concurrency' => (int $i): int ==> { return 2;},
            'fulfilled' => (mixed $value, arraykey $key, PromiseInterface $p): void ==> {
                self::$_values[] = $value;
            },
            'rejected' => null
        ));
        $p = $each->promise();
        expect($p->wait())->toBeNull();
        expect(self::$_values)->toBeSame(vec['a', 'c', 'b', 'd']);
        expect(P\Is::fulfilled($p))->toBeTrue();
    }

    public function testCallsEachLimit(): void
    {
        $p = new Promise();
        $aggregate = IteratorPromise::ofLimit( new P\DictIterator<int, PromiseInterface>(dict<int, PromiseInterface>[ 0 => $p]), (int $i): int ==> {return 2;});
        $p->resolve('a');
        P\TaskQueue::globalTaskQueue()->run();
        expect(P\Is::fulfilled($aggregate))->toBeTrue();
    }

    public function testEachLimitAllRejectsOnFailure(): void
    {
        $p = dict<int, PromiseInterface>[0 => new FulfilledPromise('a'), 1 => new RejectedPromise('b')];
        $aggregate = IteratorPromise::ofLimitAll( new P\DictIterator<int, PromiseInterface>($p), (int $i): int ==> {return 2;});

        P\TaskQueue::globalTaskQueue()->run();
        expect(P\Is::rejected($aggregate))->toBeTrue();
    }
}
