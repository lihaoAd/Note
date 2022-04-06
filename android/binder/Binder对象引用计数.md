## 引用计数

在Client个Server进行一次通信过程中，涉及四种类型的对象，分别是位于驱动中的Binder实体对象（binder_node）和Binder引用对象（binder_ref)，以及位于Binder库中的Binder本地对象（BBinder）和Binder代理对象（Bpbinder）。



## Binder本地对象的生命周期

```c++
template<typename INTERFACE> class BnInterface : public INTERFACE, public BBinder
{
public:
    virtual sp<IInterface>      queryLocalInterface(const String16& _descriptor);
    virtual const String16&     getInterfaceDescriptor() const;

protected:
    virtual IBinder*            onAsBinder();
};
```

Binder本地对象是一个类型为BBinder的对象，它是在用户空间中创建的，并且运行在Server进程中，Binder本地对象一方面会被运行在Server进程中的其他对象引用，另一方面也会被Binder驱动程序中的Binder实体对象（binder_node）引用。由于BBinder类继承了RefBase类，因此，Server进程中的其他对象可以简单地通过智能指针来引用这些Binder本地对象，以便可以控制它们地生命周期。由于Bidner驱动中的Binder实体对象是运行在内核空间的，它不能通过智能指针来引用运行在用户空间的Binder本地对象，因此，Binder驱动就需要和Server进程约定一套规则来维护它们的引用计数。

### binder_thread_read

drivers/staging/android/binder.c

```c++
static int binder_thread_read(struct binder_proc *proc, struct binder_thread *thread,
	void  __user *buffer, int size, signed long *consumed, int non_block)
{
...

	while (1) {
		uint32_t cmd;
		struct binder_transaction_data tr;
		struct binder_work *w;
		struct binder_transaction *t = NULL;

		if (!list_empty(&thread->todo))
			w = list_first_entry(&thread->todo, struct binder_work, entry);
		else if (!list_empty(&proc->todo) && wait_for_proc_work)
			w = list_first_entry(&proc->todo, struct binder_work, entry);
		else {
			if (ptr - buffer == 4 && !(thread->looper & BINDER_LOOPER_STATE_NEED_RETURN)) /* no data added */
				goto retry;
			break;
		}

		if (end - ptr < sizeof(tr) + 4)
			break;

		switch (w->type) {
		...
		case BINDER_WORK_NODE: {
			struct binder_node *node = container_of(w, struct binder_node, work);
			uint32_t cmd = BR_NOOP;
			const char *cmd_name;
			int strong = node->internal_strong_refs || node->local_strong_refs;
			int weak = !hlist_empty(&node->refs) || node->local_weak_refs || strong;
			if (weak && !node->has_weak_ref) {
                // 该Binder实体对象已经引用了一个Binder本地对象，但是还没有增加它的弱引用计数
				cmd = BR_INCREFS;
				cmd_name = "BR_INCREFS";
				node->has_weak_ref = 1;
				node->pending_weak_ref = 1;
				node->local_weak_refs++;
			} else if (strong && !node->has_strong_ref) {
                // 该Binder实体对象已经引用了以恶搞Binder本地对象，但是还没有增加它的强引用计数
				cmd = BR_ACQUIRE;
				cmd_name = "BR_ACQUIRE";
				node->has_strong_ref = 1;
				node->pending_strong_ref = 1;
				node->local_strong_refs++;
			} else if (!strong && node->has_strong_ref) {
                // 该Binder实体对象已经不再引用一个Binder本地对象了，但是还没有减少它的强引用计数
				cmd = BR_RELEASE;
				cmd_name = "BR_RELEASE";
				node->has_strong_ref = 0;
			} else if (!weak && node->has_weak_ref) {
                //  该Binder实体对象已经不再引用一个Binder本地对象了，但是还没有减少它的弱引用计数
				cmd = BR_DECREFS;
				cmd_name = "BR_DECREFS";
				node->has_weak_ref = 0;
			}
            // 将协议写到Server进程的用户空间，等待IPCThreadState接口处理
			if (cmd != BR_NOOP) {
				if (put_user(cmd, (uint32_t __user *)ptr))
					return -EFAULT;
				ptr += sizeof(uint32_t);
				if (put_user(node->ptr, (void * __user *)ptr))
					return -EFAULT;
				ptr += sizeof(void *);
				if (put_user(node->cookie, (void * __user *)ptr))
					return -EFAULT;
				ptr += sizeof(void *);

				binder_stat_br(proc, thread, cmd);
				if (binder_debug_mask & BINDER_DEBUG_USER_REFS)
					printk(KERN_INFO "binder: %d:%d %s %d u%p c%p\n",
					       proc->pid, thread->pid, cmd_name, node->debug_id, node->ptr, node->cookie);
			} else {
				list_del_init(&w->entry);
				if (!weak && !strong) {
					if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
						printk(KERN_INFO "binder: %d:%d node %d u%p c%p deleted\n",
						       proc->pid, thread->pid, node->debug_id, node->ptr, node->cookie);
					rb_erase(&node->rb_node, &proc->nodes);
					kfree(node);
					binder_stats.obj_deleted[BINDER_STAT_NODE]++;
				} else {
					if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
						printk(KERN_INFO "binder: %d:%d node %d u%p c%p state unchanged\n",
						       proc->pid, thread->pid, node->debug_id, node->ptr, node->cookie);
				}
			}
		} break;
		....
	return 0;
}
```



