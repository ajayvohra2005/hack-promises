
namespace HackPromises\Tests;

use HackPromises as P;
use HackPromises\CancellationException;
use HackPromises\FulfilledPromise;
use HackPromises\Promise;
use HackPromises\RejectedPromise;
use HackPromises\RejectionException;

use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};

/**
 * @covers HackPromises\Promise
 */
class PromiseTest extends HackTest
{
    private static mixed $_value;
    private static mixed $_value2;
    private static mixed $_value3;
    private static vec<mixed> $res = vec[];

    /**
     * @expectedException \LogicException
     * @expectedExceptionMessage The promise is already fulfilled
     */
    public function testCannotResolveNonPendingPromise(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        expect(() ==> $p->resolve('bar'))->toThrow(\LogicException::class, 
            'The promise is already fulfilled');
    }

    public function testCanResolveWithSameValue(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        $p->resolve('foo');
        $result = $p->wait();
        expect($result)->toBeSame("foo");
    }

    /**
     * @expectedException \LogicException
     * @expectedExceptionMessage Cannot change a fulfilled promise to rejected
     */
    public function testCannotRejectNonPendingPromise(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        expect(() ==> $p->reject('bar'))->toThrow(\LogicException::class, 
            'Cannot change a fulfilled promise to rejected');
    }

    public function testCanRejectWithSameValue(): void
    {
        $p = new Promise();
        $p->reject('foo');
        $p->reject('foo');
        expect(P\Is::rejected($p))->toBeTrue();
    }

    /**
     * @expectedException \LogicException
     * @expectedExceptionMessage Cannot change a fulfilled promise to rejected
     */
    public function testCannotRejectResolveWithSameValue(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        expect(() ==> $p->reject('foo'))->toThrow(\LogicException::class, 
            'Cannot change a fulfilled promise to rejected');
    }

    public function testInvokesWaitFunction(): void
    {
        $p = new Promise( (P\ResolveCallback $cb): void  ==> { $cb('10'); });
        expect($p->wait(true))->toBeSame('10');
    }

    /**
     * @expectedException HackPromises\RejectionException
     * @expectedExceptionMessage The promise was rejected with reason: Invoking the wait callback did not resolve the promise
     */
    public function testRejectsAndThrowsWhenWaitFailsToResolve(): void
    {
        $p = new Promise((P\ResolveCallback $cb): void  ==> { });
        expect(() ==>  $p->wait())->toThrow(P\RejectionException::class, 
            'The promise was rejected with reason: Invoking the wait callback did not resolve the promise');
    }


    public function testRejectsSelfWhenWaitThrows(): void
    {
        $e = new \UnexpectedValueException('foo');
        $p = new Promise((P\ResolveCallback $cb): void  ==> {throw $e; });
        
        try {
            $p->wait();
        } catch (\UnexpectedValueException $e) {
            expect(P\Is::rejected($p))->toBeTrue();
        }
    }

    public function testWaitsOnNestedPromises(): void
    {
        $p1 = new Promise((P\ResolveCallback $cb): void  ==> { $cb('_'); });
        $p2 = new Promise((P\ResolveCallback $cb): void  ==> { $cb('foo'); });
        $p3 = $p1->then( (mixed $value): mixed ==> { return $p2; });
        expect($p3->wait())->toBeSame('foo');
    }

    /**
     * @expectedException HackPromises\RejectionException
     */
    public function testThrowsWhenWaitingOnPromiseWithNoWaitFunction(): void
    {
        $p = new Promise();
        expect(() ==>  $p->wait())->toThrow(P\RejectionException::class, 
            'The promise was rejected with reason: Cannot wait on a promise that has no internal wait function. You must provide a wait function when constructing the promise to be able to wait on a promise.');
    }


    public function testCannotCancelNonPending(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        $p->cancel();
        expect(P\Is::fulfilled($p))->toBeTrue();
    }

    /**
     * @expectedException HackPromises\CancellationException
     */
    public function testCancelsPromiseWhenNoCancelFunction(): void
    {
        $p = new Promise();
        $p->cancel();
        expect(P\Is::rejected($p))->toBeTrue();
        expect(() ==>  $p->wait())->toThrow(P\RejectionException::class, 
            'The promise was rejected with reason: Promise has been cancelled');
    }

    public function testCancelsPromiseWithCancelFunction(): void
    {
        self::$_value = false;
        $p = new Promise(null, (P\RejectCallback $cb): void ==> { self::$_value = true; });
        $p->cancel();
        expect(P\Is::rejected($p))->toBeTrue();
        expect(self::$_value)->toBeTrue();
    }

