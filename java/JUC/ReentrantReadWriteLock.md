## ReentrantReadWriteLock

读线程和读线程之间不互斥，读线程和写线程互斥，写线程和写线程也互斥

```java
public class ReentrantReadWriteLock implements ReadWriteLock, java.io.Serializable {
    private static final long serialVersionUID = -6992448646407690164L;
    /** Inner class providing readlock */
    private final ReentrantReadWriteLock.ReadLock readerLock;
    /** Inner class providing writelock */
    private final ReentrantReadWriteLock.WriteLock writerLock;
    /** Performs all synchronization mechanics */
    final Sync sync;

    /**
     * Creates a new {@code ReentrantReadWriteLock} with
     * default (nonfair) ordering properties.
     */
    public ReentrantReadWriteLock() {
        this(false);
    }

    /**
     * Creates a new {@code ReentrantReadWriteLock} with
     * the given fairness policy.
     *
     * @param fair {@code true} if this lock should use a fair ordering policy
     */
    public ReentrantReadWriteLock(boolean fair) {
        sync = fair ? new FairSync() : new NonfairSync();
        readerLock = new ReadLock(this);
        writerLock = new WriteLock(this);
    }

    public ReentrantReadWriteLock.WriteLock writeLock() { return writerLock; }
    public ReentrantReadWriteLock.ReadLock  readLock()  { return readerLock; }
    
    
    
    .............
    
}
```

## Sync

```java
static final int SHARED_SHIFT   = 16;

// 
static final int SHARED_UNIT    = (1 << SHARED_SHIFT);

// 共享锁或者独占锁的最大数量
static final int MAX_COUNT      = (1 << SHARED_SHIFT) - 1;

// Mask
static final int EXCLUSIVE_MASK = (1 << SHARED_SHIFT) - 1;

// 共享锁的数量
static int sharedCount(int c)    { return c >>> SHARED_SHIFT; }

// 独占锁的数量
static int exclusiveCount(int c) { return c & EXCLUSIVE_MASK; }
```

###  写锁的获取 tryAcquire

```java
public void lock() {
      sync.acquire(1);
}
```



```java
protected final boolean tryAcquire(int acquires) {
   
    Thread current = Thread.currentThread();
    int c = getState();
    
    // 独占锁的数量
    int w = exclusiveCount(c);
    if (c != 0) {
        // c!=0且w == 0说明读锁状态不为0，说明有线程持有读锁，读线程与写线程之间互斥
        // c!=0且w!=0且当前线程不持有写锁说明写锁被其他线程持有，写线程与读线程互斥，写线程与写线程之间也互斥
        // 这两种情况均直接返回false，不能获得写锁，返回false
        if (w == 0 || current != getExclusiveOwnerThread())
            return false;
        
        // 此时w!=0且当前线程持有写锁，检查获取锁后会否溢出 
        if (w + exclusiveCount(acquires) > MAX_COUNT)
            throw new Error("Maximum lock count exceeded");
        // Reentrant acquire
        // 不会溢出，获得写锁并更新state
        setState(c + acquires);
        return true;
    }
    // 公平模式的FairSync类，该类的readerShouldBlock和writerShouldBlock两个方法都直接返回hasQueuedPredecessors方法的结果，
    // 这个方法是AQS同步器的方法，用于判断当前线程前面是否有排队的线程。如果有排队队列就要让当前线程也加入排队队列中，这样按照
    // 队列顺序获取锁也就保证了公平性
    
    // 非公平模式NonfairSync类，该类的writerShouldBlock方法直接返回false，表明不要让当前线程进入排队队列中，直接进行锁的获取竞争
    if (writerShouldBlock() ||
        // CAS设置状态，失败的话直接返回false；成功则设置当前线程为持有锁线程，返回true
        !compareAndSetState(c, c + acquires))
        return false;
    setExclusiveOwnerThread(current);
    return true;
}
```

- 有线程持有`读锁`时不能获取`写锁`

- 其他线程持有`写锁`时，不能获取`写锁`



### 写锁的释放 unlock

```java
public void unlock() {
    sync.release(1);
}
```

```java
		protected final boolean tryRelease(int releases) {
            // 必须持有锁才能释放锁
            if (!isHeldExclusively())
                throw new IllegalMonitorStateException();
            
            // 这里并没有跟写锁掩码相交，因为获取锁时读锁状态肯定为0
            int nextc = getState() - releases;
            // 可重入的数量是否到达0了
            boolean free = exclusiveCount(nextc) == 0;
            if (free)
                setExclusiveOwnerThread(null);
            setState(nextc);
            return free;
        }
```



### 读锁的获取

