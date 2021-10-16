use namespace HackPromises;

use type HackPromises\Promise;

<<__EntryPoint>>
function quick_start_example(): void {
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();

  $promise = new Promise();

  $promise
    ->then((mixed $value): mixed ==> {
        // Return a value and don't break the chain
        return "Hello, " . ($value as string);
    })
    // This then is executed after the first then and receives the value
    // returned from the first then.
    ->then((mixed $value): void ==> {
        $msg = $value as string;
        echo "{$msg}\n";
    });

  // Resolving the promise triggers the callbacks and output Hello, reader.
  $promise->resolve('reader.');

}