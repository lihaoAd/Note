

````
startup_32:
	cld
	cli          # 关闭中断
	movl $(__KERNEL_DS),%eax
	movl %eax,%ds
	movl %eax,%es
	movl %eax,%fs
	movl %eax,%gs

	lss SYMBOL_NAME(stack_start),%esp   # 把stack_start的地址压入栈
	xorl %eax,%eax                      # eax  清0
1:	incl %eax		# check that A20 really IS enabled
	movl %eax,0x000000	# loop forever if it isn't
	cmpl %eax,0x100000
	je 1b               # 向后跳转到标号1处
````

