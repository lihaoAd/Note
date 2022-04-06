## binder_thread_read

主体处理逻辑如下:

- 首先根据`consumed`，即`binder_write_read`结构体的`read_consumed`域，是否为0判断当前的可写入指针是不是在`bwr.read_buffer`的起始位置，是的话就先写入一个`BR_NOOP`命令。由此可见，在`bwr.read_buffer`中，它**总是以一个`BR_NOOP`命令开头的**；

- 接着检查之前的处理是否有错误发生（`return_error`，`return_error2`)，是的话将错误码写入用户态地址空间的`read_buffer`中，然后跳过中间的处理逻辑，直接到达最后判断是否需要创建线程操作；

- 如果之前没有错误发生，就接着看当前线程任务栈及`todo`队列是否还有任务未处理，以决定是等待在线程还是在进程的`wait`队列上。如果没有任务要处理 —— `todo`队列为空，且用户态不需要内核态返回值，则根据进程是否设置**非阻塞**标志位，设置了就返回`-EAGAIN`，表示稍后重试；未设置且没有任务要处理就等待在进程/线程的`wait`队列上，等到有任务要处理时再被`wake_up`。这里有三个小点需要注意：

  - 线程进入睡眠前要先释放之前拿到的binder锁，这个锁是一个大锁，binder驱动的全局数据都靠其保护，如果线程睡眠前不释放锁，其他binder线程很可能都要阻塞在等待这个锁上。当线程再次等被唤醒后，会重新获取锁。
  - 线程在进入睡眠前和唤醒后要分别设置和取消`BINDER_LOOPER_STATE_WAITING`状态标志位。
  - 如果线程是等待进程的`wait`队列上，睡眠前和唤醒后要分别*增减*空闲线程数—— `proc->ready_threads`。

