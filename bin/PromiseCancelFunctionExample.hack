use namespace HackPromises;

use type HackPromises\Promise;
use type HackPromises\RejectCallback;

<<__EntryPoint>>
function promise_cancel_function_example(): void {
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();

  $cancel_fn = (RejectCallback $cb) ==> {
    $cb("Promise cancelled by user.");
  };

  $promise = new Promise(null, $cancel_fn);

  $promise
    ->then(null, (mixed $reason): void ==> {
        $msg = $reason as string;
        echo "{$msg}\n";
    });

  // Outputs 'Promise cancelled by user.''
  $promise->cancel();
}