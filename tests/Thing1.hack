namespace HackPromises\Tests;

class Thing1
{
    private string $message;
    
    public function __construct(string $message)
    {
        $this->message = $message;
    }

    public function __toString(): string
    {
        return $this->message;
    }
}