    public function testCancelsUppermostPendingPromise(): void
    {
        self::$_value = false;
        $p1 = new Promise(null, (P\RejectCallback $cb): void ==>  { self::$_value = true; });
        $p2 = $p1->then((mixed $value): void ==> {});
        $p3 = $p2->then((mixed $value): void ==> {});
        $p4 = $p3->then((mixed $value): void ==> {});
        $p3->cancel();
        expect(P\Is::rejected($p1))->toBeTrue();
        expect(P\Is::rejected($p2))->toBeTrue();
        expect(P\Is::rejected($p3))->toBeTrue();
        expect(P\Is::pending($p4))->toBeTrue();
        expect(self::$_value)->toBeTrue();

        try {
            $p3->wait();
        } catch (CancellationException $e) {
            expect($e->getMessage())->toContainSubstring('cancelled');
        }

        try {
            $p4->wait();
        } catch (CancellationException $e) {
            expect($e->getMessage())->toContainSubstring('cancelled');
        }

        expect(P\Is::rejected($p4))->toBeTrue();
    }

    public function testCancelsChildPromises(): void
    {
        self::$_value = false;
        self::$_value2 = false;
        self::$_value3 = false;
        $p1 = new Promise(null, (P\RejectCallback $cb): void ==>   { self::$_value = true; });
        $p2 = new Promise(null, (P\RejectCallback $cb): void ==>   { self::$_value2 = true; });
        $p3 = new Promise(null, (P\RejectCallback $cb): void ==>   { self::$_value3 = true; });
        $p4 = $p2->then( (mixed $value): mixed ==>  { return $p3; });
        $p4->cancel();
        expect(P\Is::pending($p1))->toBeTrue();
        expect(P\Is::rejected($p2))->toBeTrue();
        expect(P\Is::pending($p3))->toBeTrue();
        expect(P\Is::rejected($p4))->toBeTrue();
        expect(self::$_value)->toBeFalse();
        expect(self::$_value2)->toBeTrue();
        expect(self::$_value3)->toBeFalse();
    }

    public function testRejectsPromiseWhenCancelFails(): void
    {
        self::$_value = false;
        $p = new Promise(null, (P\RejectCallback $cb): void ==>    {
            self::$_value = true;
            throw new \Exception('e');
        });
        $p->cancel();
        expect(P\Is::rejected($p))->toBeTrue();
        expect(self::$_value)->toBeTrue();
        try {
            $p->wait();
        } catch (\Exception $e) {
            expect($e->getMessage())->toBeSame('e');
        }
    }

    public function testCreatesPromiseWhenFulfilledAfterThen(): void
    {
        $p = new Promise();
        self::$_value = null;
        $p2 = $p->then((mixed $v): void ==> { self::$_value = $v; });
        expect($p)->toNotBeSame($p2);
        $p->resolve('foo');
        P\TaskQueue::globalTaskQueue()->run();

        expect(self::$_value)->toBeSame('foo');
    }

    public function testCreatesPromiseWhenFulfilledBeforeThen(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        self::$_value = null;
        $p2 = $p->then((mixed $v): void ==> { self::$_value = $v; });
        expect($p)->toNotBeSame($p2);
        expect(self::$_value)->toBeNull();
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
    }

    public function testCreatesPromiseWhenFulfilledWithNoCallback(): void
    {
        $p = new Promise();
        $p->resolve('foo');
        $p2 = $p->then();
        expect($p)->toNotBeSame($p2);
        expect($p2)->toBeInstanceOf(FulfilledPromise::class);
    }

    public function testCreatesPromiseWhenRejectedAfterThen(): void
    {
        $p = new Promise();
        self::$_value = null;
        $p2 = $p->then(null, (mixed $v): void ==> { self::$_value = $v; });
        expect($p)->toNotBeSame($p2);
        $p->reject('foo');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
    }

    public function testCreatesPromiseWhenRejectedBeforeThen(): void
    {
        $p = new Promise();
        $p->reject('foo');
        self::$_value = null;
        $p2 = $p->then(null, (mixed $v): void ==> { self::$_value = $v; });
        expect($p)->toNotBeSame($p2);
        expect(self::$_value)->toBeNull();
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
    }

    public function testCreatesPromiseWhenRejectedWithNoCallback(): void
    {
        $p = new Promise();
        $p->reject('foo');
        $p2 = $p->then();
        expect($p)->toNotBeSame($p2);
        expect($p2)->toBeInstanceOf(RejectedPromise::class);
    }

