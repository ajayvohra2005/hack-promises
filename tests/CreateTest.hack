

namespace HackPromises\Tests;

use HackPromises as P;
use HackPromises\FulfilledPromise;
use HackPromises\Promise;
use HackPromises\PromiseInterface;
use HackPromises\RejectedPromise;
use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};

class CreateTest extends HackTest
{
    public function testCreatesPromiseForValue(): void
    {
        $p = P\Create::promiseFor('foo');
        expect($p)->toBeInstanceOf(FulfilledPromise::class);
    }

    public function testReturnsPromiseForPromise(): void
    {
        $p = new Promise();
        expect(P\Create::promiseFor($p))->toBeSame($p);
    }

    public function testReturnsPromiseForThennable(): void
    {
        $p = new Thenable();
        $wrapped = P\Create::promiseFor($p);
        expect($p)->toNotBeSame($wrapped);
        expect($wrapped)->toBeInstanceOf(PromiseInterface::class);
        $p->resolve('foo');
        $value = (string)$wrapped->wait();
        expect($wrapped->wait())->toBeSame('foo');
    }

    public function testReturnsRejection(): void
    {
        $p = P\Create::rejectionFor('fail');
        expect($p)->toBeInstanceOf(RejectedPromise::class);
    }

    public function testReturnsPromisesAsIsInRejectionFor(): void
    {
        $a = new Promise();
        $b = P\Create::rejectionFor($a);
        expect($a)->toBeSame($b);
    }
}