### IPCThreadState

frameworks/base/libs/binder/IPCThreadState.cpp

```c++
status_t IPCThreadState::executeCommand(int32_t cmd)
{
    BBinder* obj;
    RefBase::weakref_type* refs;
    status_t result = NO_ERROR;
    
 ...
        
    case BR_ACQUIRE:
        refs = (RefBase::weakref_type*)mIn.readInt32();
        obj = (BBinder*)mIn.readInt32();
        LOG_ASSERT(refs->refBase() == obj,
                   "BR_ACQUIRE: object %p does not match cookie %p (expected %p)",
                   refs, obj, refs->refBase());
        obj->incStrong(mProcess.get());
        IF_LOG_REMOTEREFS() {
            LOG_REMOTEREFS("BR_ACQUIRE from driver on %p", obj);
            obj->printRefs();
        }
        mOut.writeInt32(BC_ACQUIRE_DONE);
        mOut.writeInt32((int32_t)refs);
        mOut.writeInt32((int32_t)obj);
        break;
        
    case BR_RELEASE:
        refs = (RefBase::weakref_type*)mIn.readInt32();
        obj = (BBinder*)mIn.readInt32();
        LOG_ASSERT(refs->refBase() == obj,
                   "BR_RELEASE: object %p does not match cookie %p (expected %p)",
                   refs, obj, refs->refBase());
        IF_LOG_REMOTEREFS() {
            LOG_REMOTEREFS("BR_RELEASE from driver on %p", obj);
            obj->printRefs();
        }
        mPendingStrongDerefs.push(obj);
        break;
        
    case BR_INCREFS:
        refs = (RefBase::weakref_type*)mIn.readInt32();
        obj = (BBinder*)mIn.readInt32();
        refs->incWeak(mProcess.get());
        mOut.writeInt32(BC_INCREFS_DONE);
        mOut.writeInt32((int32_t)refs);
        mOut.writeInt32((int32_t)obj);
        break;
        
    case BR_DECREFS:
        refs = (RefBase::weakref_type*)mIn.readInt32();
        obj = (BBinder*)mIn.readInt32();
        // NOTE: This assertion is not valid, because the object may no
        // longer exist (thus the (BBinder*)cast above resulting in a different
        // memory address).
        //LOG_ASSERT(refs->refBase() == obj,
        //           "BR_DECREFS: object %p does not match cookie %p (expected %p)",
        //           refs, obj, refs->refBase());
        mPendingWeakDerefs.push(refs);
        break;
        
    ...
    }

    ...
    
    return result;
}
```



## Binder实体对象的生命周期

Binder实体对象是一个类型为`binder_node`的对象，它是在binder驱动中创建的，并且被Binder驱动中的Binder引用对象所引用。

drivers/staging/android/binder.c