    public function testInvokesWaitFnsForThens(): void
    {
        $p = new Promise( (P\ResolveCallback $cb): void ==> { $cb('a'); });
        $p2 = $p
            ->then( (mixed $v): mixed ==> { return ((string)$v) . '-1-'; })
            ->then( (mixed $v): mixed ==> { return ((string)$v) . '2'; });
        expect($p2->wait())->toBeSame('a-1-2');
    }

    public function testStacksThenWaitFunctions(): void
    {
        $p1 = new Promise( (P\ResolveCallback $cb): void ==> { $cb('a'); });
        $p2 = new Promise( (P\ResolveCallback $cb): void ==> { $cb('b'); });
        $p3 = new Promise((P\ResolveCallback $cb): void ==>  { $cb('c'); });
        $p4 = $p1
            ->then( (mixed $v): mixed ==> { return $p2; })
            ->then( (mixed $v): mixed ==> { return $p3; });
        expect($p4->wait())->toBeSame('c');
    }

    public function testForwardsFulfilledDownChainBetweenGaps(): void
    {
        $p = new Promise();
        self::$_value = null;
        self::$_value2 = null;
        $p->then(null, null)
            ->then( (mixed $v): mixed ==> { self::$_value = $v; return ((string)$v) . '2'; })
            ->then( (mixed $v): void ==> { self::$_value2 = $v; });
        $p->resolve('foo');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
        expect(self::$_value2)->toBeSame('foo2');
    }

    public function testForwardsRejectedPromisesDownChainBetweenGaps(): void
    {
        $p = new Promise();
        self::$_value = null;
        self::$_value2 = null;
        $p->then(null, null)
            ->then(null, (mixed $v): mixed ==>  { self::$_value = $v; return ((string)$v) . '2'; })
            ->then( (mixed $v): void ==> { self::$_value2 = $v; });
        $p->reject('foo');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
        expect(self::$_value2)->toBeSame('foo2');
    }

    public function testForwardsThrownPromisesDownChainBetweenGaps(): void
    {
        $e = new \Exception();
        $p = new Promise();
        self::$_value = null;
        self::$_value2 = null;
        $p->then(null, null)
            ->then(null, (mixed $v): void ==> {
                self::$_value = $v;
                throw $e;
            })
            ->then(
                null,
                (mixed $v): void ==> { self::$_value2 = $v; }
            );
        $p->reject('foo');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
        expect(self::$_value2)->toBeSame($e);
    }

    public function testForwardsReturnedRejectedPromisesDownChainBetweenGaps(): void
    {
        $p = new Promise();
        $rejected = new RejectedPromise('bar');
        self::$_value = null;
        self::$_value2 = null;
        $p->then(null, null)
            ->then(null, (mixed $v): mixed ==>  {
                self::$_value = $v;
                return $rejected;
            })
            ->then(
                null,
                (mixed $v): void ==>  { self::$_value2 = $v; }
            );
        $p->reject('foo');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
        expect(self::$_value2)->toBeSame('bar');

        try {
            $p->wait();
        } catch (RejectionException $e) {
            expect($e->getReason())->toBeSame('foo');
        }
    }

    public function testForwardsHandlersToNextPromise(): void
    {
        $p = new Promise();
        $p2 = new Promise();
        self::$_value = null;
        $p
            ->then( (mixed $v): mixed ==> { return $p2; })
            ->then( (mixed $value): void ==> { self::$_value = $value; });
        $p->resolve('a');
        $p2->resolve('b');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('b');
    }

    public function testRemovesReferenceFromChildWhenParentWaitedUpon(): void
    {
        self::$_value = null;
        $p = new Promise((P\ResolveCallback $cb): void ==> { $cb('a'); });
        $p2 = new Promise((P\ResolveCallback $cb): void ==> { $cb('b'); });
        $pb = $p->then(
            (mixed $v) : mixed ==> {
                self::$_value = $v;
                return $p2;
            }
        )
            ->then((mixed $v): mixed ==> {  return (string)$v . '.'; });

        expect($p->wait())->toBeSame('a');
        expect($p2->wait())->toBeSame('b');
        expect($pb->wait())->toBeSame('b.');
        expect(self::$_value)->toBeSame('a');
    }

