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
 * @covers HackPromises\FulfilledPromise
 */
class FulfilledPromiseTest extends HackTest
{
    private static mixed $_value;

    public function testReturnsValueWhenWaitedUpon(): void
    {
        $p = new FulfilledPromise('foo');
        expect(P\Is::fulfilled($p))->toBeTrue();
        expect($p->wait(true))->toBeSame('foo');
    }

    public function testCannotCancel(): void
    {
        $p = new FulfilledPromise('foo');
        expect(P\Is::fulfilled($p))->toBeTrue();
        $p->cancel();
        expect($p->wait())->toBeSame('foo');
    }

    /**
     * @exepctedExceptionMessage Cannot resolve a fulfilled promise
     */
    public function testCannotResolve(): void
    {
        $p = new FulfilledPromise('foo');
        expect( () ==> $p->resolve('bar'))->toThrow(\LogicException::class);
    }

    /**
     * @exepctedExceptionMessage Cannot reject a fulfilled promise
     */
    public function testCannotReject(): void
    {
        $p = new FulfilledPromise('foo');
        expect( () ==> $p->reject('bar'))->toThrow(\LogicException::class);
    }

    public function testCanResolveWithSameValue(): void
    {
        $p = new FulfilledPromise('foo');
        $p->resolve('foo');
        expect($p->wait())->toBeSame('foo');
    }

    public function testCannotResolveWithPromise(): void
    {
        expect(() ==> new FulfilledPromise(new Promise()))->toThrow(\InvalidArgumentException::class);
    }

    public function testReturnsSelfWhenNoOnFulfilled(): void
    {
        $p = new FulfilledPromise('a');
        expect($p->then())->toBeSame($p);
    }

    public function testAsynchronouslyInvokesOnFulfilled(): void
    {
        $p = new FulfilledPromise('a');
        self::$_value = null;
        $f = (mixed $d): void ==> { self::$_value = $d; };
        $p2 = $p->then($f);
        expect($p)->toNotBeSame($p2);
        expect(self::$_value)->toBeNull();
        P\TaskQueue::globalTaskQueue()->run();
        expect(self::$_value)->toBeSame('a');
    }

    public function testInvokesOnFulfilledOnWait(): void
    {
        $p = new FulfilledPromise('a');
        self::$_value  = null;
        $f = (mixed $d):void ==>  { self::$_value  = $d; };
        $p->then($f);
        expect(self::$_value )->toBeNull();
        $p->wait();
        expect(self::$_value )->toBeSame('a');
    }

    public function testReturnsNewRejectedWhenOnFulfilledFails(): void
    {
        $p = new FulfilledPromise('a');
        $f = (mixed $value): void ==> { throw new \Exception('b'); };
        $p2 = $p->then($f);
        expect($p)->toNotBeSame($p2);
        try {
            $p2->wait();
        } catch (\Exception $e) {
            expect($e->getMessage())->toBeSame('b');
        }
    }

    public function testOtherwiseIsSugarForRejections(): void
    {
        self::$_value = null;
        $p = new FulfilledPromise('foo');
        $p->otherwise((mixed $v) ==> { self::$_value = $v; });
        expect(self::$_value)->toBeNull();
    }

    public function testDoesNotTryToFulfillTwiceDuringTrampoline(): void
    {
        $fp = new FulfilledPromise('a');
        $t1 = $fp->then((mixed $v): mixed ==> { return (string)$v . ' b'; });
        $t1->resolve('why!');
        expect($t1->wait())->toBeSame('why!');
        P\TaskQueue::globalTaskQueue()->run();
    }
}
