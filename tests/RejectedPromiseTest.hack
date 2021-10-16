

namespace HackPromise\Tests;

use HackPromises as P;
use HackPromises\Promise;
use HackPromises\RejectedPromise;

use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};


/**
 * @covers HackPromises\RejectedPromise
 */
class RejectedPromiseTest extends HackTest
{
    private static mixed $_value;

    public function testThrowsReasonWhenWaitedUpon(): void
    {
        $p = new RejectedPromise('foo');
        expect(P\Is::rejected($p))->toBeTrue();

        try {
            $p->wait(true);
        } catch (\Exception $e) {
            expect(P\Is::rejected($p))->toBeTrue();
            expect($e->getMessage())->toBeSame('The promise was rejected with reason: foo');
        }
    }

    public function testCannotCancel(): void
    {
        $p = new RejectedPromise('foo');
        $p->cancel();
        expect(P\Is::rejected($p))->toBeTrue();
    }

    /**
     * @expectedException LogicException
     * @exepctedExceptionMessage Cannot resolve a rejected promise
     */
    public function testCannotResolve(): void
    {
        $p = new RejectedPromise('foo');
        expect(() ==> $p->resolve('bar'))->toThrow(\LogicException::class, 'Cannot resolve a rejected promise');
    }

    /**
     * @expectedException LogicException
     * @exepctedExceptionMessage Cannot resolve a rejected promise
     */
    public function testCannotReject(): void
    {
        $p = new RejectedPromise('foo');
        expect(() ==> $p->reject('bar'))->toThrow(\LogicException::class, 'Cannot reject a rejected promise');
    }

    public function testCanRejectWithSameValue(): void
    {
        $p = new RejectedPromise('foo');
        $p->reject('foo');
        expect(P\Is::rejected($p))->toBeTrue();
    }

    public function testThrowsSpecificException(): void
    {
        $e = new \Exception();
        $p = new RejectedPromise($e);
        try {
            $p->wait(true);
        } catch (\Exception $e2) {
            expect($e2)->toBeSame($e);
        }
    }

    /**
     * @expectedException InvalidArgumentException
     */
    public function testCannotResolveWithPromise(): void
    {
        expect(() ==> new RejectedPromise(new Promise()))->toThrow(\InvalidArgumentException::class, 'You cannot create a RejectedPromise with a promise.');
    }

    public function testReturnsSelfWhenNoOnReject(): void
    {
        $p = new RejectedPromise('a');
        expect($p->then())->toBeSame($p);
    }

    public function testInvokesOnRejectedAsynchronously(): void
    {
        $p = new RejectedPromise('a');
        self::$_value = null;
        $f = (mixed $reason): void ==> { self::$_value = $reason; };
        $p->then(null, $f);
        expect(self::$_value)->toBeNull();
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('a');
    }

    public function testInvokesOnRejectedOnWait(): void
    {
        self::$_value = null;
        $p = new RejectedPromise('a');
        $f = (mixed $reason): void ==> { self::$_value = $reason; };
        $p->then(null, $f);
        expect(self::$_value)->toBeNull();
        $p->wait(false);
        expect(self::$_value)->toBeSame('a');
    }

    public function testReturnsNewRejectedWhenOnRejectedFails(): void
    {
        $p = new RejectedPromise('a');
        $f = (mixed $reason): void ==> { throw new \Exception('b'); };
        $p2 = $p->then(null, $f);
        expect($p2)->toNotBeSame($p);
        try {
            $p2->wait();
        } catch (\Exception $e) {
            expect($e->getMessage())->toBeSame('b');
        }
    }

    public function testWaitingIsNoOp(): void
    {
        $p = new RejectedPromise('a');
        $p->wait(false);
        expect(P\Is::rejected($p))->toBeTrue();
    }

    public function testOtherwiseIsSugarForRejections(): void
    {
        $p = new RejectedPromise('foo');
        self::$_value = null;
        $p->otherwise( (mixed $v) : void ==>  { self::$_value = $v; });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo');
    }

    public function testCanResolveThenWithSuccess(): void
    {
        self::$_value = null;
        $p = new RejectedPromise('foo');
        $p->otherwise( (mixed $v): mixed ==> {
            return ((string)$v) . ' bar';
        })->then((mixed $v): void ==> {
            self::$_value = $v;
        });
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('foo bar');
    }

    public function testDoesNotTryToRejectTwiceDuringTrampoline(): void
    {
        $fp = new RejectedPromise('a');
        $t1 = $fp->then(null, (mixed $v): mixed ==> { return ((string)$v) . ' b'; });
        $t1->resolve('why!');
        expect($t1->wait())->toBeSame('why!');
        P\TaskQueue::globalTaskQueue()->run();
    }
}
