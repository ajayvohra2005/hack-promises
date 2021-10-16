namespace HackPromises;

use namespace HH\Lib\Vec;

/**
 * A task queue that executes tasks in a FIFO order.
 *
 * This task queue class is used to settle promises asynchronously and
 * maintains a constant stack size. You can use the task queue asynchronously
 * by calling the `run()` function of the global task queue in an event loop.
 *
 *     HackPromises\TaskQueue::globalTaskQueue()->run();
 */
class TaskQueue implements TaskQueueInterface
{
    /** @var ?TaskQueueInterface singleton global task queue */
    private static ?TaskQueueInterface $taskQueue = null;

    /** @var bool $enableShutdown run global queue on shutdown */
    private bool $enableShutdown = true;

    /** @var vec<Task> internal task queue */
    private vec<Task> $queue = vec[];

    public function __construct(bool $withShutdown = true)
    {
        if ($withShutdown) {
            $shutdown_cb = (): void ==> {
                if ($this->enableShutdown) {
                    // Only run the tasks if an E_ERROR didn't occur.
                    $err = \error_get_last();
                    if (!$err || ($err['type'] ^ \E_ERROR)) {
                        $this->run();
                    }
                }

                return;
            };

            \register_shutdown_function($shutdown_cb);
        }
    }

    public function isEmpty(): bool
    {
        return !$this->queue;
    }

    public function add(Task $task): void
    {
        $this->queue[] = $task;
    }

    public function run(): void
    {
        while($this->queue) {
            $task = Vec\take($this->queue, 1)[0];
            $this->queue = Vec\drop($this->queue, 1);
            $task();
        }
    }

    /**
     * The task queue will be run and exhausted by default when the process
     * exits IFF the exit is not the result of an error.
     *
     * You can disable running the automatic shutdown of the queue by calling
     * this function. If you disable the task queue shutdown process, then you
     * MUST either run the task queue (as a result of running your event loop
     * or manually using the run() method) or wait on each outstanding promise.
     *
     * Note: This shutdown will occur before any destructors are triggered.
     */
    public function disableShutdown(): void
    {
        $this->enableShutdown = false;
    }

    <<__Deprecated("Use `globalTaskQueue` instead")>>
    public static function queue(?TaskQueueInterface $assign = null): TaskQueueInterface {
      return self::globalTaskQueue($assign);
    }

    /**
     * Get the global task queue used for promise resolution.
     *
     * This task queue MUST be run in an event loop in order for promises to be
     * settled asynchronously. It will be automatically run when synchronously
     * waiting on a promise.
     *
     * @param TaskQueueInterface $assign Optionally specify a new queue instance.
     *
     * @return TaskQueueInterface
     */
    public static function globalTaskQueue(?TaskQueueInterface $assign = null): TaskQueueInterface
    {
        if ($assign is TaskQueueInterface) {
            self::$taskQueue = $assign;
        } elseif (self::$taskQueue is null) {
            self::$taskQueue = new TaskQueue();
        }

        return self::$taskQueue;
    }

    /**
     * Adds a function to run in the task queue when it is next `run()` and
     * returns a promise that is fulfilled or rejected with the result.
     *
     * @param Task $task Task function to run.
     *
     * @return PromiseInterface
     */
    public static function task(Task $task): PromiseInterface
    {
        $queue = self::globalTaskQueue();
        $run_cb = (ResolveCallback $cb): void ==> {
            $queue->run();
        };
        $promise = new Promise($run_cb);

        $task_cb = (): void ==> {
            try {
                if (Is::pending($promise)) {
                    $promise->resolve($task());
                }
            } catch (\Throwable $e) {
                $promise->reject($e);
            } 
        };

        $queue->add($task_cb);

        return $promise;
    }
}
