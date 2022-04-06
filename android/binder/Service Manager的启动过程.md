## main

Service Manager是由init进程负责启动的，而init是在系统启动时启动的，因此Service Manager也是在系统系统启动时启动的。

frameworks/base/cmds/servicemanager/service_manager.c

```c++
int main(int argc, char **argv)
{
    struct binder_state *bs;
    void *svcmgr = BINDER_SERVICE_MANAGER;

    // 1.打开binder设备
    bs = binder_open(128*1024);

    // 2.注册成为上下文管理者
    if (binder_become_context_manager(bs)) {
        LOGE("cannot become context manager (%s)\n", strerror(errno));
        return -1;
    }

    svcmgr_handle = svcmgr;
    //3.循环等待client请求
    binder_loop(bs, svcmgr_handler);
    return 0;
}
```

frameworks/base/cmds/servicemanager/binder.c

```c
struct binder_state
{
    int fd;           // binder_open后会返回一个文件描述符，通过该fd，可以找到内核中的file结构体，通过该file结构体可以找到打开该文件的进程
    void *mapped;     // 内核缓冲区的起始地址
    unsigned mapsize; //映射的内核缓冲区的空间大小
};
```

## binder_open

打开binder设备，并且映射binder设备文件，mapsize就是`128K`,即`128K`的内核缓冲区，调用`binder_open`和内核就会为该进程创建一个`binder_proc`,用来描述该进程在内核中的状态。



```c
struct binder_state *binder_open(unsigned mapsize)
{
    struct binder_state *bs;

    bs = malloc(sizeof(*bs));
    if (!bs) {
        errno = ENOMEM;
        return 0;
    }

    // 打开binder设备，会调用驱动的binder_open,在内核中创建binder_proc
    bs->fd = open("/dev/binder", O_RDWR);
    if (bs->fd < 0) {
        fprintf(stderr,"binder: cannot open device (%s)\n",
                strerror(errno));
        goto fail_open;
    }

    bs->mapsize = mapsize;
    bs->mapped = mmap(NULL, mapsize, PROT_READ, MAP_PRIVATE, bs->fd, 0);
    if (bs->mapped == MAP_FAILED) {
        fprintf(stderr,"binder: cannot map device (%s)\n",
                strerror(errno));
        goto fail_map;
    }

        /* TODO: check version */

    return bs;

fail_map:
    close(bs->fd);
fail_open:
    free(bs);
    return 0;
}
```

## binder_become_context_manager

```c
int binder_become_context_manager(struct binder_state *bs)
{
    return ioctl(bs->fd, BINDER_SET_CONTEXT_MGR, 0);
}
```

## binder_ioctl

drivers/staging/android/binder.c

```c
static long binder_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	int ret;
    // 在打开binder设备时闯将binder_proc,会给filp赋值
	struct binder_proc *proc = filp->private_data;
	struct binder_thread *thread;
	unsigned int size = _IOC_SIZE(cmd);
	void __user *ubuf = (void __user *)arg;


	....

	mutex_lock(&binder_lock);
    
    thread = binder_get_thread(proc);
    ...
	case BINDER_SET_CONTEXT_MGR:
		if (binder_context_mgr_node != NULL) {
			printk(KERN_ERR "binder: BINDER_SET_CONTEXT_MGR already set\n");
			ret = -EBUSY;
			goto err;
		}
		if (binder_context_mgr_uid != -1) {
			if (binder_context_mgr_uid != current->cred->euid) {
				printk(KERN_ERR "binder: BINDER_SET_"
				       "CONTEXT_MGR bad uid %d != %d\n",
				       current->cred->euid,
				       binder_context_mgr_uid);
				ret = -EPERM;
				goto err;
			}
		} else
			binder_context_mgr_uid = current->cred->euid;
    
    	// 创建一个binder_node实体对象
		binder_context_mgr_node = binder_new_node(proc, NULL, NULL);
		if (binder_context_mgr_node == NULL) {
			ret = -ENOMEM;
			goto err;
		}
		binder_context_mgr_node->local_weak_refs++;
		binder_context_mgr_node->local_strong_refs++;
		binder_context_mgr_node->has_strong_ref = 1;
		binder_context_mgr_node->has_weak_ref = 1;
		break;
	...
	}
	ret = 0;
err:
	if (thread)
		thread->looper &= ~BINDER_LOOPER_STATE_NEED_RETURN;
	mutex_unlock(&binder_lock);
	wait_event_interruptible(binder_user_error_wait, binder_stop_on_user_error < 2);
	if (ret && ret != -ERESTARTSYS)
		printk(KERN_INFO "binder: %d:%d ioctl %x %lx returned %d\n", proc->pid, current->pid, cmd, arg, ret);
	return ret;
}
```



