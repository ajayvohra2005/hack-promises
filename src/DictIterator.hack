namespace HackPromises;

use HH\Lib\Vec;
use HH\Lib\C;

class DictIterator<Tk as arraykey, Tv> implements \HH\Iterator<Tv>, \HH\KeyedIterator<Tk, Tv>
{
    protected int $keyIdx = 0;
    protected vec<Tk> $keys;
    protected dict<Tk, Tv> $data;

    public function __construct(dict<Tk, Tv> $data)[] {
        $this->data = $data;
        $this->keys = Vec\keys($data);
    }

    public function current()[]: Tv  {
        return $this->data[$this->keys[$this->keyIdx]];
    }

    public function key()[]: Tk {
        return $this->keys[$this->keyIdx];
    }

    public function rewind()[write_props]: void {
        $this->keyIdx = 0;
    }

    public function valid()[]: bool {
        return ($this->keyIdx < C\count($this->keys) && $this->keyIdx >= 0);
    }

    public function next()[write_props]: void {
        $this->keyIdx++;
    }

    public function count()[]: int 
    {
        return C\count($this->keys);
    }

    public function empty()[]: bool
    {
        return C\count($this->keys) == 0;
    }
}