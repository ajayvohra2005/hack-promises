namespace HackPromises;

/**
 * A special exception that is thrown when waiting on a rejected promise.
 *
 * The reason value is available via the getReason() method.
 */
class RejectionException extends \RuntimeException
{
    /** @var mixed Rejection reason. */
    private mixed $reason;

    /**
     * @param mixed  $reason      Rejection reason.
     * @param string $description Optional description
     */
    public function __construct(mixed $reason, ?string $description = null)
    {
        $this->reason = $reason;

        $message = 'The promise was rejected';

        if ($description) {
            $message .= ' with reason: ' . $description;
        } elseif (self::is_implicit_string($reason)) {
            $value = (string)$reason;
            $message .= ' with reason: ' . $value;
        } elseif ($reason is \JsonSerializable) {
            $message .= ' with reason: '
                . \json_encode($this->reason, \JSON_PRETTY_PRINT);
        }

        parent::__construct($message);
    }

    /**
     * Returns the rejection reason.
     *
     * @return mixed
     */
    public function getReason(): mixed
    {
        return $this->reason;
    }
  
    private static function is_implicit_string(mixed $value): bool
    {
        try {
            $cast_as_string = (string)$value;
            return true;
        } catch(\TypeAssertionException $e){
            return false;
        }
    }

}
