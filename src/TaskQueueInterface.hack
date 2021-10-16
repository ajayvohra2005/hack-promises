namespace HackPromises;

type Task = (function():mixed);

interface TaskQueueInterface
{
    /**
     * Returns true if the queue is empty.
     *
     * @return bool
     */
    public function isEmpty(): bool;

    /**
     * Adds a task to the queue that will be executed the next time run is
     * called.
     */
    public function add(Task $task): void;

    /**
     * Execute all of the pending task in the queue.
     */
    public function run(): void;
}
