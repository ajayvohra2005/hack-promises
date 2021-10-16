
namespace HackPromises\Tests;

use  type HackPromises\{Promise, PromiseInterface, ThenableInterface};
use  type HackPromises\{ThenCallback};

class Thenable implements ThenableInterface
{
    private Promise $nextPromise;

    public function __construct()
    {
        $this->nextPromise = new Promise();
    }

    public function then(?ThenCallback $res = null, ?ThenCallback $rej = null): PromiseInterface
    {
        return $this->nextPromise->then($res, $rej);
    }

    public function resolve(mixed $value): void
    {
        $this->nextPromise->resolve($value);
    }
}
