## ReentrantLock介绍

`ReentrantLock`就是一个`互斥锁`，可以让多线程执行期间，只有一个线程在执行指定的代码

```java
public ReentrantLock() {
    // 默认非公平锁
    sync = new NonfairSync();
}

public ReentrantLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
}
```



## FairSync

公平锁，每个线程会一个一个排队



## NonfairSync

非公平锁

```java
static final class NonfairSync extends Sync {
    private static final long serialVersionUID = 7316153563782823691L;

    /**
     * Performs lock.  Try immediate barge, backing up to normal
     * acquire on failure.
     */
    final void lock() {
        // 非公平锁上来就直接竞争锁资源
        if (compareAndSetState(0, 1))
            setExclusiveOwnerThread(Thread.currentThread());
        else
            acquire(1);
    }

    protected final boolean tryAcquire(int acquires) {
        return nonfairTryAcquire(acquires);
    }
}
```

