use type HackPromises\Promise;

<<__EntryPoint>>
function promise_rejection_example(): void {
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();

    $promise = new Promise();
    $promise
        ->then(null, (mixed $reason): void ==> {
            $msg = $reason as string;
            echo "{$msg}\n";
        });

    // Outputs "Error!"
    $promise->reject('Error!');
}