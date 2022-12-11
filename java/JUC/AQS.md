## AQS介绍

一般的写法：

```java
Lock lock = new ReentrantLock();
...
lock.lock();
try {
    // 更新对象
    //捕获异常
} finally {
    lock.unlock();
}
```

AQS就是`AbstractQueuedSynchronizer`，AQS内部维护一个双向链表

AQS只是一个框架，具体资源的获取/释放方式交由自定义同步器去实现，这里的接口没有定义成`abstract`是因为独占模式下只需实现`tryAcquire-tryRelease`，而共享模式下只用实现`tryAcquireShared-tryReleaseShared`。因此没必要定义成abstract类型。



```java
// 头结点，不代表任何线程,是一个虚拟节点
private transient volatile Node head;

// 阻塞的尾节点，每个新的节点进来，都插入到最后，也就形成了一个链表
private transient volatile Node tail;

// 这个是最重要的，代表当前锁的状态，0代表没有被占用，大于 0 代表有线程持有当前锁
// 这个值可以大于 1，是因为锁可以重入，每次重入都加上 1
private volatile int state;

// 代表当前持有独占锁的线程，举个最重要的使用例子，因为锁可以重入
// reentrantLock.lock()可以嵌套调用多次，所以每次用这个来判断当前线程是否已经拥有了锁
// if (currentThread == getExclusiveOwnerThread()) {state++}
private transient Thread exclusiveOwnerThread; //继承自AbstractOwnableSynchronizer
```

在AQS中的队列是一个CLH队列，它的head节点永远是一个哑结点（dummy node), 它不代表任何线程（某些情况下可以看做是代表了当前持有锁的线程），**因此head所指向的Node的thread属性永远是null**。只有从次头节点往后的所有节点才代表了所有等待锁的线程。也就是说，在当前线程没有抢到锁被包装成Node扔到队列中时，**即使队列是空的，它也会排在第二个**

## acquire

```java
public final void acquire(int arg) {
    // 尝试获取锁，tryAcquire由AQS子类自己实现
    // 如果tryAcquire(arg) 返回true, 也就结束了,也就不需要进队列排队了
    if (!tryAcquire(arg) &&
        // tryAcquire(arg)没有成功，这个时候需要把当前线程挂起，放到阻塞队列中
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        // acquireQueued
        selfInterrupt();
}
```

为什么满足if条件会需要进行`selfInterrupt()`设置中断呢？其实后面关于`acquireQueued()`方法介绍中会提到，如果当前线程是中断状态，其内部调用的方法：`parkAndCheckInterrupt()`会清除线程的中断状态，所以`acquire`调用`selfInterrupt()`将线程的中断状态设置回去。

## addWaiter

```java
private Node addWaiter(Node mode) {
    // 把线程包装成node，同时进入到队列中
    Node node = new Node(Thread.currentThread(), mode);
    // Try the fast path of enq; backup to full enq on failure
    Node pred = tail;
    // 
    if (pred != null) {
        // 队列不为空，
        node.prev = pred;
        // 以CAS方式自己设置为队尾
        // 如果失败，可能是队列空了，或者有其他线程抢占了，后面就会以自旋的方式插入队尾
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    enq(node);
    return node;
}

// 采用自旋的方式入队,总能入队
private Node enq(final Node node) {
    for (;;) {
        // tail 的修饰符是 volatile ，所以保证线程间的可见性
        Node t = tail;
        if (t == null) { // Must initialize
            // 先初始化头节点，然后自旋
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            // 插入到队尾
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```

![aqs-0](../img/aqs-0.png)



## acquireQueued