## binder_get_thread

drivers/staging/android/binder.c



Service Manager在调用ioctl时，就会创建`binder_thread`结构，用来描述当前线程，这是`Service Manager`的主线程，也是一个Binder线程，这样Binder驱动可以给该线程发送数据。进程的所有binder线程都保存在`binder_proc`的threads这个红黑树上，



```c
static struct binder_thread *binder_get_thread(struct binder_proc *proc)
{
	struct binder_thread *thread = NULL;
	struct rb_node *parent = NULL;
	struct rb_node **p = &proc->threads.rb_node;

	while (*p) {
		parent = *p;
		thread = rb_entry(parent, struct binder_thread, rb_node);

		if (current->pid < thread->pid)
			p = &(*p)->rb_left;
		else if (current->pid > thread->pid)
			p = &(*p)->rb_right;
		else
			break;
	}
	if (*p == NULL) {
		thread = kzalloc(sizeof(*thread), GFP_KERNEL);
		if (thread == NULL)
			return NULL;
		binder_stats.obj_created[BINDER_STAT_THREAD]++;
		thread->proc = proc;   // 关联binder_proc
		thread->pid = current->pid;
		init_waitqueue_head(&thread->wait); // 初始化等待队列
		INIT_LIST_HEAD(&thread->todo);      // 初始化任务todo队列
		rb_link_node(&thread->rb_node, parent, p);
		rb_insert_color(&thread->rb_node, &proc->threads);
        
        // 刚刚创建的binder线程，BINDER_LOOPER_STATE_NEED_RETURN表示需要立刻返回到用户空间
		thread->looper |= BINDER_LOOPER_STATE_NEED_RETURN;
		thread->return_error = BR_OK;
		thread->return_error2 = BR_OK;
	}
	return thread;
}
```

检查对应`threads`红黑树上是否已经有该线程对应的`binder_thread`,



## binder_new_node

drivers/staging/android/binder.c

```c
// ptr:binder本地对象的一个弱引用计数对象的地址
// cookie: binder本地对象地址（BBinder，用户空间创建运行在service）
static struct binder_node * binder_new_node(struct binder_proc *proc, void __user *ptr, void __user *cookie)
{
	struct rb_node **p = &proc->nodes.rb_node;
	struct rb_node *parent = NULL;
	struct binder_node *node;

	while (*p) {
		parent = *p;
		node = rb_entry(parent, struct binder_node, rb_node);

		if (ptr < node->ptr)
			p = &(*p)->rb_left;
		else if (ptr > node->ptr)
			p = &(*p)->rb_right;
		else
			return NULL;
	}

	node = kzalloc(sizeof(*node), GFP_KERNEL);
	if (node == NULL)
		return NULL;
	binder_stats.obj_created[BINDER_STAT_NODE]++;
	rb_link_node(&node->rb_node, parent, p);
	rb_insert_color(&node->rb_node, &proc->nodes);
	node->debug_id = ++binder_last_id;
	node->proc = proc;
	node->ptr = ptr;
	node->cookie = cookie;
	node->work.type = BINDER_WORK_NODE;
	INIT_LIST_HEAD(&node->work.entry);
	INIT_LIST_HEAD(&node->async_todo);
	if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
		printk(KERN_INFO "binder: %d:%d node %d u%p c%p created\n",
		       proc->pid, current->pid, node->debug_id,
		       node->ptr, node->cookie);
	return node;
}
```



## binder_loop

frameworks/base/cmds/servicemanager/binder.c

```c
void binder_loop(struct binder_state *bs, binder_handler func)
{
    int res;
    struct binder_write_read bwr;
    unsigned readbuf[32];

    bwr.write_size = 0;
    bwr.write_consumed = 0;
    bwr.write_buffer = 0;
    
    readbuf[0] = BC_ENTER_LOOPER;
    binder_write(bs, readbuf, sizeof(unsigned));

    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
        bwr.read_buffer = (unsigned) readbuf;

        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);

        if (res < 0) {
            LOGE("binder_loop: ioctl failed (%s)\n", strerror(errno));
            break;
        }

        res = binder_parse(bs, 0, readbuf, bwr.read_consumed, func);
        if (res == 0) {
            LOGE("binder_loop: unexpected reply?!\n");
            break;
        }
        if (res < 0) {
            LOGE("binder_loop: io error %d %s\n", res, strerror(errno));
            break;
        }
    }
}

int binder_write(struct binder_state *bs, void *data, unsigned len)
{
    struct binder_write_read bwr;
    int res;
    bwr.write_size = len;
    bwr.write_consumed = 0;
    bwr.write_buffer = (unsigned) data;
    bwr.read_size = 0;
    bwr.read_consumed = 0;
    bwr.read_buffer = 0;
    res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);
    if (res < 0) {
        fprintf(stderr,"binder_write: ioctl failed (%s)\n",
                strerror(errno));
    }
    return res;
}
```



