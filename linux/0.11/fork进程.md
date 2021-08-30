

## 定义

fork函数先从当前任务表（task）里找到一个任务号（进程pid），如果可以找到，就会复制当前进程`current`结构体的数据(task_struct),然后复制进程页表项，将RW置位0，为以后写时复制做准备。子进程与父进程共享内存。然后处理信号。切换进程后，CPU会自动的加载每个 task_struct中的TSS数据，并且保存前一个进程的CPU状态到TSS中。进程fork后，就等着调度了。注意，子进程在初始化的时候往eax寄存器中存进去了0，eax用于函数返回值。也就是说子进程会返回0，而父进程会返回自己的pid。

`````c
if (!fork()) {		/* we count on this going ok */
	 init();        // 在新建的子进程(任务1)中执行。
 }
`````

*init/main.c*

```c++
static inline _syscall0(int,fork)
```

*include/unistd.h*

````apl
#define __NR_fork	2

#define _syscall0(type,name) \
type name(void) \
{ \
long __res; \
__asm__ volatile ("int $0x80" \
	: "=a" (__res) \
	: "0" (__NR_##name)); \
if (__res >= 0) \
	return (type) __res; \
errno = -__res; \
return -1; \
}

````

宏展开后就是

`````c
int fork(void) 
{ 
long __res; 
__asm__ volatile ("int $0x80" : "=a" (__res) : "0" (__NR_fork));
if (__res >= 0) 
	return (type) __res; 
errno = -__res; 
return -1; 
}
`````

- volatile 是可选的。如果用了它，则是向GCC 声明不允许对该内联汇编优化，否则当 使用了优化选项(-O)进行编译时，GCC 将会根据自己的判断决定是否将这个内联汇编表达式中的指令优化掉。
- int 0x80 是系统调用，"a"表示使用eax寄存器，"="表示只写，类似 _res = eax
- 0～9：此约束只用在 input 部分，但表示可与 output 和 input 中第 n 个操作数用相同的寄存器或内存  ，`"0" (__NR_fork))`表示表示沿用上一次的约束，就是把`__NR_fork`的值2放到`eax`寄存器中。



## 0x80中断

在sched_init执行时调用了set_system_gate(0x80,&system_call);



```c
sys_fork:
	call find_empty_process
	testl %eax,%eax             # 在eax中返回进程号pid。若返回负数则退出。
	js 1f
	push %gs
	pushl %esi
	pushl %edi
	pushl %ebp
	pushl %eax
	call copy_process
	addl $20,%esp               # 丢弃这里所有压栈内容。
1:	ret
```

```c
// 为新进程取得不重复的进程号last_pid.函数返回在任务数组中的任务号(数组项)。
int find_empty_process(void)
{
	int i;

    // 首先获取新的进程号。如果last_pid增1后超出进程号的整数表示范围，则重新从1开始
    // 使用pid号。然后在任务数组中搜索刚设置的pid号是否已经被任何任务使用。如果是则
    // 跳转到函数开始出重新获得一个pid号。接着在任务数组中为新任务寻找一个空闲项，并
    // 返回项号。last_pid是一个全局变量，不用返回。如果此时任务数组中64个项已经被全部
    // 占用，则返回出错码。
	repeat:
		if ((++last_pid)<0) last_pid=1;
		for(i=0 ; i<NR_TASKS ; i++)
			if (task[i] && task[i]->pid == last_pid) goto repeat;
	for(i=1 ; i<NR_TASKS ; i++)         // 任务0项被排除在外
		if (!task[i])
			return i;
	return -EAGAIN;
}

```



## 复制页表

```c
// 复制内存页表
// 参数nr是新任务号：p是新任务数据结构指针。该函数为新任务在线性地址空间中
// 设置代码段和数据段基址、限长，并复制页表。由于Linux系统采用了写时复制
// (copy on write)技术，因此这里仅为新进程设置自己的页目录表项和页表项，而
// 没有实际为新进程分配物理内存页面。此时新进程与其父进程共享所有内存页面。
// 操作成功返回0，否则返回出错号。
int copy_mem(int nr,struct task_struct * p)
{
	unsigned long old_data_base,new_data_base,data_limit;
	unsigned long old_code_base,new_code_base,code_limit;

    // 首先取当前进程局部描述符表中代表中代码段描述符和数据段描述符项中的
    // 的段限长(字节数)。0x0f是代码段选择符：0x17是数据段选择符。然后取
    // 当前进程代码段和数据段在线性地址空间中的基地址。由于Linux-0.11内核
    // 还不支持代码和数据段分立的情况，因此这里需要检查代码段和数据段基址
    // 和限长是否都分别相同。否则内核显示出错信息，并停止运行。
	code_limit=get_limit(0x0f);  // 0000 1111 表示RPL=3 TI=1（在LDT中），索引1，就是代码段
	data_limit=get_limit(0x17);  // 0001 0111 表示RPL=3 TI=1（在LDT中），索引2，就是数据段
	old_code_base = get_base(current->ldt[1]);
	old_data_base = get_base(current->ldt[2]);
	if (old_data_base != old_code_base)
		panic("We don't support separate I&D");
	if (data_limit < code_limit)
		panic("Bad data_limit");
    // 然后设置创建中的新进程在线性地址空间中的基地址等于(64MB * 其任务号)，
    // 并用该值设置新进程局部描述符表中段描述符中的基地址。接着设置新进程
    // 的页目录表项和页表项，即复制当前进程(父进程)的页目录表项和页表项。
    // 此时子进程共享父进程的内存页面。正常情况下copy_page_tables()返回0，
    // 否则表示出错，则释放刚申请的页表项。
	new_data_base = new_code_base = nr * 0x4000000;
	p->start_code = new_code_base;
	set_base(p->ldt[1],new_code_base);
	set_base(p->ldt[2],new_data_base);
    
    // 设置新进程的页目录表项和页表项。即把新进程的线性地址内存页对应到实际物理地址内存页面上
	if (copy_page_tables(old_data_base,new_data_base,data_limit)) {
		printk("free_page_tables: from copy_mem\n");
		free_page_tables(new_data_base,data_limit);
		return -ENOMEM;
	}
	return 0;
}
```

![image-20210830231639518](img/image-20210830231639518.png)



指令lsl 是Load Segment Limit 缩写。它从指定段描述符中取出分散的限长比特位拼成完整的段限长值放入指定寄存器中。所得的段限长是实际字节数减1，因此这里还需要加1 后才返回。

```java
#define get_limit(segment) ({ \
unsigned long __limit; \
__asm__("lsll %1,%0 \n\t incl %0":"=r" (__limit):"r" (segment)); \
__limit;})
```





```java
static inline unsigned long _get_base(char * addr)
{
         unsigned long __base;
         __asm__("movb %3,%%dh\n\t"
                 "movb %2,%%dl\n\t"
                 "shll $16,%%edx\n\t"
                 "movw %1,%%dx"
                 :"=&d" (__base)
                 :"m" (*((addr)+2)),
                  "m" (*((addr)+4)),
                  "m" (*((addr)+7)));
         return __base;
}

#define get_base(ldt) _get_base( ((char *)&(ldt)) )
```



由于Linux系统采用了写时复制(copy on write)技术，`copy_mem`仅为新进程设置自己的页目录表项和页表项，而没有实际为新进程分配物理内存页面。此时新进程与其父进程共享所有内存页面。 系统设置全局描述符表GDT中的分段描述符项数最大为256，其中2项空闲，2项系统使用，每个进程使用两项。因此，此时系统可以最多容纳(256-4)/2 +1 =127个任务，并且虚拟地址范围是((256-4)/2)*64MB =4G。 4G正好与CPU的线性地址空间范围或物理地址空间范围相同，因此在0.11内核中比较容易混淆三种地址概念， 从Linux内核0.99版以后，对内存空间的使用方式发生了变化。每个进程可以单独享用整个4G的地址空间范围。

![image-20210830232219030](img/image-20210830232219030.png)

```c
// 复制页目录表项和页表项
// 复制指定线性地址和长度内存对应的页目录项和页表项，从而被复制的页目录和页表对
// 应的原物理内存页面区被两套页表映射而共享使用。复制时，需申请新页面来存放新页
// 表，原物理内存区将被共享。此后两个进程（父进程和其子进程）将共享内存区，直到
// 有一个进程执行谢操作时，内核才会为写操作进程分配新的内存页(写时复制机制)。
// 参数from、to是线性地址，size是需要复制（共享）的内存长度，单位是byte.
int copy_page_tables(unsigned long from,unsigned long to,long size)
{
	unsigned long * from_page_table;
	unsigned long * to_page_table;
	unsigned long this_page;
	unsigned long * from_dir, * to_dir;
	unsigned long nr;

    // 首先检测参数给出的原地址from和目的地址to的有效性。原地址和目的地址都需要
    // 在4Mb内存边界地址上。否则出错死机。作这样的要求是因为一个页表的1024项可
    // 管理4Mb内存。源地址from和目的地址to只有满足这个要求才能保证从一个页表的
    // 第一项开始复制页表项，并且新页表的最初所有项都是有效的。然后取得源地址和
    // 目的地址的其实目录项指针(from_dir 和 to_dir).再根据参数给出的长度size计
    // 算要复制的内存块占用的页表数(即目录项数)。
	if ((from&0x3fffff) || (to&0x3fffff))
		panic("copy_page_tables called with wrong alignment");
	from_dir = (unsigned long *) ((from>>20) & 0xffc); /* _pg_dir = 0 */
	to_dir = (unsigned long *) ((to>>20) & 0xffc);
	size = ((unsigned) (size+0x3fffff)) >> 22;
    // 在得到了源起始目录项指针from_dir和目的起始目录项指针to_dir以及需要复制的
    // 页表个数size后，下面开始对每个页目录项依次申请1页内存来保存对应的页表，并
    // 且开始页表项复制操作。如果目的目录指定的页表已经存在(P=1)，则出错死机。
    // 如果源目录项无效，即指定的页表不存在(P=1),则继续循环处理下一个页目录项。
	for( ; size-->0 ; from_dir++,to_dir++) {
		if (1 & *to_dir)
			panic("copy_page_tables: already exist");
		if (!(1 & *from_dir))
			continue;
        // 在验证了当前源目录项和目的项正常之后，我们取源目录项中页表地址
        // from_page_table。为了保存目的目录项对应的页表，需要在住内存区中申请1
        // 页空闲内存页。如果取空闲页面函数get_free_page()返回0，则说明没有申请
        // 到空闲内存页面，可能是内存不够。于是返回-1值退出。
		from_page_table = (unsigned long *) (0xfffff000 & *from_dir);
		if (!(to_page_table = (unsigned long *) get_free_page()))
			return -1;	/* Out of memory, see freeing */
        // 否则我们设置目的目录项信息，把最后3位置位，即当前目录的目录项 | 7，
        // 表示对应页表映射的内存页面是用户级的，并且可读写、存在(Usr,R/W,Present).
        // (如果U/S位是0，则R/W就没有作用。如果U/S位是1，而R/W是0，那么运行在用
        // 户层的代码就只能读页面。如果U/S和R/W都置位，则就有读写的权限)。然后
        // 针对当前处理的页目录项对应的页表，设置需要复制的页面项数。如果是在内
        // 核空间，则仅需复制头160页对应的页表项(nr=160),对应于开始640KB物理内存
        // 否则需要复制一个页表中的所有1024个页表项(nr=1024)，可映射4MB物理内存。
		*to_dir = ((unsigned long) to_page_table) | 7;
		nr = (from==0)?0xA0:1024;
        // 此时对于当前页表，开始循环复制指定的nr个内存页面表项。先取出源页表的
        // 内容，如果当前源页表没有使用，则不用复制该表项，继续处理下一项。否则
        // 复位表项中R/W标志(位1置0)，即让页表对应的内存页面只读。然后将页表项复制
        // 到目录页表中。
		for ( ; nr-- > 0 ; from_page_table++,to_page_table++) {
			this_page = *from_page_table;
			if (!(1 & this_page))
				continue;
			this_page &= ~2;
			*to_page_table = this_page;
            // 如果该页表所指物理页面的地址在1MB以上，则需要设置内存页面映射数
            // 组mem_map[]，于是计算页面号，并以它为索引在页面映射数组相应项中
            // 增加引用次数。而对于位于1MB以下的页面，说明是内核页面，因此不需
            // 要对mem_map[]进行设置。因为mem_map[]仅用于管理主内存区中的页面使
            // 用情况。因此对于内核移动到任务0中并且调用fork()创建任务1时(用于
            // 运行init())，由于此时复制的页面还仍然都在内核代码区域，因此以下
            // 判断中的语句不会执行，任务0的页面仍然可以随时读写。只有当调用fork()
            // 的父进程代码处于主内存区(页面位置大于1MB)时才会执行。这种情况需要
            // 在进程调用execve()，并装载执行了新程序代码时才会出现。
            // *from_page_table = this_page; 这句是令源页表项所指内存页也为只读。
            // 因为现在开始有两个进程公用内存区了。若其中1个进程需要进行写操作，
            // 则可以通过页异常写保护处理为执行写操作的进程匹配1页新空闲页面，也
            // 即进行写时复制(copy on write)操作。
			if (this_page > LOW_MEM) {
				*from_page_table = this_page;
				this_page -= LOW_MEM;
				this_page >>= 12;
				mem_map[this_page]++;
			}
		}
	}
	invalidate();
	return 0;
}
```