```java
final boolean acquireQueued(final Node node, int arg) {
    // 记是否成功拿到资源
    boolean failed = true;
    try {
        // 标记等待过程中是否中断过
        boolean interrupted = false;
        // 开始自旋，要么获取锁，要么中断
        for (;;) {
            // 获取当前节点的前驱节点
            final Node p = node.predecessor();
            // 如果p是头结点，说明当前节点在真实数据队列的首部，就尝试获取锁（别忘了头结点是虚节点）
            // p == head 说明当前节点虽然进到了阻塞队列，但是是阻塞队列的第一个，因为它的前驱是head
            // 注意，阻塞队列不包含head节点，head一般指的是占有锁的线程，head后面的才称为阻塞队列
            // head是延时初始化的，而且new Node()的时候没有设置任何线程
            // 也就是说，当前的head不属于任何一个线程，所以作为队头
            if (p == head && tryAcquire(arg)) {
                // 获取锁成功，头指针移动到当前node
                // 重新设置队头
                setHead(node);
               
                // 帮助GC回收之前的head
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            
            // 说明p为头节点且当前没有获取到锁（可能是非公平锁被抢占了）或者是p不为头结点，这个时候就要判断当前node是否要
            // 被阻塞（被阻塞条件：前驱节点的waitStatus为-1），防止无限循环浪费资源。
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}

    // 靠前驱节点判断当前线程是否应该被阻塞
	// 当前线程没有抢到锁，是否需要挂起当前线程?
	// 第一个参数是前驱节点，第二个参数才是代表当前线程的节点
  private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
        // 获取前驱结点的节点状态
        int ws = pred.waitStatus;
        // 前驱节点的 waitStatus == -1 ，说明前驱节点状态正常，当前线程需要挂起，直接可以返回true
        if (ws == Node.SIGNAL)
            /*
             * This node has already set status asking a release
             * to signal it, so it can safely park.
             */
            return true;
        // 前驱节点 waitStatus大于0 ，之前说过，大于0 说明前驱节点取消了排队
        // 这里需要知道这点：进入阻塞队列排队的线程会被挂起，而唤醒的操作是由前驱节点完成的。
        // 所以下面这块代码说的是将当前节点的prev指向waitStatus<=0的节点，
        if (ws > 0) {
            /*
             * Predecessor was cancelled. Skip over predecessors and
             * indicate retry.
             */
            do {
                // 环向前查找取消节点，把取消节点从队列中剔除
                node.prev = pred = pred.prev;
            } while (pred.waitStatus > 0);
            pred.next = node;
        } else {
            // 前驱节点的waitStatus不等于-1和1，那也就是只可能是0，-2，-3
            // 在我们前面的源码中，都没有看到有设置waitStatus的，所以每个新的node入队时，waitStatu都是0
            // 正常情况下，前驱节点是之前的 tail，那么它的 waitStatus 应该是 0
            // 用CAS将前驱节点的waitStatus设置为Node.SIGNAL(也就是-1)
            /*
             * waitStatus must be 0 or PROPAGATE.  Indicate that we
             * need a signal, but don't park yet.  Caller will need to
             * retry to make sure it cannot acquire before parking.
             */
            compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
        }
        return false;
    }


  
   // 这里用了LockSupport.park(this)来挂起线程，然后就停在这里了，等待被唤醒
   private final boolean parkAndCheckInterrupt() {
        LockSupport.park(this); // 挂起线程
        return Thread.interrupted(); // 检查线程中断标志位，并且清楚中断标记
    }
```

注：setHead方法是把当前节点置为虚节点，但并没有修改waitStatus，因为它是一直需要用的数据。

parkAndCheckInterrupt主要用于挂起当前线程，阻塞调用栈，返回当前线程的中断状态

因为我们知道，head节点就是个哑节点，它不代表任何线程，或者代表了持有锁的线程，如果当前节点的前驱节点就是head节点，那就说明当前节点已经是排在整个等待队列最前面的了。






```java
protected final boolean tryRelease(int releases) {
    int c = getState() - releases;
    // 释放锁的线程当前必须是持有锁的线程
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    // 是否完全释放
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null);
    }
    setState(c);
    return free;
}
```



```java
/**
 * 唤醒后继节点
 * Wakes up node's successor, if one exists.
 *
 * @param node the node
 */
private void unparkSuccessor(Node node) {
    /*
     * If status is negative (i.e., possibly needing signal) try
     * to clear in anticipation of signalling.  It is OK if this
     * fails or if status is changed by waiting thread.
     */
    int ws = node.waitStatus;
    // 如果head节点的ws比0小, 则直接将它设为0
    if (ws < 0)
        compareAndSetWaitStatus(node, ws, 0);

    /*
     * Thread to unpark is held in successor, which is normally
     * just the next node.  But if cancelled or apparently null,
     * traverse backwards from tail to find the actual
     * non-cancelled successor.
     */
    // 通常情况下, 要唤醒的节点就是自己的后继节点
    // 如果后继节点存在且也在等待锁, 那就直接唤醒它
    // 但是有可能存在 后继节点取消等待锁 的情况
    // 此时从尾节点开始向前找起, 直到找到距离head节点最近的ws<=0的节点
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        // 注意这里是从队尾开始找，是有原因的
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    // 如果找到了还在等待锁的节点,则唤醒它
    if (s != null)
        LockSupport.unpark(s.thread);
}
```

