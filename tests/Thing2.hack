namespace HackPromises\Tests;

class Thing2 implements \JsonSerializable
{
    public function __toString(): string
    {
        return $this->jsonSerialize();
    }
    
    public function jsonSerialize(): string
    {
        return '{}';
    }
}
