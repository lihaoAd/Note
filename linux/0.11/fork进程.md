

## 定义



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



