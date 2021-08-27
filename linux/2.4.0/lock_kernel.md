## 加锁

```
extern __inline__ void lock_kernel(void)
{
...
	if (!++current->lock_depth)
		spin_lock(&kernel_flag);
...
}
```





`````
static inline void spin_lock(spinlock_t *lock)
{
...
	__asm__ __volatile__(
		spin_lock_string
		:"=m" (lock->lock) : : "memory");
}
`````



如果lock等于1的话，表示 这个spin lock是自由的；如果lock小于等于0的话，则表示spin lock已经被其他CPU所 获取。 

```
#define spin_lock_string \
	"\n1:\t" \
	"lock ; decb %0\n\t" \    # 原子性的把lock->lock减去1
	"js 2f\n" \         # 如果是负数，表示的是lock->lock是小于0，还没有获取锁，向前跳转到标号2处
	".section .text.lock,\"ax\"\n" \ # 编译指示，往下的代码放在单独的.text.lock段中，
									 # 双引号中的ax分别表示这个段是allocatable和executable
	"2:\t" \
	"cmpb $0,%0\n\t" \   #  将lock->lock的值与0比较
	"rep;nop\n\t" \  
	"jle 2b\n\t" \       # 当lock->lock小于等于0时，向后跳转到标号2处，继续循环测试
	"jmp 1b\n" \         # 当lock->lock大于0时，向后跳转到标号1处，获取自旋锁
	".previous"          # previous后面的代码将会链接到上一个段中
```



```decb```就是把 lock--,这个指令先把lock读进寄存器中，然后lock减1，然后把减1后的值回写到内存中，这个过程不是原子操作，加上```lock```指令后，保证了修改的原子性了。

如果lock->lock小于等于0，那么就一直循环测试其值，直到lock->lock大于0。这就相当于让CPU一直空转，做无用功，因此自旋锁应用的地方不能加锁时间太长，否则就会浪费资源。



```
".section .text.lock,\"ax\"\n"
```

如果非负，值为0则加锁成功，由于此处往下的语句由.section命令放在了另外的段中，所以如果加锁成功，则直接从此处返回到原来spin_lock函数中去，下面的代码不会执行到。



.previous 起到一个切换段的作用。这里可以看到有两个段，一个是 .text 段，另一个是自定义的 .text.lock 段，下面的这些代码属于 .text.lock 段：

```
"2:\t" \
	"cmpb $0,%0\n\t" \
	"rep;nop\n\t" \
	"jle 2b\n\t" \
	"jmp 1b\n" \
```

之所以定义成一个单独的区，原因是在大多数情况下，spin lock是能获取成功的，从.section 到.previous的这一段代码并不经常被调用，如果把它跟别的常用指令混在一起，会浪费指令缓存的空间。从这里也可以看出，linux内核的实现，要时时注意效率。

`````
rep;nop 
`````

这是一条很有趣的指令，咋一看，这只是一条空指令，但实际上这条指令可以降低CPU的运行 频率，减低电的消耗量，但最重要的是，提高了整体的效率。因为这段指令执行太快的话，会生成 很多读取内存变量的指令，另外的一个CPU可能也要写这个内存变量，现在的CPU经常需要重新排序指令来提高效率，如果读指令太多的话，为了保证指令之间的依赖性，CPU会以牺牲流水线 执行（pipeline）所带来的好处。从pentium 4以后，intel引进了一条pause指令，专门用于spin lock这种情况，据intel的文档说，加上pause可以提高25倍的效率！nop指令前加rep前缀意思是：Spin-Wait and Idle Loops 。

rep;nop 会被翻译成 pause 指令



## 去锁

```
extern __inline__ void unlock_kernel(void)
{
	if (current->lock_depth < 0)
		BUG();
#if 1
	if (--current->lock_depth < 0)
		spin_unlock(&kernel_flag);
#else
	__asm__ __volatile__(
		"decl %1\n\t"
		"jns 9f\n\t"
		spin_unlock_string
		"\n9:"
		:"=m" (__dummy_lock(&kernel_flag)),
		 "=m" (current->lock_depth));
#endif
}
```

```
static inline void spin_unlock(spinlock_t *lock)
{
#if SPINLOCK_DEBUG
	if (lock->magic != SPINLOCK_MAGIC)
		BUG();
	if (!spin_is_locked(lock))
		BUG();
#endif
	__asm__ __volatile__(
		spin_unlock_string
		:"=m" (lock->lock) : : "memory");
}
```
```
#define spin_unlock_string \
	"movb $1,%0"
```

解除锁定就是把lock恢复到1。