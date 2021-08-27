

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

