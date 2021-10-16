namespace HackPromises;

use HH\Lib\Vec;
use HH\Lib\C;

class MutableDictIterator<Tk as arraykey, Tv> extends DictIterator<Tk, Tv> 
{
    public function __construct(dict<Tk, Tv> $data)[] {
        parent::__construct($data);
    }

    public function unset(Tk $key): void 
    {
        if(C\contains($this->keys, $key)) {
            $find_cb = (Tk $k): bool ==> $k === $key;
            $index = C\find_key($this->keys, $find_cb);

            if($index is nonnull) {
                $this->keys = Vec\concat(Vec\take($this->keys, $index), Vec\drop($this->keys, $index+1));
                \unset($this->data[$key]);
                if(!$this->valid()) {
                    $this->rewind();
                }
            }
        }
    }

    public function add(Tk $key, Tv $value): bool 
    {
        if(!C\contains($this->keys, $key)) {
            $this->keys[] = $key;
            $this->data[$key] = $value;
            return true;
        }

        return false;
    }

    public function set(Tk $key, Tv $value): bool 
    {
        if(C\contains($this->keys, $key)) {
            $this->data[$key] = $value;
            return true;
        }

        return false;
    }

}