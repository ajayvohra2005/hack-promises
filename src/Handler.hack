namespace HackPromises;

use HH\Lib\C;

class Handler
{
    private PromiseInterface $promise;
    private ?ThenCallback $onFulfilled;
    private ?ThenCallback $onRejected;

    public function __construct(PromiseInterface $promise, 
        ?ThenCallback $onFulfilled=null, 
        ?ThenCallback $onRejected=null)
    {
        $this->promise = $promise;
        $this->onFulfilled = $onFulfilled;
        $this->onRejected = $onRejected;
    }

    public function getPromise(): PromiseInterface
    {
        return $this->promise;
    }

    public function getCallback(string $name): ?ThenCallback {
        $callback = null;

        switch($name) {
            case PromiseInterface::FULFILLED:
                $callback = $this->onFulfilled;
                break;
            case PromiseInterface::REJECTED:
                $callback = $this->onRejected;
                break;
        }

        return $callback;
    }
    
}