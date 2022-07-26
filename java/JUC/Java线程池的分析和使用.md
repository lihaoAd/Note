## 线程池的5种状态

```java

// runState is stored in the high-order bits

// 能接受新提交的任务，并且也能处理阻塞队列中的任务
private static final int RUNNING    = -1 << COUNT_BITS;

// 关闭状态，不在接受新提交的任务，但却可以继续处理阻塞队列中的已保存的任务
private static final int SHUTDOWN   =  0 << COUNT_BITS;

// 不能接受新任务，也不处理队列中的任务，会中断正在处理任务的线程
private static final int STOP       =  1 << COUNT_BITS;

// 所有的任务都已终止了，workCount(有效线程数)为0
private static final int TIDYING    =  2 << COUNT_BITS;

// 在terminated()方法执行完后进入该状态
private static final int TERMINATED =  3 << COUNT_BITS;

```

线程池运行的状态，并不是用户显式设置的，而是伴随着线程池的运行，由内部来维护。线程池内部使用一个变量维护两个值：运行状态(runState)和线程数量 (workerCount)。在具体实现中，线程池将运行状态(runState)、线程数量 (workerCount)两个关键参数的维护放在了一起，如下代码所示：

```java
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
```

`ctl`这个AtomicInteger类型，是对线程池的运行状态和线程池中有效线程的数量进行控制的一个字段， 它同时包含两部分的信息：线程池的运行状态 (runState) 和线程池内有效线程的数量 (workerCount)，`高3位`保存runState，`低29位`保存workerCount，两个变量之间互不干扰。用一个变量去存储两个值，可避免在做相关决策时，出现不一致的情况，不必为了维护两者的一致，而占用锁资源。通过阅读线程池源代码也可以发现，经常出现要同时判断线程池运行状态和线程数量的情况。线程池也提供了若干方法去供用户获得线程池当前的运行状态、线程个数。这里都使用的是位运算的方式，相比于基本运算，速度也会快很多。

关于内部封装的获取生命周期状态、获取线程池线程数量的计算方法如以下代码所示：

```java
private static final int COUNT_BITS = Integer.SIZE - 3;
private static final int CAPACITY   = (1 << COUNT_BITS) - 1;

private static int runStateOf(int c)     { return c & ~CAPACITY; } //计算当前运行状态
private static int workerCountOf(int c)  { return c & CAPACITY; }  //计算当前线程数量
private static int ctlOf(int rs, int wc) { return rs | wc; }   //通过状态和线程数生成ctl
```

![图3 线程池生命周期](../img/582d1606d57ff99aa0e5f8fc59c7819329028.png)

### RUNNING

线程池处在RUNNING状态时，能够接收新任务，以及对已添加的任务进行处理。线程池的初始化状态是RUNNING。换句话说，线程池被一旦被创建，就处于RUNNING状态





## ThreadPoolExecutor

```java
public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          ThreadFactory threadFactory,
                          RejectedExecutionHandler handler) {
    if (corePoolSize < 0 ||
        maximumPoolSize <= 0 ||
        maximumPoolSize < corePoolSize ||
        keepAliveTime < 0)
        throw new IllegalArgumentException();
    if (workQueue == null || threadFactory == null || handler == null)
        throw new NullPointerException();
    this.acc = System.getSecurityManager() == null ?
            null :
            AccessController.getContext();
    this.corePoolSize = corePoolSize;
    this.maximumPoolSize = maximumPoolSize;
    this.workQueue = workQueue;
    this.keepAliveTime = unit.toNanos(keepAliveTime);
    this.threadFactory = threadFactory;
    this.handler = handler;
}
```

- corePoolSize

  





## execute

