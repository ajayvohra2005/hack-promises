

namespace HackPromises\Tests;

use HackPromises as P;
use HackPromises\Promise;
use HackPromises\PromiseInterface;

class NotPromiseInstance extends Thenable implements PromiseInterface
{
    private Promise $nextPromise;

    public function __construct()
    {
        parent::__construct();
        $this->nextPromise = new Promise();
    }

    public function then(?P\ThenCallback $res = null, ?P\ThenCallback $rej = null): PromiseInterface
    {
        return $this->nextPromise->then($res, $rej);
    }

    public function otherwise(P\ThenCallback $onRejected): PromiseInterface
    {
        return $this->then($onRejected);
    }

    public function resolve(mixed $value): void
    {
        $this->nextPromise->resolve($value);
    }

    public function reject(mixed $reason): void
    {
        $this->nextPromise->reject($reason);
    }

    public function wait(bool $unwrap = true): void
    {
    }

    public function cancel(): void
    {
    }

    public function getState(): string
    {
        return $this->nextPromise->getState();
    }
}