    public function testForwardsHandlersWhenFulfilledPromiseIsReturned(): void
    {
        self::$res = vec[] ;
        $p = new Promise();
        $p2 = new Promise();
        $p2->resolve('foo');
        $p2->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'A:' . ((string)$v); });
        // $res is A:foo
        $p
            ->then((mixed $v): mixed ==>  { $v = (string)$v; self::$res[] = 'B'; return $p2; })
            ->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'C:' . $v; });
        $p->resolve('a');
        $p->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'D:' . $v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$res)->toBeSame(vec['A:foo', 'B', 'D:a', 'C:foo']);
    }

    public function testForwardsHandlersWhenRejectedPromiseIsReturned(): void
    {
        self::$res = vec[] ;
        $p = new Promise();
        $p2 = new Promise();
        $p2->reject('foo');
        $p2->then(null, (mixed $v): void ==> { $v = (string)$v; self::$res[] = 'A:' . (string)$v; });
        $p->then(null, (mixed $v): mixed ==>  { $v = (string)$v; self::$res[] = 'B'; return $p2; })
            ->then(null, (mixed $v): void ==> { $v = (string)$v; self::$res[] = 'C:' . (string)$v; });
        $p->reject('a');
        $p->then(null, (mixed $v): void ==> { $v = (string)$v; self::$res[] = 'D:' . (string)$v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$res)->toBeSame(vec['A:foo', 'B', 'D:a', 'C:foo']);
    }

    public function testDoesNotForwardRejectedPromise(): void
    {
        self::$res = vec[] ;
        $p = new Promise();
        $p2 = new Promise();
        $p2->cancel();
        $p2->then((mixed $v): mixed ==> { $v = (string)$v; self::$res[] = "B:{$v}"; return $v; });
        $p->then((mixed $v): mixed ==>  { $v = (string)$v; self::$res[] = "B:$v"; return $p2; })
            ->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'C:' . $v; });
        $p->resolve('a');
        $p->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'D:' . $v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect( self::$res)->toBeSame(vec['B:a', 'D:a']);
    }

    public function testRecursivelyForwardsWhenOnlyThennable(): void
    {
        self::$res = vec[] ;
        $p = new Promise();
        $p2 = new Thenable();
        $p2->resolve('foo');
        $p2->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'A:' . $v; });
        $p->then((mixed $v): mixed ==>  { $v = (string)$v; self::$res[] = 'B'; return $p2; })
            ->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'C:' . $v; });
        $p->resolve('a');
        $p->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'D:' . $v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$res)->toBeSame(vec['A:foo', 'B', 'D:a', 'C:foo']);
    }

    public function testRecursivelyForwardsWhenNotInstanceOfPromise(): void
    {
        self::$res = vec[] ;
        $p = new Promise();
        $p2 = new NotPromiseInstance();
        $p2->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'A:' . $v; });
        $p->then((mixed $v): mixed ==>  { $v = (string)$v; self::$res[] = 'B'; return $p2; })
            ->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'C:' . $v; });
        $p->resolve('a');
        $p->then((mixed $v): void ==> { $v = (string)$v; self::$res[] = 'D:' . $v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$res)->toBeSame(vec['B', 'D:a']);
        $p2->resolve('foo');
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$res)->toBeSame(vec['B', 'D:a', 'A:foo', 'C:foo']);
    }

    public function testCannotResolveWithSelf(): void
    {
        $p = new Promise();
        expect( () ==> $p->resolve($p))->toThrow(\LogicException::class, 
            'Cannot fulfill or reject a promise with itself');
    }

    public function testCannotRejectWithSelf(): void
    {
        $p = new Promise();
        expect( () ==> $p->reject($p))->toThrow(\LogicException::class, 
            'Cannot fulfill or reject a promise with itself');
    }

    public function testDoesNotBlowStackWhenWaitingOnNestedThens(): void
    {
        $inner = new Promise((P\ResolveCallback $cb) ==> { $cb(0); });
        $prev = $inner;
        for ($i = 1; $i < 100; $i++) {
            $prev = $prev->then((mixed $i): mixed ==> { return (int)$i + 1; });
        }

        $parent = new Promise( (P\ResolveCallback $cb) ==>   {$cb($prev);});

        expect($parent->wait())->toBeSame(99);
    }

    public function testOtherwiseIsSugarForRejections(): void
    {
        $p = new Promise();
        $p->reject('foo');
        self::$_value = null;
        $p->otherwise((mixed $v): void ==>  { self::$_value = $v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
    }

    public function testRepeatedWaitFulfilled(): void
    {
        $promise = new Promise((P\ResolveCallback $cb): void ==> {$cb('foo');});

        expect($promise->wait())->toBeSame('foo');
        expect($promise->wait())->toBeSame('foo');
    }
}
