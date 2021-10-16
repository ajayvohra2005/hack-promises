namespace HackPromises\Tests;

use HackPromises\TaskQueue;
use function Facebook\FBExpect\expect;
use type Facebook\HackTest\{DataProvider, HackTest};


class TaskQueueTest extends HackTest
{
    static  vec<string> $called = vec[];

    public function testKnowsIfEmpty(): void
    {
        $tq = new TaskQueue(false);
        expect($tq->isEmpty())->toBeTrue();

    }

    public function testKnowsIfFull(): void
    {
        $tq = new TaskQueue(false);
        $tq->add( (): void ==> {});
        expect($tq->isEmpty())->toBeFalse();
    }

    public function testExecutesTasksInOrder(): void
    {
        $tq = new TaskQueue(false);
        $tq->add( (): void  ==> { self::$called[] = 'a'; });
        $tq->add( (): void  ==> { self::$called[] = 'b'; });
        $tq->add( (): void  ==> { self::$called[] = 'c'; });
        $tq->run();
        expect(self::$called)->toBeSame(vec['a', 'b', 'c']);
    }
}
