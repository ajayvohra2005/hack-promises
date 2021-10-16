namespace HackPromises;

type ThenCallback = (function(mixed): mixed);

interface ThenableInterface
{
  /**
     * @param ThenCallback $onFulfilled Triggered when the promise is fulfilled.
     * @param ThenCallback $onRejected  Triggered when the promise is rejected.
     *
     * @return PromiseInterface A promise used for chaining promises
     */
    public function then(
        ?ThenCallback $onFulfilled = null,
        ?ThenCallback $onRejected = null): PromiseInterface;

}