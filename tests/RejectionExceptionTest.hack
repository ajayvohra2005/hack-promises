
namespace HackPromises\Tests;

use HackPromises\RejectionException;
use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};



/**
 * @covers HackPromises\RejectionException
 */
class RejectionExceptionTest extends HackTest
{
    public function testCanGetReasonFromException(): void
    {
        $thing = new Thing1('foo');
        $e = new RejectionException($thing);
        expect($e->getReason())->toBeSame($thing);
        expect($e->getMessage())->toBeSame('The promise was rejected with reason: foo');
    }

    public function testCanGetReasonMessageFromJson(): void
    {
        $reason = new Thing2();
        $e = new RejectionException($reason);
        expect($e->getMessage())->toContainSubstring("{}");
    }
}