`h!=null` 我们容易理解, `h.waitStatus != 0`是个什么意思呢?

我不妨逆向来思考一下, waitStatus在什么条件下等于0? 从上一篇文章到现在, 我们发现之前给 waitStatus赋值过的地方只有一处, 那就是[`shouldParkAfterFailedAcquire`](https://segmentfault.com/a/1190000015739343#articleHeader9) 函数中将前驱节点的 `waitStatus`设为`Node.SIGNAL`, 除此之外, 就没有了.

然而, 真的没有了吗???

其实还有一处, 那就是新建一个节点的时候, 在[`addWaiter`](https://segmentfault.com/a/1190000015739343#articleHeader7) 函数中, 当我们将一个新的节点添加进队列或者初始化空队列的时候, 都会新建节点 而新建的节点的`waitStatus`在没有赋值的情况下都会初始化为0.

所以当一个head节点的`waitStatus`为0说明什么呢, 说明这个head节点后面没有在挂起等待中的后继节点了(如果有的话, head的ws就会被后继节点设为`Node.SIGNAL`了), 自然也就不要执行 `unparkSuccessor` 操作了.

## FairSync 公平锁

```java
static final class FairSync extends Sync {
    private static final long serialVersionUID = -3000897897090466540L;

	// 获取锁
    final void lock() {
        acquire(1);
    }

    /**
     * 判断当前锁有没有被占用
     * Fair version of tryAcquire.  Don't grant access unless
     * recursive call or no waiters or is first.
     */
    protected final boolean tryAcquire(int acquires) {
        final Thread current = Thread.currentThread();
        // state == 0 此时此刻没有线程持有锁
        int c = getState();
        if (c == 0) {
            // 虽然此时此刻锁是可以用的，但是这是公平锁，既然是公平，就得讲究先来后到
            // 看看有没有别人在队列中等了半天了
            if (!hasQueuedPredecessors() &&
                
                // 如果没有线程在等待，那就用CAS尝试一下，成功了就获取到锁了
                // 不成功的话，只能说明一个问题，就在刚刚几乎同一时刻有个线程抢先了
                compareAndSetState(0, acquires)) {
                // 到这里就是获取到锁了，标记一下，告诉大家，现在是我占用了锁,后面可以用来判断可重入
                setExclusiveOwnerThread(current);
                return true;
            }
        }
        // 进入这里说明已经有线程获取锁了，至于是不是自己，获取getExclusiveOwnerThread()比较下就知道了
        else if (current == getExclusiveOwnerThread()) {
            // 原来时线程自己获取的锁，继续执行，注意state就会比1大了
            int nextc = c + acquires;
            if (nextc < 0)
                throw new Error("Maximum lock count exceeded");
            setState(nextc);
            return true;
        }
        return false;
    }
}
```

## NonfairSync 非公平锁

```java
static final class NonfairSync extends Sync {
    private static final long serialVersionUID = 7316153563782823691L;

    /**
     * Performs lock.  Try immediate barge, backing up to normal
     * acquire on failure.
     */
    final void lock() {
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

```java
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

## unlock

由于锁的释放操作对于公平锁和非公平锁都是一样的, 所以, `unlock`的逻辑并没有放在 `FairSync` 或 `NonfairSync` 里面, 而是直接定义在 `ReentrantLock`类中:

```java
public void unlock() {
    sync.release(1);
}
```

release方法定义在AQS类中，描述了释放锁的流程

```java
public final boolean release(int arg) {
    
    if (tryRelease(arg)) {  // 该方法由继承AQS的子类实现, 为释放锁的具体逻辑
        // 锁成功释放之后, 接下来就是唤醒后继节点
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h); // 唤醒后继线程
        return true;
    }
    return false;
}
```

`tryRelease`方法由ReentrantLock的静态类`Sync`实现

能执行到释放锁的线程, 一定是已经获取了锁的线程另外, 相比获取锁的操作, 这里并没有使用任何CAS操作, 也是因为当前线程已经持有了锁, 所以可以直接安全的操作, 不会产生竞争.



`h!=null` 我们容易理解, `h.waitStatus != 0`是个什么意思呢?

我不妨逆向来思考一下, waitStatus在什么条件下等于0? 从上一篇文章到现在, 我们发现之前给 waitStatus赋值过的地方只有一处, 那就是[`shouldParkAfterFailedAcquire`](https://segmentfault.com/a/1190000015739343#articleHeader9) 函数中将前驱节点的 `waitStatus`设为`Node.SIGNAL`, 除此之外, 就没有了.

然而, 真的没有了吗???

其实还有一处, 那就是新建一个节点的时候, 在[`addWaiter`](https://segmentfault.com/a/1190000015739343#articleHeader7) 函数中, 当我们将一个新的节点添加进队列或者初始化空队列的时候, 都会新建节点 而新建的节点的`waitStatus`在没有赋值的情况下都会初始化为0.

所以当一个head节点的`waitStatus`为0说明什么呢, 说明这个head节点后面没有在挂起等待中的后继节点了(如果有的话, head的ws就会被后继节点设为`Node.SIGNAL`了), 自然也就不要执行 `unparkSuccessor` 操作了.

```java
protected final boolean tryRelease(int releases) {
    // 这里的操作主要是针对可重入锁的情况下, c可能大于1
    int c = getState() - releases;
    // 释放锁的线程当前必须是持有锁的线程
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {
        //  如果c为0了, 说明锁已经完全释放了
        free = true;
        setExclusiveOwnerThread(null);
    }
    setState(c);
    return free;
}
```

锁成功释放之后, 接下来就是唤醒后继节点了, 这个方法同样定义在AQS中.

```java
private void unparkSuccessor(Node node) {
    /*
     * If status is negative (i.e., possibly needing signal) try
     * to clear in anticipation of signalling.  It is OK if this
     * fails or if status is changed by waiting thread.
     */
    // 如果head节点的ws比0小, 则直接将它设为0
    int ws = node.waitStatus;
    if (ws < 0)
        compareAndSetWaitStatus(node, ws, 0);

    /*
     * Thread to unpark is held in successor, which is normally
     * just the next node.  But if cancelled or apparently null,
     * traverse backwards from tail to find the actual
     * non-cancelled successor.
     */
    
    // 通常情况下, 要唤醒的节点就是自己的后继节点
    // 如果后继节点存在且也在等待锁, 那就直接唤醒它
    // 但是有可能存在 后继节点取消等待锁 的情况
    // 此时从尾节点开始向前找起, 直到找到距离head节点最近的ws<=0的节点
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    // 如果找到了还在等待锁的节点,则唤醒它
    if (s != null)
        LockSupport.unpark(s.thread);
}
```

## cancelAcquire

```java
private void cancelAcquire(Node node) {
    // Ignore if node doesn't exist
    if (node == null)
        return;

    // 设置该节点不关联任何线程，也就是虚节点
    node.thread = null;

    // 通过前驱节点，跳过取消状态的node
    // Skip cancelled predecessors
    Node pred = node.prev;
    while (pred.waitStatus > 0)
        node.prev = pred = pred.prev;

    // 获取过滤后的前驱节点的后继节点
    // predNext is the apparent node to unsplice. CASes below will
    // fail if not, in which case, we lost race vs another cancel
    // or signal, so no further action is necessary.
    Node predNext = pred.next;

    // 把当前node的状态设置为CANCELLED
    // Can use unconditional write instead of CAS here.
    // After this atomic step, other Nodes can skip past us.
    // Before, we are free of interference from other threads.
    node.waitStatus = Node.CANCELLED;

    // If we are the tail, remove ourselves.
    if (node == tail && compareAndSetTail(node, pred)) {
        compareAndSetNext(pred, predNext, null);
    } else {
        // If successor needs signal, try to set pred's next-link
        // so it will get one. Otherwise wake it up to propagate.
        int ws;
        if (pred != head &&
            ((ws = pred.waitStatus) == Node.SIGNAL ||
             (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&
            pred.thread != null) {
            Node next = node.next;
            if (next != null && next.waitStatus <= 0)
                compareAndSetNext(pred, predNext, next);
        } else {
            unparkSuccessor(node);
        }

        node.next = node; // help GC
    }
}
```
