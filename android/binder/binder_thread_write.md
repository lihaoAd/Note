## binder_thread_write



```c
int binder_thread_write(struct binder_proc *proc, struct binder_thread *thread, void __user *buffer, int size, signed long *consumed)
{
	uint32_t cmd;
	void __user *ptr = buffer + *consumed; // 用户空间数据起始地址
	void __user *end = buffer + size;      // 用户空间数据结束地址

	while (ptr < end && thread->return_error == BR_OK) {
        // 可能有多个命令及对应数据要处理，所以要循环
        // 用户态地址空间bwr的write_buffer中读取一个32位无符号整型到cmd
        // 即一个cmd 就会占据4个字节
		if (get_user(cmd, (uint32_t __user *)ptr))
			return -EFAULT;
        
        // 指针后移4个字节,跳过 cmd 所占的空间，指向要处理的数据
		ptr += sizeof(uint32_t);
        
        // 更新该cmd相关的统计信息
		if (_IOC_NR(cmd) < ARRAY_SIZE(binder_stats.bc)) {
			binder_stats.bc[_IOC_NR(cmd)]++;
			proc->stats.bc[_IOC_NR(cmd)]++;
			thread->stats.bc[_IOC_NR(cmd)]++;
		}
		switch (cmd) {
		.....
		}
         //被写入处理消耗的数据量，对应于用户空间的 bwr.write_consumed
		*consumed = ptr - buffer;
	}
	return 0;
}
```



## BC_INCREFS、BC_ACQUIRE、BC_RELEASE、BC_DECREFS

增加或者减少强(`BC_ACQUIRE,BC_RELEASE`)，弱(`BC_INCREFS, BC_DECREFS`)引用计数

```c
case BC_INCREFS:
case BC_ACQUIRE:
case BC_RELEASE:
case BC_DECREFS: {
	uint32_t target;
	struct binder_ref *ref;
	const char *debug_string;

    // 从传入参数的用户态地址中读取想要修改引用计数的struct binder_ref的目标handle
	if (get_user(target, (uint32_t __user *)ptr))
		return -EFAULT;
    
    // 指针继续增加4个字节
	ptr += sizeof(uint32_t);
    
	if (target == 0 && binder_context_mgr_node && (cmd == BC_INCREFS || cmd == BC_ACQUIRE)) {
		ref = binder_get_ref_for_node(proc, binder_context_mgr_node);
		if (ref->desc != target) {
			binder_user_error("binder: %d:"
				"%d tried to acquire "
				"reference to desc 0, "
				"got %d instead\n",
				proc->pid, thread->pid,
				ref->desc);
		}
	} else
        // 从这个proc的refs_by_desc红黑树中获取等于target的binder_ref,如果没有就返回NULL
		ref = binder_get_ref(proc, target);
	if (ref == NULL) {
		binder_user_error("binder: %d:%d refcou nt change on invalid ref %d\n",proc->pid, thread->pid, target);
		break;
	}
	switch (cmd) {
	case BC_INCREFS:
		debug_string = "IncRefs";
		binder_inc_ref(ref, 0, NULL);
		break;
	case BC_ACQUIRE:
		debug_string = "Acquire";
		binder_inc_ref(ref, 1, NULL);
		break;
	case BC_RELEASE:
		debug_string = "Release";
		binder_dec_ref(ref, 1);
		break;
	case BC_DECREFS:
	default:
		debug_string = "DecRefs";
		binder_dec_ref(ref, 0);
		break;
	}
	if (binder_debug_mask & BINDER_DEBUG_USER_REFS)
		printk(KERN_INFO "binder: %d:%d %s ref %d desc %d s %d w %d for node %d\n",
		       proc->pid, thread->pid, debug_string, ref->debug_id, ref->desc, ref->strong, ref->weak, ref->node->debug_id);
	break;
}
```





## BC_INCREFS_DONE、BC_ACQUIRE_DONE