```java
public void lock() {
	sync.acquireShared(1);
 }

public final void acquireShared(int arg) {
        if (tryAcquireShared(arg) < 0)
            doAcquireShared(arg);
}
```



```java
protected final int tryAcquireShared(int unused) {
    
    Thread current = Thread.currentThread();
    int c = getState();
    
    // 当其他线程持有写锁，获取读锁失败，return -1，接着构造共享节点加入阻塞队列
    //  如果是当前线程获取到了写锁，可以获取读锁
    if (exclusiveCount(c) != 0 &&
        getExclusiveOwnerThread() != current)
        return -1;
    
    // 此时没有线程持有写锁或本线程持有写锁，可以获取读锁
    // r为持有读锁的线程
    int r = sharedCount(c);
    
    // 公平模式的FairSync类，该类的readerShouldBlock个方法都直接返回hasQueuedPredecessors方法的结果，
    // 这个方法是AQS同步器的方法，用于判断当前线程前面是否有排队的线程。如果有排队队列就要让当前线程也加入
    // 排队队列中，这样按照队列顺序获取锁也就保证了公平性
    
    // 非公平模式NonfairSync类，readerShouldBlock方法则调用apparentlyFirstQueuedIsExclusive方法，这个
    // 方法是AQS同步器的方法，用于判断头结点的下一个节点线程是否在请求获取独占锁（写锁）。如果是则让其它线
    // 程先获取写锁，而自己则乖乖去排队。如果不是则说明下一个节点线程是请求共享锁（读锁），此时直接与之竞争读锁
    if (!readerShouldBlock() &&
        r < MAX_COUNT &&
        compareAndSetState(c, c + SHARED_UNIT)) {
        
        if (r == 0) {
            // 此时没有线程持有读锁，当前线程将是第一个获取读锁的线程
            firstReader = current;
            firstReaderHoldCount = 1;
        } else if (firstReader == current) {
            // 此时有线程持有读锁
            // 当前线程是这些线程中第一个获取读锁的线程，更新firstReaderHoldCount
            firstReaderHoldCount++;
        } else {
            // 此时有线程持有读锁 且 当前线程不是第一个获取读锁的线程
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
            rh.count++;
        }
        // 成功获取读锁
        return 1;
    }
    // 自旋获取
    return fullTryAcquireShared(current);
}
```

什么当前线程持有写锁的情况下还能继续获取读锁呢？

> **其实就是一个可见性的问题，当前线程获取写锁后，其他线程显然不能再获取写锁，所以此时的修改操作只能在当前线程进行，此时完全可以把本线程内的任务看成是顺序执行的，别的线程不会干扰他，自然可以获取读锁进行读取操作**



```java
final int fullTryAcquireShared(Thread current) {
            /*
             * This code is in part redundant with that in
             * tryAcquireShared but is simpler overall by not
             * complicating tryAcquireShared with interactions between
             * retries and lazily reading hold counts.
             */
            HoldCounter rh = null;
            for (;;) {
                int c = getState();
                // 其他线程持有写锁时直接返回-1
                if (exclusiveCount(c) != 0) {
                    if (getExclusiveOwnerThread() != current)
                        return -1;
                    // else we hold the exclusive lock; blocking here
                    // would cause deadlock.
                } else if (readerShouldBlock()) {
                    // 发生等待
                    // Make sure we're not acquiring read lock reentrantly
                    if (firstReader == current) {
                        // assert firstReaderHoldCount > 0;
                    } else {
                        // 当前线程不是第一个获得读锁的线程
                        if (rh == null) {
                            rh = cachedHoldCounter;
                            if (rh == null || rh.tid != getThreadId(current)) {
                                rh = readHolds.get();
                                if (rh.count == 0)
                                    readHolds.remove();
                            }
                        }
                        if (rh.count == 0)
                            return -1;
                    }
                }
                // 此时没有发生等待
                if (sharedCount(c) == MAX_COUNT)
                    throw new Error("Maximum lock count exceeded");
                
                // CAS更新state，更新对应的firstreader或者readHolds或者cachedHoldCounter，CAS成功返回1，否则继续自旋
                if (compareAndSetState(c, c + SHARED_UNIT)) {
                    if (sharedCount(c) == 0) {
                        firstReader = current;
                        firstReaderHoldCount = 1;
                    } else if (firstReader == current) {
                        firstReaderHoldCount++;
                    } else {
                        if (rh == null)
                            rh = cachedHoldCounter;
                        if (rh == null || rh.tid != getThreadId(current))
                            rh = readHolds.get();
                        else if (rh.count == 0)
                            readHolds.set(rh);
                        rh.count++;
                        cachedHoldCounter = rh; // cache for release
                    }
                    return 1;
                }
            }
        }
```

