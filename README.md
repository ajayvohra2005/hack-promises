# Hack Promises

This project provides [Promises/A+](https://promisesaplus.com/) implementation in [Hack](https://docs.hhvm.com/hack/).

# Overview

## Key features
- Promises have synchronous `wait` and ```cancel``` methods.
- Works with any object that implements ```HackPromises\ThenableInterface```
- Support for Hack [```HH\KeyedIterator```](https://docs.hhvm.com/hack/reference/interface/HH.KeyedIterator/), and Hack [Generator](https://docs.hhvm.com/hack/asynchronous-operations/generators).

## Requirements

HHVM 4.128 and above.

## Installation

* Git clone this repository
* Install [composer](https://getcomposer.org/)
* In the root directory of this repository, run the command

        composer install

To use this package,

        composer require ajayvohra2005/hack-promises

## Running tests
After installation, run the following command in the root directory of this repository:

        ./vendor/bin/hacktest tests/

## License

This project is made available under the MIT License (MIT). Please see LICENSE file in this project for more information.

# Tutorial

A *promise* represents the result of the resolution of an asynchronous operation, and the side-effects associated with the resolution. 

## Resolving a promise

*Resolving* a promise means that a promise is either *fulfilled* with a *value* or *rejected*  with a *reason*. Resolving a promises triggers callbacks registered with the promises's `then` method. These callbacks are triggered only once and in the order in which they were added. When a callback is triggered, it is added to a *global task queue*. When the global task  queue is ```run```, the tasks on the queue are removed and executed in the order they were added to the queue. 

## Global task queue
The global task queue can be ```run```  as needed, or in an event loop. By default, the global task queue is run *implicitly* once prior to the program shutdown. The global task queue can be run *explictily* as shown below:

      HackPromises\TaskQueue::globalTaskQueue()->run();

## Callbacks

Callbacks are registered with a promise by calling the `then` method of the promise, and by providing optional 
`$onFulfilled` and `$onRejected` functions, whereby the functions must be of type ```HackPromises\ThenCallback```.  

When you register callbacks with a promise by calling the ```then``` method, it always returns a new promise. This can be used to create a chain of promises.  The next promise in the chain is invoked with the
resolved value of the previous promise in the chain. A promise in the chain is fulfilled only when the previous promise has been fulfilled. 

## Quick example
Below we show a quick start example that illustrates the concepts discussed so far:

```
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

  // Resolving the promise triggers the callback, and outputs 'Hello, reader.'.
  // The callbacks are executed on the global task queue, prior to program shutdown
  $promise->resolve('reader.');
  
}
```

## Promise rejection

When a promise is rejected, the `$onRejected` callbacks are invoked with the
rejection reason, as shown in the example below:

```
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
```

## Rejection forwarding

If an exception is thrown in an `$onRejected` callback, subsequent
`$onRejected` callbacks are invoked with the thrown exception as the reason.

```
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
```

If an exception is not thrown in a `$onRejected` callback and the callback
does not return a rejected promise, downstream `$onFulfilled` callbacks are
invoked using the value returned from the `$onRejected` callback, as shown in the example below:

```
use namespace HackPromises as P;

<<__EntryPoint>>
function ignore_rejection_example(): void 
{
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();
  
  $promise = new P\Promise();
  $promise ->then(null, (mixed $reason): mixed ==> {
        return "It's ok";
    })->then( (mixed $value): void ==> {
        echo $value as string;
    });

  // Outputs 'It's ok'
  $promise->reject('Error!');
}
```

## Synchronous wait

You can resolve a promise synchronously by caling the ```wait``` method on a promise. 

Calling the ```wait``` method of a promise invokes the *wait* function provided to the promise, and implicitly runs the global task queue. An example showing the use of the ```wait``` method is shown below:

```
use namespace HackPromises;

use type HackPromises\Promise;
use type HackPromises\ResolveCallback;

<<__EntryPoint>>
function promise_wait_function_example(): void {
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();

  $wait_fn = (ResolveCallback $cb) ==> {
    $cb('reader.');
  };

  $promise = new Promise($wait_fn);

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

  // Calling wait  resolves promise synchronously and outputs 'Hello, reader.'.
  $promise->wait();
}
```

If an exception is encountered while invoking the *wait* function of a promise, the promise is rejected with the exception and the exception is thrown. Calling `wait` method of a promise that has been fulfilled will not trigger the *wait* function. It will simply return the previously resolved value

Calling `wait` method on a promise that has been rejected will throw an exception. If the rejection reason is an instance of `\Exception` the *reason* is thrown. Otherwise, a `HackPromises\RejectionException` is thrown and the *reason* can be obtained by calling the `getReason` method of the exception.

### Unwrapping a promise

When you call the ```wait``` method without an argument, or with the argument ```true```, it unwraps the promiose. Unwrapping the promise returns the value of the promise if it was *fulfilled*, or throws an exception if the promise was *rejected*.   You can force a promise to resolve but *not* unwrap 
by passing `false` to the `wait` method of the promise, as shown in the example below:

```
$promise = new Promise();
$promise->reject('foo');
// This will not throw an exception. It simply ensures the promise has
// been resolved.
$promise->wait(false);
```

When unwrapping a promise, the resolved value of the promise will be waited
upon until the unwrapped value is not a promise. This means that if you resolve
promise A with a promise B and unwrap promise A, the value returned by the
wait function will be the result of resolving promise B, as shown in the example below;

```
use namespace HackPromises as P;

<<__EntryPoint>>
function unwrapping_example(): void 
{
  require_once(__DIR__.'/../vendor/autoload.hack');
  \Facebook\AutoloadMap\initialize();
  
  $b = new P\Promise();
  $a = new P\Promise( (P\ResolveCallback $cb): void ==> { $cb($b);});
  $b->resolve('foo');
  $result = $a->wait() as string;

  // Outputs 'foo'
  echo $result;
}
```

## Synchronous cancel

You can cancel a promise that has not yet been fulfilled synchronously using the `cancel()`
method of a promise. 

# API classes

## Promise 

For the base case, you can use  ```Promise```  class to create a promise. 

If you want to resolve the promise **asynchronosuly** and invoke the registerd ```then``` callbacks, you can create the ```Promise``` without any arguments to the constructor. 

If you want be able to **synchronously** resolve or cancel the ```Promise``` , pass the *wait* and *cancel* functions to the constructor.

### Wait function
The *wait* function must be of type ```HackPromises\WaitFunction```.  The *wait* function provided to a ```Promise``` constructor is invoked when the ```wait``` method
of the ```Promise``` is called. The *wait* function must resolve the ```Promise``` by calling the ```HackPromises\ResolveCallback```  function passed to it as an argument, or throw an exception. 

### Cancel function
When creating a ```Promise``` you can provide an optional
*cancel* function of type ```HackPromises\CancelFunction```, which is invoked by the promise if you call the ```cancel()``` method of the promise. The *cancel* function may optionally reject the promise by invoking the ```HashPromises\RejectCallback``` function passed to it as an argument.

## FulfilledPromise

The ```FulfilledPromise```  class object is fulfilled on construction.

## RejectedPromise

The ```RejectedPromise```  class object is rejected on construction.

## IteratorPromise

The ```IteratorPromise``` class creates an aggregated promise that iterates over an iterator of promises, or values, and triggers callback functions in the process. Use ```Create::iterFor``` to create an iterator for a ```vec<mixed>``` or a ```dict<arraykey, mixed>```.

## GeneratorPromise

The ```GeneratorPromise``` class wraps a generator that yields values, or promises.

## Create

The ```Create``` class provides helper methods.

# Acknowledgements
This project is inspired by [Guzzle Promises](https://github.com/guzzle/promises). However, it has signficant differences in API and implementation, owing to the language and best-practices requirements of Hack. 