drivers/staging/android/binder.c

```c
static long binder_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	int ret;
	struct binder_proc *proc = filp->private_data;
	struct binder_thread *thread;
	unsigned int size = _IOC_SIZE(cmd);
	void __user *ubuf = (void __user *)arg;
	
    ...

	mutex_lock(&binder_lock);
	thread = binder_get_thread(proc);
	...

	switch (cmd) {
	case BINDER_WRITE_READ: {
		struct binder_write_read bwr;
		if (size != sizeof(struct binder_write_read)) {
			ret = -EINVAL;
			goto err;
		}
        // 将用户空间的binder_write_read 拷贝到 内核中的 bwr
		if (copy_from_user(&bwr, ubuf, sizeof(bwr))) {
			ret = -EFAULT;
			goto err;
		}
        
		...
            
        // 目前时service manager
        // 此时输入缓冲区长度大于0
        // write_size大于0，表示用户进程有数据发送到驱动，则调用binder_thread_write发送数据 
		if (bwr.write_size > 0) {
			ret = binder_thread_write(proc, thread, (void __user *)bwr.write_buffer, bwr.write_size, &bwr.write_consumed);
			if (ret < 0) {
                // binder_thread_write中有错误发生，则read_consumed设为0，表示kernel没有数据返回给进程
				bwr.read_consumed = 0;
                // 将bwr返回给用户态调用者，bwr在binder_thread_write中会被修改
				if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
					ret = -EFAULT;
				goto err;
			}
		}
        
        // read_size大于0， 表示进程用户态地址空间希望有数据返回给它，则调用binder_thread_read进行处理
		if (bwr.read_size > 0) {
			ret = binder_thread_read(proc, thread, (void __user *)bwr.read_buffer, bwr.read_size, &bwr.read_consumed, filp->f_flags & O_NONBLOCK);
			if (!list_empty(&proc->todo))
                // 读取完后，如果proc->todo链表不为空，则唤醒在proc->wait等待队列上的进程
				wake_up_interruptible(&proc->wait);
			if (ret < 0) {
                // 如果binder_thread_read返回小于0，可能处理一半就中断了，需要将bwr拷贝回进程的用户态地址
				if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
					ret = -EFAULT;
				goto err;
			}
		}
		if (binder_debug_mask & BINDER_DEBUG_READ_WRITE)
			printk(KERN_INFO "binder: %d:%d wrote %ld of %ld, read return %ld of %ld\n",
			       proc->pid, thread->pid, bwr.write_consumed, bwr.write_size, bwr.read_consumed, bwr.read_size);
        // 处理成功的情况，也需要将bwr拷贝回进程的用户态地址空间
		if (copy_to_user(ubuf, &bwr, sizeof(bwr))) {
			ret = -EFAULT;
			goto err;
		}
		break;
	}
	...
	}
	ret = 0;
err:
	if (thread)
		thread->looper &= ~BINDER_LOOPER_STATE_NEED_RETURN;
	mutex_unlock(&binder_lock);
	wait_event_interruptible(binder_user_error_wait, binder_stop_on_user_error < 2);
	if (ret && ret != -ERESTARTSYS)
		printk(KERN_INFO "binder: %d:%d ioctl %x %lx returned %d\n", proc->pid, current->pid, cmd, arg, ret);
	return ret;
}
```



## binder_thread_write

drivers/staging/android/binder.c

```c
int binder_thread_write(struct binder_proc *proc, struct binder_thread *thread, void __user *buffer, int size, signed long *consumed)
{
	uint32_t cmd;
	void __user *ptr = buffer + *consumed;
	void __user *end = buffer + size;

	while (ptr < end && thread->return_error == BR_OK) {
		if (get_user(cmd, (uint32_t __user *)ptr))
			return -EFAULT;
		ptr += sizeof(uint32_t);
		if (_IOC_NR(cmd) < ARRAY_SIZE(binder_stats.bc)) {
			binder_stats.bc[_IOC_NR(cmd)]++;
			proc->stats.bc[_IOC_NR(cmd)]++;
			thread->stats.bc[_IOC_NR(cmd)]++;
		}
		switch (cmd) {
		
                ...
            
		case BC_ENTER_LOOPER:
			...
			...
            // 很简单，添加一个标识，就返回到binder_ioctl，然后就返回到用户空间
			thread->looper |= BINDER_LOOPER_STATE_ENTERED;
			break;
		...
		*consumed = ptr - buffer;
	}
	return 0;
}
```

