use type HackPromises\Promise;

<<__EntryPoint>>
function promise_forwarding_example(): void {
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();

    $firstPromise = new Promise();
    $secondPromise = new Promise();

    $firstPromise
        ->then((mixed $value): mixed ==> {
            // Return a value and don't break the chain
            $msg = $value as string;
            echo "{$msg}\n";
            return $secondPromise;
        })
        // This then is executed after the first then and receives the value
        // returned from the first then.
        ->then((mixed $value): void ==> {
            $msg = $value as string;
            echo "{$msg}\n";
        });

    $secondPromise->resolve('Second Promise fulfilled');
    $firstPromise->resolve('First Promise fulfilled');
    
}