```java
public void execute(Runnable command) {
    if (command == null)
        throw new NullPointerException();
    int c = ctl.get();
    if (workerCountOf(c) < corePoolSize) {
        // 工作线程小于 corePoolSize ，就添加添加一个核心线程去执行command
        if (addWorker(command, true))
            //  添加成功，直接返回
            return;
		// 添加失败
        // 什么时候会失败呢？ 假如上面的addWorker有多个线程并发执行到了，就会出现添加核心线程失败的情况
        // 添加失败的线程，重新获取ctl属性
        c = ctl.get();
    }
    // 能运行到这，说明创建核心线程失败了
    // 需要判断当前线程池是否是RUNNING状态
    // 如果执行上面的addWorker时，突然线程池状态发生变化也有可能addWorker失败
    // 如果还是RUNNING状态，就将command添加到队列中
    if (isRunning(c) && workQueue.offer(command)) {
        // 添加任务到工作队列成功
        // 再次获取ctl
        int recheck = ctl.get();
        // 判断线程池是否是RUNNING状态，如果不是RUNNING状态，需要将任务从工作队列中移除
        if (! isRunning(recheck) && remove(command))
            reject(command);
        // 判断工作线程是否为0
        else if (workerCountOf(recheck) == 0)
            // 添加一个空任务非核心线程，为了处理在工作队列中排队的任务
            addWorker(null, false);
    }
    // 如果添加任务到工作队列失败，就添加非核心线程去执行当前任务
    else if (!addWorker(command, false))
        // 添加非核心线程失败，执行reject拒绝策略
        reject(command);
}
```



## addWorker

```java
private boolean addWorker(Runnable firstTask, boolean core) {
    retry:
    
    // 第一个部分，先判断线程池的状态以及工作线程数的判断
    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);

        // Check if queue empty only if necessary.
       
         // 如果线城池的状态不是RUNNING，添加任务就会失败
        if (rs >= SHUTDOWN &&
            // 如果线城池状态是SHUTDOWN ，并且是一个空任务，并且工作队列不为空
            // 满足这三个条件，说明需要处理工作队列中的任务，不能 return false
            ! (rs == SHUTDOWN && firstTask == null && ! workQueue.isEmpty()))
            return false;

        for (;;) {
            int wc = workerCountOf(c);
            if (wc >= CAPACITY ||
                wc >= (core ? corePoolSize : maximumPoolSize))
                return false;
            // CAS自增工作线程数
            if (compareAndIncrementWorkerCount(c))
                // 自增成功，跳出最外层的for循环
                break retry;
            // 自增失败，重新获取ctl，因为ctl可能被别的线程更新了
            c = ctl.get();  // Re-read ctl
            if (runStateOf(c) != rs)
                // 说明并发操作导致线程池状态变化，需要重新判断状态 
                continue retry;
            // 如果状态一直，再次循环判断工作线程数量
            // else CAS failed due to workerCount change; retry inner loop
        }
    }

    // 第二部分，添加工作线程，并启动工作线程
    boolean workerStarted = false;
    boolean workerAdded = false;
    Worker w = null;
    try {
        w = new Worker(firstTask);
        final Thread t = w.thread;
        if (t != null) {
            // 加锁，为什么这里枷锁？
            // 假如这里不加锁,执行shutdown()时，这里就会往添加任务
            final ReentrantLock mainLock = this.mainLock;
            mainLock.lock();
            try {
                // Recheck while holding lock.
                // Back out on ThreadFactory failure or if
                // shut down before lock acquired.
                // 再次获取ctl
                // 假如一个线程执行到 mainLock.lock() 时，另外一个线程 执行shutdown()了怎么办？ 所以这里重新获取ctl
                int rs = runStateOf(ctl.get());

                // 线程池是RUNNING状态，可以添加
                if (rs < SHUTDOWN ||
                    // 线程池是SHUTDOWN状态，且firstTask为null时也可以添加，就是为了处理队列中的任务
                    (rs == SHUTDOWN && firstTask == null)) {
                    
                    if (t.isAlive()) // precheck that t is startable
                        throw new IllegalThreadStateException();
                    // 添加到workers
                    workers.add(w);
                    int s = workers.size();
                    // largestPoolSize记录最大工作线程数
                    if (s > largestPoolSize)
                        largestPoolSize = s;
                    // 添加成功
                    workerAdded = true;
                }
            } finally {
                mainLock.unlock();
            }
            
            if (workerAdded) {
                // 添加成功，及启动成功
                t.start();
                workerStarted = true;
            }
        }
    } finally {
        if (! workerStarted)
            addWorkerFailed(w);
    }
    return workerStarted;
}
```