```c++
/*
node:要增加引用计数的Binder实体对象
strong:增加强引用计数还是弱引用计数
internal:用来区分增加的是内部引用计数还是外部引用计数
target_list:指向一个目标进程或者目标线程的todo队列，当它不为NULL时，就表示增加了Binder实体对象node的引用计数之后，要相应地增加它所引用的Binder本地对象的引用计数
*/
static int binder_inc_node(struct binder_node *node, int strong, int internal, struct list_head *target_list)
{
	if (strong) {
		if (internal) {
			if (target_list == NULL &&
			    node->internal_strong_refs == 0 &&
			    !(node == binder_context_mgr_node &&
			    node->has_strong_ref)) {
				printk(KERN_ERR "binder: invalid inc strong "
					"node for %d\n", node->debug_id);
				return -EINVAL;
			}
            // strong为1，internal为1，表示要增加Binder实体对象node的外部强引用计数internal_strong_refs。
			node->internal_strong_refs++;
		} else
            // strong为1，internal为0，表示要增加Binder实体对象node的内部强引用计数local_strong_refs
			node->local_strong_refs++;
        
        // 当参数internal的值等于1时,意味着此时是Binder驱动程序在为一个Client进程增加Binder实体对象node的外部强引用计数。
        // 这时候如如果它的外部强引用计数internal_strong_refs也等于0，并且它还没有增加对应的Binder本地对象的强引用计数，
        // 即它的has_strong_ref也等于0，那么就需要增加该Binder本地对象的强引用计数了，否则，该Binder本地对象就可能会过早的被销毁，
        // 在这种情况下，就必须指定参数target_list，而且它必须指向该Binder本地对象所在进程的todo队列，以便可以往里面加入一个工作
        // 项来通知该进程增加对应的Binder本地对象的强引用计数。
        // 但是有一种特殊情况，即Binder实体对象node引用的Binder本地对象是Service Manager时，可以不指定target_list的值，因为这个Bidner
        // 本地对象不会被销毁的。
		if (!node->has_strong_ref && target_list) {
			list_del_init(&node->work.entry);
			list_add_tail(&node->work.entry, target_list);
		}
	} else {
		if (!internal)
            // strong为0，internal为0，表示要增加Binder实体对象node的内部弱引用计数local_week_refs
			node->local_weak_refs++;
		if (!node->has_weak_ref && list_empty(&node->work.entry)) {
			if (target_list == NULL) {
				printk(KERN_ERR "binder: invalid inc weak node "
					"for %d\n", node->debug_id);
				return -EINVAL;
			}
			list_add_tail(&node->work.entry, target_list);
		}
	}
	return 0;
}
```



### binder_dec_node

```c++
/*
node:要增加引用计数的Binder实体对象
strong:增加强引用计数还是弱引用计数
internal:用来区分增加的是内部引用计数还是外部引用计数
*/
static int binder_dec_node(struct binder_node *node, int strong, int internal)
{
	if (strong) {
		if (internal)
			node->internal_strong_refs--;
		else
			node->local_strong_refs--;
		if (node->local_strong_refs || node->internal_strong_refs)
			return 0;
	} else {
		if (!internal)
			node->local_weak_refs--;
		if (node->local_weak_refs || !hlist_empty(&node->refs))
			return 0;
	}
    // 执行到这，说明强引用或者弱引用计数等于0了，
	if (node->proc && (node->has_strong_ref || node->has_weak_ref)) {
		if (list_empty(&node->work.entry)) {
			list_add_tail(&node->work.entry, &node->proc->todo);
			wake_up_interruptible(&node->proc->wait);
		}
	} else {
		if (hlist_empty(&node->refs) && !node->local_strong_refs &&
		    !node->local_weak_refs) {
			list_del_init(&node->work.entry);
			if (node->proc) {
				rb_erase(&node->rb_node, &node->proc->nodes);
				if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
					printk(KERN_INFO "binder: refless node %d deleted\n", node->debug_id);
			} else {
				hlist_del(&node->dead_node);
				if (binder_debug_mask & BINDER_DEBUG_INTERNAL_REFS)
					printk(KERN_INFO "binder: dead node %d deleted\n", node->debug_id);
			}
            
			kfree(node);
			binder_stats.obj_deleted[BINDER_STAT_NODE]++;
		}
	}

	return 0;
}
```



## Binder引用对象的生命周期

