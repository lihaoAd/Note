

## 源码位置

goldfish/drivers/staging/android/binder.c

goldfish/drivers/staging/android/binder.h

## 基础数据结构

*binder.c*

```c
struct binder_work {
	struct list_head entry;
	enum {
		BINDER_WORK_TRANSACTION = 1,
		BINDER_WORK_TRANSACTION_COMPLETE,
		BINDER_WORK_NODE,
		BINDER_WORK_DEAD_BINDER,
		BINDER_WORK_DEAD_BINDER_AND_CLEAR,
		BINDER_WORK_CLEAR_DEATH_NOTIFICATION,
	} type;
};
```

binder_work 用来描述待处理的工作项，成员变量entry用来将该结构体嵌入到一个宿主结构中，成员变量type用来描述工作项的类型。

*binder.c*

```c
struct binder_node {
	int debug_id;
	struct binder_work work;
	union {
		struct rb_node rb_node;
		struct hlist_node dead_node;   // 如果一个Binder实体对象的宿主进程已经死亡了，
	};
	struct binder_proc *proc;          // 指向一个Binder实体对象的宿主进程
	struct hlist_head refs;
	int internal_strong_refs;          // 强引用计数
	int local_weak_refs;               // 弱引用计数
	int local_strong_refs;             // 强引用计数
	void __user *ptr;                  // 指向一个用户空间地址，指向该Service组件内部的一个引用计数对象（类型为weakref_impl）的地址
	void __user *cookie;               // 指向该Service组件的地址
	unsigned has_strong_ref : 1;
	unsigned pending_strong_ref : 1;
	unsigned has_weak_ref : 1;
	unsigned pending_weak_ref : 1;
	unsigned has_async_transaction : 1; // 描述一个Binder实体对象是否正在处理一个异步事务
	unsigned accept_fds : 1;     // 是否可以接收包含有文件描述符的进程间通信数据
	int min_priority : 8;
	struct list_head async_todo;
};
```

binder_node用来描述一个binder实体对象。每一个Service组件在Binder驱动中都对应有一个Binder实体对象，用来描述它在内核中的状态。Binder驱动通过强引用计数和弱引用计数来维护它们的生命周期。

binder.c

```c
struct binder_ref_death {
	struct binder_work work;  //BINDER_WORK_DEAD_BINDER、BINDER_WORK_DEAD_BINDER_AND_CLEAR、BINDER_WORK_CLEAR_DEATH_NOTIFICATION都是死亡通知
	void __user *cookie;  // 保存负责接收死亡通知对象的地址
};
```

binder_ref_death用来描述一个Servcie组件的死亡接收通知



```c
struct binder_ref {
	/* Lookups needed: */
	/*   node + proc => ref (transaction) */
	/*   desc + proc => ref (transaction, inc/dec ref) */
	/*   node => refs + procs (proc exit) */
	int debug_id;
	struct rb_node rb_node_desc;
	struct rb_node rb_node_node;
	struct hlist_node node_entry;
	struct binder_proc *proc;
	struct binder_node *node;
	uint32_t desc;
	int strong;
	int weak;
	struct binder_ref_death *death;
};
```