```c
case BC_INCREFS_DONE:
case BC_ACQUIRE_DONE: {
	void __user *node_ptr;
	void *cookie;
	struct binder_node *node;

	if (get_user(node_ptr, (void * __user *)ptr))
		return -EFAULT;
	ptr += sizeof(void *);
	if (get_user(cookie, (void * __user *)ptr))
		return -EFAULT;
	ptr += sizeof(void *);
	node = binder_get_node(proc, node_ptr);
	if (node == NULL) {
		binder_user_error("binder: %d:%d "
			"%s u%p no match\n",
			proc->pid, thread->pid,
			cmd == BC_INCREFS_DONE ?
			"BC_INCREFS_DONE" :
			"BC_ACQUIRE_DONE",
			node_ptr);
		break;
	}
	if (cookie != node->cookie) {
		binder_user_error("binder: %d:%d %s u%p node %d"
			" cookie mismatch %p != %p\n",
			proc->pid, thread->pid,
			cmd == BC_INCREFS_DONE ?
			"BC_INCREFS_DONE" : "BC_ACQUIRE_DONE",
			node_ptr, node->debug_id,
			cookie, node->cookie);
		break;
	}
	if (cmd == BC_ACQUIRE_DONE) {
		if (node->pending_strong_ref == 0) {
			binder_user_error("binder: %d:%d "
				"BC_ACQUIRE_DONE node %d has "
				"no pending acquire request\n",
				proc->pid, thread->pid,
				node->debug_id);
			break;
		}
		node->pending_strong_ref = 0;
	} else {
		if (node->pending_weak_ref == 0) {
			binder_user_error("binder: %d:%d "
				"BC_INCREFS_DONE node %d has "
				"no pending increfs request\n",
				proc->pid, thread->pid,
				node->debug_id);
			break;
		}
		node->pending_weak_ref = 0;
	}
	binder_dec_node(node, cmd == BC_ACQUIRE_DONE, 0);
	if (binder_debug_mask & BINDER_DEBUG_USER_REFS)
		printk(KERN_INFO "binder: %d:%d %s node %d ls %d lw %d\n",
		       proc->pid, thread->pid, cmd == BC_INCREFS_DONE ? "BC_INCREFS_DONE" : "BC_ACQUIRE_DONE", node->debug_id, node->local_strong_refs, node->local_weak_refs);
	break;
```



## BC_FREE_BUFFER



```c
case BC_FREE_BUFFER: {
	void __user *data_ptr;
	struct binder_buffer *buffer;

	if (get_user(data_ptr, (void * __user *)ptr))
		return -EFAULT;
	ptr += sizeof(void *);

	buffer = binder_buffer_lookup(proc, data_ptr);
	if (buffer == NULL) {
		binder_user_error("binder: %d:%d "
			"BC_FREE_BUFFER u%p no match\n",
			proc->pid, thread->pid, data_ptr);
		break;
	}
	if (!buffer->allow_user_free) {
		binder_user_error("binder: %d:%d "
			"BC_FREE_BUFFER u%p matched "
			"unreturned buffer\n",
			proc->pid, thread->pid, data_ptr);
		break;
	}
	if (binder_debug_mask & BINDER_DEBUG_FREE_BUFFER)
		printk(KERN_INFO "binder: %d:%d BC_FREE_BUFFER u%p found buffer %d for %s transaction\n",
		       proc->pid, thread->pid, data_ptr, buffer->debug_id,
		       buffer->transaction ? "active" : "finished");

	if (buffer->transaction) {
		buffer->transaction->buffer = NULL;
		buffer->transaction = NULL;
	}
	if (buffer->async_transaction && buffer->target_node) {
		BUG_ON(!buffer->target_node->has_async_transaction);
		if (list_empty(&buffer->target_node->async_todo))
			buffer->target_node->has_async_transaction = 0;
		else
			list_move_tail(buffer->target_node->async_todo.next, &thread->todo);
	}
	binder_transaction_buffer_release(proc, buffer, NULL);
	binder_free_buf(proc, buffer);
	break;
}
```





## BC_TRANSACTION、BC_REPLY



```c
case BC_TRANSACTION:
case BC_REPLY: {
	struct binder_transaction_data tr;

	if (copy_from_user(&tr, ptr, sizeof(tr)))
		return -EFAULT;
	ptr += sizeof(tr);
	binder_transaction(proc, thread, &tr, cmd == BC_REPLY);
	break;
}
```

![image-20220321233808041](./img/image-20220321233808041.png)



## BC_ATTEMPT_ACQUIRE、BC_ACQUIRE_RESULT

暂不支持这些协议