### 读锁的释放

```java
public void unlock() {
     sync.releaseShared(1);
}

public final boolean releaseShared(int arg) {
        if (tryReleaseShared(arg)) {
            doReleaseShared();
            return true;
        }
        return false;
}
```



```java
protected final boolean tryReleaseShared(int unused) {
    Thread current = Thread.currentThread();
    if (firstReader == current) {
        // assert firstReaderHoldCount > 0;
        if (firstReaderHoldCount == 1)
            firstReader = null;
        else
            firstReaderHoldCount--;
    } else {
        // 更新当前线程对应的读锁重入次数
        HoldCounter rh = cachedHoldCounter;
        if (rh == null || rh.tid != getThreadId(current))
            rh = readHolds.get();
        int count = rh.count;
        if (count <= 1) {
            readHolds.remove();
            if (count <= 0)
                throw unmatchedUnlockException();
        }
        --rh.count;
    }
    for (;;) {
        int c = getState();
        int nextc = c - SHARED_UNIT;
        if (compareAndSetState(c, nextc))
            // Releasing the read lock has no effect on readers,
            // but it may allow waiting writers to proceed if
            // both read and write locks are now free.
            // CAS 更新state，最后返回状态是否为0，为 0 的话就说明此时没有线程持有读锁，
            // 然后调用doReleaseShared释放一个由于获取写锁而被阻塞的线程
            return nextc == 0;
    }
}
```

为什么当前线程持有读锁的情况下不能继续获取写锁呢？

> **如果可以允许读锁升级为写锁，这里面就涉及一个很大的竞争问题，所有的读锁都会去竞争写锁，这样以来必然引起巨大的抢占，这是非常复杂的，因为如果竞争写锁失败，那么这些线程该如何处理？是继续还原成读锁状态，还是升级为竞争写锁状态？这一点是不好处理的，所以Java的api为了让语义更加清晰，所以只支持写锁降级为读锁，不支持读锁升级为写锁。JDK8中新增的StampedLock类就可以比较优雅的完成这件事**

总结一下锁的获取：

- 当有线程持有读锁时当前线程不能获取写锁
- 当前线程持有写锁时可以继续获取读锁，此时再释放写锁继续持有读锁，即锁降级
- 其他线程持有写锁时不能获取读锁
- 不支持锁升级

## WriteLock

```java
public static class WriteLock implements Lock, java.io.Serializable {
        private static final long serialVersionUID = -4992448646407690164L;
        private final Sync sync;

        protected WriteLock(ReentrantReadWriteLock lock) {
            sync = lock.sync;
        }

        public void lock() {
            sync.acquire(1);
        }

        public void lockInterruptibly() throws InterruptedException {
            sync.acquireInterruptibly(1);
        }

        
        public boolean tryLock( ) {
            return sync.tryWriteLock();
        }

        
        public boolean tryLock(long timeout, TimeUnit unit)
                throws InterruptedException {
            return sync.tryAcquireNanos(1, unit.toNanos(timeout));
        }

       
        public void unlock() {
            sync.release(1);
        }

        
        public Condition newCondition() {
            return sync.newCondition();
        }

        
        public String toString() {
            Thread o = sync.getOwner();
            return super.toString() + ((o == null) ?
                                       "[Unlocked]" :
                                       "[Locked by thread " + o.getName() + "]");
        }

        
        public boolean isHeldByCurrentThread() {
            return sync.isHeldExclusively();
        }

        
        public int getHoldCount() {
            return sync.getWriteHoldCount();
        }
    }
```





## ReadLock

```java
public static class ReadLock implements Lock, java.io.Serializable {
    private static final long serialVersionUID = -5992448646407690164L;
    private final Sync sync;

    protected ReadLock(ReentrantReadWriteLock lock) {
        sync = lock.sync;
    }

    public void lock() {
        sync.acquireShared(1);
    }

    public void lockInterruptibly() throws InterruptedException {
        sync.acquireSharedInterruptibly(1);
    }

    public boolean tryLock() {
        return sync.tryReadLock();
    }
    
    public boolean tryLock(long timeout, TimeUnit unit)
            throws InterruptedException {
        return sync.tryAcquireSharedNanos(1, unit.toNanos(timeout));
    }

    public void unlock() {
        sync.releaseShared(1);
    }

    public Condition newCondition() {
        throw new UnsupportedOperationException();
    }

    public String toString() {
        int r = sync.getReadLockCount();
        return super.toString() +
            "[Read locks = " + r + "]";
    }
}
```





