

namespace HackPromise\Tests;

use HackPromises as P;
use HackPromises\FulfilledPromise;
use HackPromises\Promise;
use HackPromises\RejectedPromise;
use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};


class IsTest extends HackTest
{
    public function testKnowsIfFulfilled(): void
    {
        $p = new FulfilledPromise(null);
        expect(P\Is::fulfilled($p))->toBeTrue();
        expect(P\Is::rejected($p))->toBeFalse();
    }

    public function testKnowsIfRejected(): void
    {
        $p = new RejectedPromise(null);
        expect(P\Is::rejected($p))->toBeTrue();
        expect(P\Is::fulfilled($p))->toBeFalse();
    }

    public function testKnowsIfSettled(): void
    {
        $p = new RejectedPromise(null);
        expect(P\Is::settled($p))->toBeTrue();
        expect(P\Is::pending($p))->toBeFalse();
    }

    public function testKnowsIfPending(): void
    {
        $p = new Promise();
        expect(P\Is::settled($p))->toBeFalse();
        expect(P\Is::pending($p))->toBeTrue();
    }
}
