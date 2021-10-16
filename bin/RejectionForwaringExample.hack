use type HackPromises\{Promise, RejectedPromise};

<<__EntryPoint>>
function rejection_forwarding_example(): void {
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();

    $promise = new Promise();
    $promise
        ->then(null, (mixed $reason): mixed ==> {
            return new RejectedPromise($reason);
        })
        ->then(null, (mixed $reason): void ==> {
        });

    // Outputs nothing
    $promise->reject('No Error!');
}