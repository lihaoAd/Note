## 前言

共享锁与独占锁最大的区别在于，独占锁是**独占的，排他的**，因此在独占锁中有一个`exclusiveOwnerThread`属性，用来记录当前持有锁的线程。**当独占锁已经被某个线程持有时，其他线程只能等待它被释放后，才能去争锁，并且同一时刻只有一个线程能争锁成功。**

而对于共享锁而言，由于锁是可以被共享的，因此**它可以被多个线程同时持有**。换句话说，如果一个线程成功获取了共享锁，那么其他等待在这个共享锁上的线程就也可以尝试去获取锁，并且极有可能获取成功。





## 共享锁的获取

```java
public final void acquireShared(int arg) {
    if (tryAcquireShared(arg) < 0)
        doAcquireShared(arg);
}


private void doAcquireShared(int arg) {
    	// 进入阻塞队列
        final Node node = addWaiter(Node.SHARED);
        boolean failed = true;
        try {
            boolean interrupted = false;
            // 自旋
            for (;;) {
                // 前置节点
                final Node p = node.predecessor();
                if (p == head) {
                    int r = tryAcquireShared(arg);
                    // 大于等于0标识获取锁成功
                    if (r >= 0) {
                        setHeadAndPropagate(node, r);
                        p.next = null; // help GC
                        if (interrupted)
                            selfInterrupt();
                        failed = false;
                        return;
                    }
                }
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    interrupted = true;
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
```

共享锁用的是`addWaiter(Node.SHARED)`