- 开始循环处理线程/进程的`todo`队列上的任务。处理进程`todo`队列的条件是线程的`todo`队列已经处理完了，进程的`todo`队列不为空，且之前等待在进程的`wait`队列上。对于每一个`binder_work`的处理流程，则根据其类型，走各自的处理逻辑：
  - `BINDER_WORK_TRANSACTION`, 根据`binder_work`在`binder_transaction`结构体的偏移计算出`binder_transaction`对象的地址。然后根据是Client->Server的binder请求还是Server->Client的回复（t->buffer->target_node是否为NULL），确定发送给用户态进程的`cmd`是`BR_TRANSACTION`还是`BR_REPLY`。如果是Client->Server的请求，还要根据`target_node`，得到binder server对象在server所在进程的用户态地址（`cookie`）及其相关的引用计数（`ptr`），填入`binder_transaction_data`中。再就是将binder请求的相关信息，如发送进程的pid，有效用户id，`code`, `flags`及数据相关信息。这里需要单独提出来讲一下的是transaction相关data区及offsets区的内容，并不需要从内核态拷贝到用户态的操作，只需将`binder_transaction_data`的`data.ptr.buffer`和`data.ptr.offsets`两个指针修改为相应用户态地址即可。可以这样做的原因是`binder_buffer`的`data`所指的缓冲区的物理页框同时映射到了用户态和内核态的虚拟机地址空间，即`binder_buffer.data`(内核态)和`binder_buffer.data + user_buffer_offset`（用户态）两段虚拟地址空间映射的是同一组物理页框。这里就是Binder进程间通信高效的精髓所在，只需要一次发送端的用户态到内核态拷贝即可，接收端只需简单修改指针就好了。这部分内容的不太清楚的可以参考一下之前写的[Binder驱动之binder_buffer的分配与回收](https://www.jianshu.com/p/82dc9fa2031c)第二节内容。剩下的工作就是将`cmd`和`binder_transaction_data`发送到用户态（`binder_write_read.read_buffer`)，从`todo`移除该`binder_work`，加入事务栈（BR_TRANSACTION）或者释放`binder_transaction`（BR_REPLY）等。还有一个要说明的是对于`BINDER_WORK_TRANSACTION`的`binder_work`，一次`binder_thread_read`操作**只会执行一个**，处理完了就跳出循环，以便线程可以回到用户态处理本次Binder Transaction。

- `BINDER_WORK_TRANSACTION_COMPLETED`，这个的主要用途是用来告知进程binder请求或者回复已经发出去
- `BINDER_WORK_NODE`，这是一个处理`binder_node`与`binder service(BBinder)`强弱引用计数相关的命令。当`binder_node`有强/弱引用时，确保其对应服务端进程用户态地址空间中binder service对象，不会被释放；当`binder_node`有强/弱引用归0时，递减其对应服务端进程用户态地址空间中binder service对象引用计数，以确保用户地址空间的对象会被正确释放。
- `BINDER_WORK_DEAD_BINDER`, `BINDER_WORK_DEAD_BINDER_AND_CLEAR`, `BINDER_WORK_CLEAR_DEATH_NOTIFICATION`，这三种`binder_work`是binder service死亡相关几个`work`。从前文的`binder_thread_write`中的死亡通知的几个命令中，已经基本讲清楚了这几个类型及队列的转移过程，可以回头重新看一下.

```c
static int binder_thread_read(struct binder_proc *proc, struct binder_thread *thread,
	void  __user *buffer, int size, signed long *consumed, int non_block)
{
	void __user *ptr = buffer + *consumed;
	void __user *end = buffer + size;

	int ret = 0;
	int wait_for_proc_work;

	if (*consumed == 0) {
		if (put_user(BR_NOOP, (uint32_t __user *)ptr))
			return -EFAULT;
		ptr += sizeof(uint32_t);
	}

retry:
    // 如果线程事务栈和todo队列都为空，说明此时没有要当前线程处理的任务，将增加空闲线程的计数器（即将wait_for_proc_work设为1），
    // 让线程等待在进程的wait队列上
	wait_for_proc_work = thread->transaction_stack == NULL && list_empty(&thread->todo);

	if (thread->return_error != BR_OK && ptr < end) {
        // 之前在binder_transaction或者binder death时发生了错误
		if (thread->return_error2 != BR_OK) {
            // 发送reply时发生了错误，将错误返回给进程用户态
			if (put_user(thread->return_error2, (uint32_t __user *)ptr))
				return -EFAULT;
			ptr += sizeof(uint32_t);
			if (ptr == end)
				goto done;
			thread->return_error2 = BR_OK;
		}
		if (put_user(thread->return_error, (uint32_t __user *)ptr))
			return -EFAULT;
		ptr += sizeof(uint32_t);
		thread->return_error = BR_OK;
		goto done;
	}


    // 即将进入睡眠等待区，这会导致进程/线程进入阻塞状态，先将线程状态改为BINDER_LOOPER_STATE_WAITING
	thread->looper |= BINDER_LOOPER_STATE_WAITING;
	if (wait_for_proc_work)
        // 空闲线程数+1
		proc->ready_threads++;
    
    // 线程/进程将可能进入阻塞等待状态，先释放锁,这个锁是在binder_ioctl开始执行就拿了
	mutex_unlock(&binder_lock);
	if (wait_for_proc_work) {
		if (!(thread->looper & (BINDER_LOOPER_STATE_REGISTERED |
					BINDER_LOOPER_STATE_ENTERED))) {
			binder_user_error("binder: %d:%d ERROR: Thread waiting "
				"for process work before calling BC_REGISTER_"
				"LOOPER or BC_ENTER_LOOPER (state %x)\n",
				proc->pid, thread->pid, thread->looper);
            // 线程还未进入binder循环，输出错误信息，并阻塞直到binder_stop_on_user_error小于2
			wait_event_interruptible(binder_user_error_wait, binder_stop_on_user_error < 2);
		}
		binder_set_nice(proc->default_priority);
       
        // 设置了非阻塞标识
		if (non_block) {
            // 检查当前进程是否有工作待处理，如果没有就将返回值设为-EAGAIN，以便用户进程稍后重试
			if (!binder_has_proc_work(proc, thread))
				ret = -EAGAIN;
		} else
            // 如果是阻塞的读操作，则让进程阻塞在proc的wait队列上，直到binder_has_proc_work(thread)为true，即进程有工作待处理
			ret = wait_event_interruptible_exclusive(proc->wait, binder_has_proc_work(proc, thread));
	} else {
        // 读操作设置了非阻塞标识
		if (non_block) {
            // 检查当前线程是否有工作待处理，如果没有就将返回值设为-EAGAIN，以便用户进程稍后重试
			if (!binder_has_thread_work(thread))
				ret = -EAGAIN;
		} else
            // 如果是阻塞的读操作，则让线程阻塞在thread的wait队列上，直到binder_has_thread_work(thread)为true，即线程有工作待处理
			ret = wait_event_interruptible(thread->wait, binder_has_thread_work(thread));
	}
    // 运行到这里，要么是线程/进程没有工作待处理，但是讲返回值ret设置成了-EAGAIN；要么是线程/进程已经有工作待处理了
	mutex_lock(&binder_lock);
	if (wait_for_proc_work)
        // 空闲线程数减1
		proc->ready_threads--;
    // 移除线程等待标志位
	thread->looper &= ~BINDER_LOOPER_STATE_WAITING;

	if (ret)
		return ret;

    // 开始循环处理thread/proc的todo队列上的每一个binder_work
	while (1) {
		uint32_t cmd;
		struct binder_transaction_data tr;
		struct binder_work *w;
		struct binder_transaction *t = NULL;

        // 取出一个binder work来处理
		if (!list_empty(&thread->todo))
            // 从线程的待处理列表队头中取出一项工作处理
			w = list_first_entry(&thread->todo, struct binder_work, entry);
		else if (!list_empty(&proc->todo) && wait_for_proc_work)
            // 从进程的待处理列表的队头中取出一项工作处理
			w = list_first_entry(&proc->todo, struct binder_work, entry);
		else {
			if (ptr - buffer == 4 && !(thread->looper & BINDER_LOOPER_STATE_NEED_RETURN)) /* no data added */
				goto retry;
			break;
		}

		if (end - ptr < sizeof(tr) + 4)
			break;

		switch (w->type) {
        // 要处理的是一个事务（Binder请求）
		case BINDER_WORK_TRANSACTION: 
             ...
             break;
		case BINDER_WORK_TRANSACTION_COMPLETE: 
			...
			 break;
		case BINDER_WORK_NODE: 
             ...   
             break;
		case BINDER_WORK_DEAD_BINDER:
		case BINDER_WORK_DEAD_BINDER_AND_CLEAR:
		case BINDER_WORK_CLEAR_DEATH_NOTIFICATION: 
             ...
             break;
		}

        // 当binder_work的类型是BINDER_WORK_TRANSACTION时，t不为NULL
		if (!t)
			continue;

        // 接下来开始处理**TRANSACTION**，将binder_transaction转换为进程用户态使用的binder_transaction_data
        // 当binder客户端向binder服务端发送请求时，target_node为binder服务端的binder_node地址，如果是binder服务端回复客户端，则target_node为NULL
        
		BUG_ON(t->buffer == NULL);
        // Client->Server的binder请求	
		if (t->buffer->target_node) {
            // 将引用计数器地址及BBinder地址写入transaction data中， 
            // 即将struct binder_transaction转化为进程用户态可处理struct binder_transaction_data结构体
			struct binder_node *target_node = t->buffer->target_node;
			tr.target.ptr = target_node->ptr;
			tr.cookie =  target_node->cookie;
			t->saved_priority = task_nice(current);
			if (t->priority < target_node->min_priority &&
			    !(t->flags & TF_ONE_WAY))
				binder_set_nice(t->priority);
			else if (!(t->flags & TF_ONE_WAY) ||
				 t->saved_priority > target_node->min_priority)
				binder_set_nice(target_node->min_priority);
			cmd = BR_TRANSACTION;
		} else {
            // Client->Server的binder请求的回复
            // 将引用计数器地址及BBinder地址从transaction data清空
            // 因为Client无法从地址中获取相应的对象，这个地址只有在服务端的进程的地址空间才有效
			tr.target.ptr = NULL;
			tr.cookie = NULL;
			cmd = BR_REPLY;
		}
        
        // 设置transacton的业务代码，一种代码对应一种binder server提供的服务
		tr.code = t->code;
        
        // 设置transacton的标识位
		tr.flags = t->flags;
        
        // 请求线程的有eudi
		tr.sender_euid = t->sender_euid;

        // 设置发送端进程id
		if (t->from) {
			struct task_struct *sender = t->from->proc->tsk;
			tr.sender_pid = task_tgid_nr_ns(sender, current->nsproxy->pid_ns);
		} else {
			tr.sender_pid = 0;
		}

		tr.data_size = t->buffer->data_size;
		tr.offsets_size = t->buffer->offsets_size;
		tr.data.ptr.buffer = (void *)t->buffer->data + proc->user_buffer_offset;
		tr.data.ptr.offsets = tr.data.ptr.buffer + ALIGN(t->buffer->data_size, sizeof(void *));

		if (put_user(cmd, (uint32_t __user *)ptr))
			return -EFAULT;
		ptr += sizeof(uint32_t);
		if (copy_to_user(ptr, &tr, sizeof(tr)))
			return -EFAULT;
		ptr += sizeof(tr);

		binder_stat_br(proc, thread, cmd);
		if (binder_debug_mask & BINDER_DEBUG_TRANSACTION)
			printk(KERN_INFO "binder: %d:%d %s %d %d:%d, cmd %d"
				"size %zd-%zd ptr %p-%p\n",
			       proc->pid, thread->pid,
			       (cmd == BR_TRANSACTION) ? "BR_TRANSACTION" : "BR_REPLY",
			       t->debug_id, t->from ? t->from->proc->pid : 0,
			       t->from ? t->from->pid : 0, cmd,
			       t->buffer->data_size, t->buffer->offsets_size,
			       tr.data.ptr.buffer, tr.data.ptr.offsets);

		list_del(&t->work.entry);
		t->buffer->allow_user_free = 1;
		if (cmd == BR_TRANSACTION && !(t->flags & TF_ONE_WAY)) {
			t->to_parent = thread->transaction_stack;
			t->to_thread = thread;
			thread->transaction_stack = t;
		} else {
			t->buffer->transaction = NULL;
			kfree(t);
			binder_stats.obj_deleted[BINDER_STAT_TRANSACTION]++;
		}
		break;
	}

done:

	*consumed = ptr - buffer;
	if (proc->requested_threads + proc->ready_threads == 0 &&
	    proc->requested_threads_started < proc->max_threads &&
	    (thread->looper & (BINDER_LOOPER_STATE_REGISTERED |
	     BINDER_LOOPER_STATE_ENTERED)) /* the user-space code fails to */
	     /*spawn a new thread if we leave this out */) {
		proc->requested_threads++;
		if (binder_debug_mask & BINDER_DEBUG_THREADS)
			printk(KERN_INFO "binder: %d:%d BR_SPAWN_LOOPER\n",
			       proc->pid, thread->pid);
		if (put_user(BR_SPAWN_LOOPER, (uint32_t __user *)buffer))
			return -EFAULT;
	}
	return 0;
}
```

## BINDER_WORK_TRANSACTION

```c
t = container_of(w, struct binder_transaction, work);
```

## BINDER_WORK_TRANSACTION_COMPLETE

```c
cmd = BR_TRANSACTION_COMPLETE;
// 发送 BR_TRANSACTION_COMPLETE 给用户进程
if (put_user(cmd, (uint32_t __user *)ptr))
	return -EFAULT;
ptr += sizeof(uint32_t);

// 更新统计数据
binder_stat_br(proc, thread, cmd);
if (binder_debug_mask & BINDER_DEBUG_TRANSACTION_COMPLETE)
	printk(KERN_INFO "binder: %d:%d BR_TRANSACTION_COMPLETE\n",
	       proc->pid, thread->pid);

// 从todo队列中移除
list_del(&w->entry);
// 释放在binder_thread_write在处理BC_TRANSACTION命令时在binder_transaction中申请的binder_work
kfree(w);
// 更新BINDER_STAT_TRANSACTION_COMPLETE统计数据
binder_stats.obj_deleted[BINDER_STAT_TRANSACTION_COMPLETE]++;
```

## BINDER_WORK_NODE

取出的binder_work是一个binder_node

```c
struct binder_node *node = container_of(w, struct binder_node, work);
uint32_t cmd = BR_NOOP;
const char *cmd_name;
int strong = node->internal_strong_refs || node->local_strong_refs;
int weak = !hlist_empty(&node->refs) || node->local_weak_refs || strong;
if (weak && !node->has_weak_ref) { 
    // 弱引用计数不为0，但是弱引用标志位为0
	cmd = BR_INCREFS;
    // 发送BR_INCREFS命令给进程用户态，让其增加弱引用计数
	cmd_name = "BR_INCREFS";
	node->has_weak_ref = 1; // 设置弱引用标志位
	node->pending_weak_ref = 1; // 设置pengding标志位，表示（进程用户态）有未处理的弱引用增加命令
	node->local_weak_refs++;  // 增加本地弱引用计数器
} else if (strong && !node->has_strong_ref) {
    // 强引用计数不为0，但是强引用标志位为0
	cmd = BR_ACQUIRE;
    // 发送BR_ACQUIRE命令给进程，让其增加强引用计数
	cmd_name = "BR_ACQUIRE";
	node->has_strong_ref = 1; // 设置强引用标志位
	node->pending_strong_ref = 1; // 设置pengding标志位，表示（进程用户态）有未处理的强引用增加命令
	node->local_strong_refs++; // 增加本地强引用计数器
} else if (!strong && node->has_strong_ref) {
    // 强引用计数为0，但是强引用标志位不为0
	cmd = BR_RELEASE;
	cmd_name = "BR_RELEASE";
	node->has_strong_ref = 0;
} else if (!weak && node->has_weak_ref) {
    // 弱引用计数为0，但是弱引用标志位不为0
	cmd = BR_DECREFS;
	cmd_name = "BR_DECREFS";
	node->has_weak_ref = 0;
}

// 有引用计数相关的命令需要处理
if (cmd != BR_NOOP) {
    // 将命令先发送给进程用户态
	if (put_user(cmd, (uint32_t __user *)ptr))
		return -EFAULT;
	ptr += sizeof(uint32_t);
    
    // BBinder的引用计数器的地址发送给进程的用户态地址空间read_buffer
	if (put_user(node->ptr, (void * __user *)ptr))
		return -EFAULT;
	ptr += sizeof(void *);
    
    // BBinder的地址发送给进程
	if (put_user(node->cookie, (void * __user *)ptr))
		return -EFAULT;
	ptr += sizeof(void *);

    // 更新统计数据
	binder_stat_br(proc, thread, cmd);
	if (binder_debug_mask & BINDER_DEBUG_USER_REFS)
		printk(KERN_INFO "binder: %d:%d %s %d u%p c%p\n",
		       proc->pid, thread->pid, cmd_name, node->debug_id, node->ptr, node->cookie);
} else {
    // 不需要增加/减少binder_node的强/弱引用计数
    // 从todo队列中移出
	list_del_init(&w->entry);
	if (!weak && !strong) {
        // binder_node的强弱引用计数都为0，释放该binder_node
		if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
			printk(KERN_INFO "binder: %d:%d node %d u%p c%p deleted\n",
			       proc->pid, thread->pid, node->debug_id, node->ptr, node->cookie);
        // 从proc->nodes红黑树中移除
		rb_erase(&node->rb_node, &proc->nodes);
        
        // 释放binder_node所占内存空间
		kfree(node);
        // 更新统计数据
		binder_stats.obj_deleted[BINDER_STAT_NODE]++;
	} else {
		if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
			printk(KERN_INFO "binder: %d:%d node %d u%p c%p state unchanged\n",
			       proc->pid, thread->pid, node->debug_id, node->ptr, node->cookie);
	}
}
```

## BINDER_WORK_DEAD_BINDER、BINDER_WORK_DEAD_BINDER_AND_CLEAR、BINDER_WORK_CLEAR_DEATH_NOTIFICATION

binder service死亡相关的几个命令处理



```c
struct binder_ref_death *death = container_of(w, struct binder_ref_death, work);
uint32_t cmd;
// 死亡通知清理完毕的消息
if (w->type == BINDER_WORK_CLEAR_DEATH_NOTIFICATION)
    // 回复命令设为BR_CLEAR_DEATH_NOTIFICATION，告知用户进程清除通知完毕的相关处理已完成
	cmd = BR_CLEAR_DEATH_NOTIFICATION_DONE;
else
    // 告诉用户进程，binder service已经死亡
	cmd = BR_DEAD_BINDER;
// 命令发送给用户
if (put_user(cmd, (uint32_t __user *)ptr))
	return -EFAULT;
ptr += sizeof(uint32_t);

// 客户端对象（BpBinder）对应的地址发送到用户进程
if (put_user(death->cookie, (void * __user *)ptr))
	return -EFAULT;
ptr += sizeof(void *);
if (binder_debug_mask & BINDER_DEBUG_DEATH_NOTIFICATION)
	printk(KERN_INFO "binder: %d:%d %s %p\n",
	       proc->pid, thread->pid,
	       cmd == BR_DEAD_BINDER ?
	       "BR_DEAD_BINDER" :
	       "BR_CLEAR_DEATH_NOTIFICATION_DONE",
	       death->cookie);

if (w->type == BINDER_WORK_CLEAR_DEATH_NOTIFICATION) {
	list_del(&w->entry);
	kfree(death);
	binder_stats.obj_deleted[BINDER_STAT_DEATH]++;
} else
    // BINDER_WORK_DEAD_BINDER`和`BINDER_WORK_DEAD_BINDER_AND_CLEAR`移到proc->delivered_deat队列
	list_move(&w->entry, &proc->delivered_death);
if (cmd == BR_DEAD_BINDER)
	goto done; /* DEAD_BINDER notifications can cause transactions */
```

