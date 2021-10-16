

namespace HackPromises;

final class Is
{
    /**
     * Returns true if a promise is pending.
     *
     * @return bool
     */
    public static function pending(PromiseInterface $promise): bool
    {
        return $promise->getState() === PromiseInterface::PENDING;
    }

    /**
     * Returns true if a promise is fulfilled or rejected.
     *
     * @return bool
     */
    public static function settled(PromiseInterface $promise): bool
    {
        return $promise->getState() !== PromiseInterface::PENDING;
    }

    /**
     * Returns true if a promise is fulfilled.
     *
     * @return bool
     */
    public static function fulfilled(PromiseInterface $promise): bool
    {
        return $promise->getState() === PromiseInterface::FULFILLED;
    }

    /**
     * Returns true if a promise is rejected.
     *
     * @return bool
     */
    public static function rejected(PromiseInterface $promise): bool
    {
        return $promise->getState() === PromiseInterface::REJECTED;
    }
}
