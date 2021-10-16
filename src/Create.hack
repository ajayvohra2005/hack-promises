namespace HackPromises;

use namespace HH;

final class Create
{
    /**
     * Creates a promise for a value if the value is not a promise.
     *
     * @param mixed $value Promise or value.
     *
     * @return PromiseInterface
     */
    public static function promiseFor(mixed $value): PromiseInterface
    {
        if ($value is PromiseInterface) {
            return $value;
        }

        // Return a promise that shadows the given promise.
        if ($value is ThenableInterface) {
            $promise = new Promise( (ResolveCallback $cb): void ==> { }, 
                (RejectCallback $cb): void ==> { });
            $onFulfilled = (mixed $value): void ==> { $promise->resolve($value);};
            $onRejected = (mixed $reason): void ==> { $promise->reject($reason);};

            $value->then($onFulfilled, $onRejected);
            return $promise;
        }

        return new FulfilledPromise($value);
    }

    /**
     * Creates a rejected promise for a reason if the reason is not a promise.
     * If the provided reason is a promise, then it is returned as-is.
     *
     * @param mixed $reason Promise or reason.
     *
     * @return PromiseInterface
     */
    public static function rejectionFor(mixed $reason): PromiseInterface
    {
        if ($reason is PromiseInterface) {
            return $reason;
        }

        return new RejectedPromise($reason);
    }

    /**
     * Create an exception for a rejected promise value.
     *
     * @param mixed $reason
     *
     * @return \Exception
     */
    public static function exceptionFor(mixed $reason): \Exception
    {
        if ($reason is \Exception) {
            return $reason;
        }

        return new RejectionException($reason);
    }

    /**
     * Returns a Keyed Iterator for the given value.
     *
     * @param mixed $value
     *
     * @return HH\KeyedIterator
     */
    public static function iterFor(mixed $value): HH\KeyedIterator<arraykey, mixed>
    {
        if ($value is vec<_>) {
            $value = dict<arraykey, mixed>($value);
        } elseif(! ($value is dict<_,_>) ) {
            $value = dict[ 0 => $value];
        }

        return new DictIterator<arraykey, mixed>($value);
    }
}
