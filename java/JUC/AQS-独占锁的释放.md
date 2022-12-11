## 前言

 JAVA的内置锁在退出临界区之后是会自动释放锁的, 但是`ReentrantLock`这样的显式锁是需要自己显式的释放的, 所以在加锁之后一定不要忘记在finally块中进行显式的锁释放:

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

## ReentrantLock的锁释放

由于锁的释放操作对于公平锁和非公平锁都是一样的, 所以, `unlock`的逻辑并没有放在 `FairSync` 或 `NonfairSync` 里面, 而是直接定义在 `ReentrantLock`类中:

```java
public void unlock() {
    sync.release(1);
}
```

## release

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

能执行到释放锁的线程, 一定是已经获取了锁的线程，另外, 相比获取锁的操作, 这里并没有使用任何CAS操作, 也是因为当前线程已经持有了锁, 所以可以直接安全的操作, 不会产生竞争.



`h!=null` 我们容易理解, `h.waitStatus != 0`是个什么意思呢?

我不妨逆向来思考一下, waitStatus在什么条件下等于0? 从上一篇文章到现在, 我们发现之前给 waitStatus赋值过的地方只有一处, 那就是[`shouldParkAfterFailedAcquire`](https://segmentfault.com/a/1190000015739343#articleHeader9) 函数中将前驱节点的 `waitStatus`设为`Node.SIGNAL`, 除此之外, 就没有了.

然而, 真的没有了吗???

其实还有一处, 那就是新建一个节点的时候, 在[`addWaiter`](https://segmentfault.com/a/1190000015739343#articleHeader7) 函数中, 当我们将一个新的节点添加进队列或者初始化空队列的时候, 都会新建节点 而新建的节点的`waitStatus`在没有赋值的情况下都会初始化为0.

所以当一个head节点的`waitStatus`为0说明什么呢, 说明这个head节点后面没有在挂起等待中的后继节点了(如果有的话, head的ws就会被后继节点设为`Node.SIGNAL`了), 自然也就不要执行 `unparkSuccessor` 操作了.

## unparkSuccessor

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

