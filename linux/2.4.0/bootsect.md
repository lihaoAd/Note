 这个地址的指令就会把0磁头0磁道1扇区的数据加载到```0x07C000```地址处。在PC的系统结构中，线性地址0xA0000以上，即640KB以上都用于图形接口卡以及BIOS本身，而0xA0000以下的640KB为系统的基本内存。



![bios启动后](.\img\image-20210113171629198.png)

![bios加载bootsect](.\img\image-20210113172019487.png)

此时内存中就已经有了我们的bootsect数据。bios将控制权交给bootsect程序。首先就要把自己复制到```0x90000```的地方

```

	movw	$BOOTSEG, %ax   # 0x07C0 -> ax
	movw	%ax, %ds        # 0x07C0 -> ds
	movw	$INITSEG, %ax   # 0x9000 -> ax 
	movw	%ax, %es        # 0x9000 -> es
	movw	$256, %cx       # 256 -> cx 
	subw	%si, %si        # si 清0
	subw	%di, %di        # di 清0
	cld     				# 向内存正方向复制数据
	rep    					# 重复后面的 movsw指令
	movsw
	ljmp	$INITSEG, $go   # CS:IP =  0x9000:$go
```

就是把 地址```0x07C00```地方的数据复制到```0x90000```的地方，复制了256个字的数据，即512字节，然后跳转到该```0x9000:$go```地址处继续执行。

![image-20210118193339828](.\img\image-20210118191038340.png)



```

go:	movw	$0x4000-12, %di		# 0x4000 is an arbitrary value >=
								# length of bootsect + length of
								# setup + room for stack;
								# 12 is disk parm size.
	movw	%ax, %ds		# ax中的值就是0x9000 ，即0x9000->ds
	movw	%ax, %ss        # 0x9000->ss,栈低
	movw	%di, %sp		# 0x4000-12 -> sp，即栈顶在 0x9000:0x4000-12.

	
	# BIOS中断0x1E的中断向量值是软驱参数表地址，其向量值位于内存0x0000:0x78处，
	# 该地址处存储的一个四字节是一个地址，该地址处的12字节就是软驱参数表
	
	movw	%cx, %fs		# cx =0,即 0 -> fs
	movw	$0x78, %bx		# 0x78 -> bx,fs:bx is parameter table address
	pushw	%ds             # 保存 ds= 0x9000
	
	ldsw	%fs:(%bx), %si	# 把fs:bx即0x78处的4个字节的值，高2字节给ds，低2字节给si
							# 也就是把指向软盘参数表的指针装入ds:si中。
							
	movb	$6, %cl			# copy 12 bytes
	pushw	%di			    # 保存 di = 0x4000-12.
	rep				        # don't need cld -> done on line 66
	movsw                   # ds:si -> es:di，即 ds:si -> 0x9000:0x4000-12 
	
	popw	%di             # di = 0x4000-12
	popw	%ds				# ds= 0x9000
	movb	$36, 0x4(%di)	# 36 -> ds:di +0x4, 将磁盘新参数表的sectors/track值修改为36 								# (2.88M软盘的参数)

	movw	%di, %fs:(%bx)  # 修改0:0x78处的指针指向0x4000-12 (es:di)
	movw	%es, %fs:2(%bx)
	

```

 BIOS中断0x1E的中断向量值是软驱参数表地址，其向量值位于内存0x0000:0x78处， 该地址处存储的一个四字节是一个地址，该地址处的12字节就是软驱参数表。



![image-20210121171137123](.\img\image-20210121171137123.png)



![image-20210118193612299](.\img\image-20210118193612299.png)

在BIOS中断0x1E对应的中断向量表项入口地址0:0x78处的4个字节，保存着指向存放于系统BIOS ROM中的软盘参数表的入口逻辑地址。需要说明一下，这四个字节的低两个字节为偏移量，高两个字节为段地址。

在BIOS的中断向量表中断1Eh的地址0:78h处，保存着指向存放于系统BIOS ROM中的软盘参数表的远指针（远指针指需要通过segment:offset的方式来制定的指针，它所指向的地址可以跨越不同的64K段；而近指针则只需要通过offset来制定同一段内的另外一个地址）。里面包含了有关驱动器（Driver）的信息。BIOS使用这个表来为软盘控制器编程和指定软驱的控制定时——当某个程序调用13h中断来使用软盘服务时，BIOS将会使用软盘参数表中提供的数据来对软盘控制器进行编程。

软盘参数表是一个重要的概念——如果系统上只有一个驱动器类型，正像早期的PC和XT系统一样。参数表在早期的PS/2上工作得也很好，在这里要从两种类型的驱动器中选择一个，比如3.5英寸，1.44M

![image-20210118200257902](C:\Users\LIHAO\AppData\Roaming\Typora\typora-user-images\image-20210118200257902.png)



![image-20210121204920996](.\img\image-20210121204920996.png)

从软盘读取数据，不能够跨越磁道，即每次读取，尽管可以同时读取多个扇区，而这些扇区却必须都属于同一个磁道。BIOS 13h服务例程将对此进行验证，如果发现用户所要读取扇区跨越了不同的磁道，则返回调用失败。而验证所依据的数据则是软盘参数表。假如，软盘参数表中所记录的“每磁道的扇区数”（偏移量为4的位置）为9；如果现在一个INT 13h, ax = 2的调用指定：磁头为0，磁道为1，磁道内起始扇区为2，要读取的扇区数目为9；由于磁道内起始扇区+要读取的扇区数-1 = 2+9 -1 = 10  > 9，则调用将会失败。（之所以减去1是因为磁道内起始扇区是从1开始计数的，而不是0）。

但这并不意味着，如果通过了BIOS软盘参数表的验证，而读取就一定能够成功。例如，软盘参数表中所记录的“每磁道的扇区数”为18，而实际的“每磁道的扇区数”为9，如果现在一个INT 13h, ax = 2的调用指定：磁头为0，磁道为1，磁道内起始扇区为2，要读取的扇区数目为9；由于磁道内起始扇区+要读取的扇区数-1 = 2+9 -1 = 10 < 18，通过软盘参数表的验证没有任何问题，但当软盘驱动器真正去读取磁头0，磁道1，第10个扇区的时候，而这个扇区并不存在，调用依然会失败。



所以，为了保证一个需要读取软盘的程序不出错误，我们必须保证：

“要读取的扇区数” + “磁道内起始扇区” - 1 <= 软盘参数表中“每磁道的扇区数”的数值

同时保证：

“要读取的扇区数” + “磁道内起始扇区” - 1 <= 实际的“每磁道的扇区数”



你如果想保证你的程序永远不在读取软盘的时候出此类错误，最稳妥的方法是每次只读取一个扇区，但这样效率很低，真正作软件的人都愿意有效率更高，而又稳妥地方法——所以我们要在提高效率的目标下，寻找一种方法来确保效率。

我们还是看一看上面所列的两个条件，从中我们可以首先得知——我们必须知道实际的“每磁道的扇区数”，否则，我们肯定会出错。那么，在我们知道实际的“每磁道的扇区数”的前提下，软盘参数表中“每磁道的扇区数”的数值不能小于实际的“每磁道的扇区数”，否则，仍然会出错。那么大于呢？由于BIOS对软盘参数表中“每磁道的扇区数”的数值的验证放在前面，如果大于的话，这一级验证即使通过了，还有实际的“每磁道的扇区数”这一关需要通过。所以大于是不会有任何问题的。等于就更不用说了。

由此得知，要想让我们的程序不出此类错误，我们必须保证两点：

1、保证 软盘参数表中“每磁道的扇区数”的数值 大于等于 实际的“每磁道的扇区数”。

2、知道实际的“每磁道的扇区数”；

对于第1点，或许大家会问，难道BIOS厂商不能够来保证这一点吗？答案是，能够。但不幸的是，在现实生活中，由于历史的原因，确确实实有一些BIOS厂商将软盘参数表中“每磁道的扇区数”的数值设置的比较小。这样，我们就必须靠自己来保证这一点。



**如何保证软盘参数表中“每磁道的扇区数”大于等于实际的“每磁道的扇区数”？** 

我们在前面已经说过，在BIOS的中断向量表中断1Eh的地址0:78h处，放置的仅仅是指向软盘参数表的的指针，而软盘参数表被放在BIOS ROM中，我们无法修改。所以，我们可以在RAM中复制一份软盘参数表，进行修改。然后将BIOS的中断向量表中断1Eh的地址0:78h处的远指针修改为指向RAM中新复制的软盘参数表。

由于到目前为止，最大可能的“每磁道扇区数”为36，所以我们只需要将新的软盘参数表中的“每磁道扇区数”修改为36，即可以保证软盘参数表中“每磁道的扇区数”的数值大于等于实际的“每磁道的扇区数”。



**如何获取实际的“每磁道的扇区数”？**

除了去猜测之外，没有什么好的方法能够获取“实际的每磁道扇区数”。所幸的是，实际存在的软盘只有有限的几个种类，而不同的“实际的每磁道扇区数”就更加有限。“实际的每磁道扇区数”有9，15，18，36四种。于是，我们就可以对一张软盘使用这四个数值从大到小依次猜测。

 

猜测的方法，是读取磁头0，磁道0，当前磁道最大扇区。首先猜测“当前磁道最大扇区”为36，如果实际的“每磁道扇区数”小于36，则读取失败。然后猜测“当前磁道最大扇区”为18，如果失败了，再猜测15……依次类推，直到猜测为9为止，这是最小可能的“每磁道扇区数”。




将软盘参数表读入9000:3FF4，设置maximum sector count = 36，并将中断向量表中的软盘参数表始址指向地址9000:3FF4; ds=es=ss=cs = 90。



```

# 加载4个扇区的setup程序
load_setup:
	xorb	%ah, %ah			# reset FDC 
	xorb	%dl, %dl
	int 	$0x13	            # 调用 0x13 中断 reset 软驱控制器
	xorw	%dx, %dx			# drive 0, head 0
	movb	$0x02, %cl			# sector 2, track 0
	movw	$0x0200, %bx		# 读入到 es:bx (0x9000:0200)
	movb	$0x02, %ah			# service 2, "read sector(s)"
	movb	setup_sects, %al	# 4 -> al ,读取4个扇区
	int	$0x13					# 将软盘从第二扇区开始的 4个扇区(setup 代码)读入内存										# (0x9000:0x0200)处。
	
	jnc	ok_load_setup			# 成功则转到 ok_load_setup

	pushw	%ax					# 否则打印错误码并循环重试
	call	print_nl
	movw	%sp, %bp
	call	print_hex
	popw	%ax	
	jmp	load_setup
```

利用13号中断的02功能，读取扇区，读取4个扇区到0x9000：0x0200这个地址。这里就把setup程序加载到内存中了。

![image-20210113175125556](.\img\image-20210113175125556.png)

```
ok_load_setup:
	# 获取磁盘参数，尤其是每个磁道的扇区数
	movw	$disksizes, %si		# disksizes标号的偏移地址 -> si
probe_loop:
	lodsb               		# 把 ds:si处的一个字节加载到al中,根据DF标志增减si
								# 因为前面cld，所以这里时si=si+1
								
	cbtw						# convert byte to word，如果al的最高有效位是0，则ah = 00;
								# al的最高有效位为1，则ah =FFH。al不变
								
	movw	%ax, sectors        # 第一次时ax=36，即sectors=36
	cmpw	$disksizes+4, %si   
	jae	got_sectors		        # 36,18,15,9都搞不定, 则默认为9
	
	xchgw	%cx, %ax			# cx = track and sector
	xorw	%dx, %dx			# drive 0, head 0
	xorb	%bl, %bl            # bl清0 
	movb	setup_sects, %bh   	# 4 -> bh ,
	incb	%bh                 # bh = 5
	shlb	%bh			        # bh = 0x0a, 缓冲区es:bx = 0x9000:0x0a00
	movw	$0x0201, %ax		# service 2, 1 sector
	int	$0x13
	jc	probe_loop		        # try next value
```

串操作指令```LODSB/LODSW```是块装入指令，其具体操作是把```SI```指向的存储单元读入累加器,```LODSB```就读入```AL```,```LODSW```就读入```AX```中,然后```SI```自动增加或减小```1```或```2```。

这里获取磁盘参数，主要是每个磁道的扇区数，每次尝试读取一个扇区，如果失败，就会尝试下一个，如果都失败，每个磁道扇区数就默认为9。

![image-20210118195746006](.\img\image-20210118195746006.png)

```
disksizes:	.byte 36, 18, 15, 9
```

![QQ截图20210118194753](.\img\QQ截图20210118194753.jpg)

```
got_sectors:

	# 获取光标
	movw	$INITSEG, %ax   # 0x9000 -> ax
	movw	%ax, %es		# 0x9000 -> es
	movb	$0x03, %ah		# 0x03 -> ah
	xorb	%bh, %bh        # bh = 0
	int	$0x10
	
	# 显示 Loading
	movw	$9, %cx         # 9 -> cx,一个换行符一个回车符和“Loading”一共9个
	movw	$0x0007, %bx	# page 0, attribute 7 (normal)
	movw    $msg1, %bp
	movw    $0x1301, %ax	# write string, move cursor
	int	$0x10			    # tell the user we're loading..
	
	movw	$SYSSEG, %ax	# 0x1000 -> ax
	movw	%ax, %es		# we want to load system (at 0x10000)
	call	read_it
	call	kill_motor
	call	print_nl
```

![image-20210121212137928](.\img\image-20210121212137928.png)





![image-20210121212951676](.\img\image-20210121212951676.png)

运行到这里就已经找到每磁道扇区数了，保存在```sectors```



这里用了int10号中断，的03号功能

![image-20210113180615647](.\img\image-20210113180615647.png)



![image-20210113180746674](.\img\image-20210113180746674.png)



接下来加载system，以为前面已经加载了一个扇区的bootsect和4个扇区的setup，一共读取了5个扇区的数据了。

以下程序(read_it)把核心装载到内存 0x10000 处，并保证64KB 对齐。 尽可能快的读入内核，只要可能一次就读入整个磁道。

```
sread:	.word 0				# sectors read of current track
head:	.word 0				# current head
track:	.word 0				# current track

read_it:
	movb	setup_sects, %al   # 4 -> al
	incb	%al                # al is 5，下一个需要读取的扇区号就是5
	movb	%al, sread         # 已经读取的扇区数   
	movw	%es, %ax           # 0x1000 -> ax  
	testw	$0x0fff, %ax       # 64KB对齐
die:	jne	die				   # 如果不是64KB对齐的就死机

	xorw	%bx, %bx		   # 内核读到 es:bx,即 0x1000:0x0000
	
rp_read:
#ifdef __BIG_KERNEL__           # 如果是编译成bzImage,则lcall 0x220,即调用 setup 中的子程序 
								# bootsect_helper(setup 中偏移 0x20 处的指针指向的程序),把 
								# 0x10000 处的 64KB 内核移扩展内存 0x100000 开始处
	bootsect_kludge = 0x220		# 0x200 (size of bootsector) + 0x20 (offset
	lcall	bootsect_kludge		# of bootsect_kludge in setup.S)
	
#else                           # 否则为 zImage，读入内存 0x10000 处 
	movw	%es, %ax            # 0x1000 -> ax  
	subw	$SYSSEG, %ax        # ax = 0
#endif
	cmpw	syssize, %ax		# syssize = 0x7F00
								# ax 中是已读入的字节数，检查内核是否已全部读入内存，是则返回，								  # 否则继续
	jbe	ok1_read                # 内核还没全部读入，转到 ok1_read 继续读 
	ret
```

这里解释下为什么64KB对齐，分段是从CPU 8086 开始的，限于技术和经济，那时候电脑还是非常昂贵的东西，所以CPU 和寄存器等宽度都是16 位的，并不是像今天这样寄存器已经扩展到64位，当然编译器用的最多的还是32 位。16 位寄存器意味着其可存储的数字范围是2 的16 次方，即65536 字节，64KB，也就是一个段最多可以访问到64KB。



```````ok1_read:
# sread表示的是磁道内已经读取的扇区数，bx寄存器是16位的，最大就是64KB，有了已读扇区数，就知道了
# 未读扇区数，也就可以算出一个磁道还需要读取多少字节，这个值就保存在cx中，但是bx寄存器最大就是
# 64KB，所以未读字节数加上bx中的值可能会超过64KB，如果超过就64KB - cx，算出还能读取多少就可以。
# 没有超过就读取这个磁道未读字节数。

ok1_read:
	movw	sectors, %ax  # 每磁道扇区数，固定不变的
	subw	sread, %ax    # sread磁道已读扇区数，未读就时就是0，ax表示的是该磁道剩余未读扇区数				   		   # 即0磁道还需读入的扇区数	
	movw	%ax, %cx      # cx=磁道内还未读扇区数
	shlw	$9, %cx       # 左移9位，即乘以512，表示cx = 磁道还需读入的字节数
	addw	%bx, %cx      # 加上磁道内的未读字节数看是否已经超过bx寄存器存储的最大值（64KB）
	jnc	ok2_read          # CF=0 则跳转，不超过64KB边界(16位加法不溢出)，转向ok2_read
	je	ok2_read		  # ZF=1则跳转，正好64KB也转向ok2_read

	xorw	%ax, %ax      # 已经超过当前es:bx所能表示的范围，先把ax清0
	subw	%bx, %ax      # 由于寄存器是16位无符号的，所以0-bx = 65536-bx，結果为段內剩余字节数
	shrw	$9, %ax       # ax >> 9 转换成扇区数
	
	
# ok2_read是从ok1_read过来的，ok1_read初始化了 al=需要读取的扇区数，然后调用read_track读取磁道
# read_track返回后，al = 实际读取的扇区数数量，一个磁道内已读扇区数sread累加上这次读取的扇区数
# 和该磁道扇区数sectors对比，如果比sectors还说明这个磁道还没读完，调用ok3_read继续读
# 如果该磁道已经读完，如果当前是0磁头，那下次就读取1磁头，跳转到ok4_read；如果当前是1磁头，那么就把# 磁道号加1

ok2_read:
	call	read_track    # 读取磁道
	movw	%ax, %cx      # 读取后，al中保存着实际读取的扇区数数量，cx就表示这次已经读了多少扇区 
	addw	sread, %ax    # ax表示该磁道上已经读取的扇区总数
	cmpw	sectors, %ax  # 如果当前磁道上的还有扇区未读，则跳转到ok3_read 处 
	jne	ok3_read
	
	movw	$1, %ax       # 否则准备读下一磁道，ax = 1
	subw	head, %ax     # 1-head,当前是0磁头的话，则ax=1,表示下一次读1磁头；当前已是1磁						      #头，则磁道号增1
	jne	ok4_read
	
	incw	track         # 每个磁道有0磁头和1磁头两面，ax-head=0，说明某磁道已读完，此次该读下							 # 一磁道，调整track(磁道号增1)
	
# 能跳到ok4_read的，要么是之前读取的0磁头所在的磁道读完了，那么这次读取的就是1磁头的磁道
# 要么是上次读取的是1磁头的磁道，读完了，需要读取新磁道了。
ok4_read:
	movw	%ax, head     # 调整head(新的磁头号存入head）
	xorw	%ax, %ax      # 一个磁道读取完了，ax清0  
	
	
# 可以从ok2_read到ok3_read，说明该磁道还有未读扇区，继续读，sread=ax+sread
# 或者是从ok4_read下来的，需要读取新的磁道了，track加了1，sread=ax=0
# cx中保存着经过ok2_read是时读取的扇区数，转换为字节数，加上bx看有没有查过最大值64KB
# 如果没有超过就可以继续读跳转到rp_read
# 否则就表示bx所在的段已经被填充完了，需要到下一个段中，es增加0x1000，bx 清0，一个新的段，跳转到
# rp_read继续读。

ok3_read:
	movw	%ax, sread    # 调整sread 值(sread中存放当前磁道已读扇区数。如果是从ok4_read 下来							  # 的，则磁道号刚增1，sread=ax=0;否则是从ok2_read 下来的，是新的已读							  # 扇区数(sread=ax+sread))
	shlw	$9, %cx       # 刚读字节数
	addw	%cx, %bx      # 调整段内偏移(范围(0,64K)) 
	jnc	rp_read           # 若偏移<64KB,则es不变,直接转到rp_read进行下一轮读；否则(即已读完一							 # 个64KB了)要调整es(es=es+0x1000)和bx(bx=0)
	
	movw	%es, %ax      # ax=es  
	addb	$0x10, %ah    # ax=ax+0x1000 
	movw	%ax, %es      # es=ax,整个过程相当于es=es+0x1000 
	xorw	%bx, %bx      # bx 清0，所以es:bx 表示的内存地址增加了0x10000(即64KB)
	jmp	rp_read           # 返回rp_read 进行下一轮读以下读磁道 


# 把磁道中的数据读取到es:bx所在的内存中。
read_track:
	pusha   					# 压入 AX、CX、DX、BX、SP（原始值）、BP、SI 及 DI 
	pusha						# 压入 AX、CX、DX、BX、SP（原始值）、BP、SI 及 DI 
	movw	$0xe2e, %ax 		# 0x2e是’.’的ascii码，读一次在屏幕上显示一个“.”
	movw	$7, %bx
 	int	$0x10                   # 每次read都会在屏幕显示一个点，目的是让用户知道系统现在在运转
	popa		                # 弹出 DI,SI,BP,BX,DX,CX,AX
	
	movw	track, %dx    		# dl=磁道号
	movw	sread, %cx			# 已经读取的扇区数
	incw	%cx					# 下次开始读扇区号
	movb	%dl, %ch			# ch=磁道号,cl=读起始扇区号
	movw	head, %dx			# 磁头号放低字节	
	movb	%dl, %dh			# dh=磁头号
	andw	$0x0100, %dx        # dl=0(读软驱)
	movb	$2, %ah 			# ah=2,表示读磁盘；al=读扇区数
	pushw	%dx					# save for error dump
	pushw	%cx
	pushw	%bx
	pushw	%ax
	int	$0x13                   # 读取磁盘扇区，如果读取成功，al中会保存实际读取的扇区数
	jc	bad_rt                  # 读取磁盘有问题，跳到bad_rt
	
	addw	$8, %sp             # 前面push了4个字，即8字节的数据，这里加8表示栈顶后退8个字节
	popa                        # 依次恢复DI、SI、BP、SP、BX、DX、CX、AX
	ret

bad_rt:
	pushw	%ax				    # 读取磁盘失败，错误码就会在ah中，把ax压栈，给print_all当参数
	call	print_all			# ah = error, al = read
	xorb	%ah, %ah            # 清0
	xorb	%dl, %dl
	int	$0x13                   # ah=0表示重置磁盘系统
	addw	$10, %sp
	popa
	jmp read_track				# 继续读磁盘
```````

int10中断，功能ah=0x0e，在屏幕上显示一个字符。

![image-20210114104936126](.\img\image-20210114104936126.png)

读取的扇区会保存到es:bx中，bx就是段偏移地址，加上cx中未读的字节数



rp_read 是循环的起点， 每轮循环要么读完一个磁道，要么读满一个64KB， 如果定义了—BIG_KERNEL—（生成bz-Image 的情况）， 则把刚读入的64KB 移到内存0x100000 以上。
2） rp_read： 检查内核读完否， 是则返回(ret) ,否则转到ok1_read。



ok1_read： 计算当前磁道还需读入的扇区、字节数， 检查(此字节数+bx 段内偏移) 是否超出64KB 边界， 若不超出或正好满64KB， 则转向ok2_read;否则调整需读字节数， 使(字节数+bx) =64KB， 将字节数折合到扇区数（左移9 位）， 执行ok2_read。



ok2_read： 调用read_track 读磁道(之前已准备好的参数有ax=读扇区数， bx=段内偏移， head=磁头号， track=磁道号， sread=当前磁道已读扇区数)。检查当前磁道读完否： 若已读完， 调整track， 调整head (在ok4_read 处)， 转到ok3_read;否则直接转到ok3_read。

ok3_read： 调整sread， 调整段内偏移bx。检查段内偏移是否达到64KB， 是则调整es=es+0x1000， bx=0， 然后回到rp_read 进行下一轮循环； 否则直接转到rp_read， 无需调整es。



`````
	movw	root_dev, %ax   # root_dev标号的偏移地址 -> ax
	orw	%ax, %ax
	jne	root_defined        # 如果ax不为0，就跳到 root_defined
	
	movw	sectors, %bx    
	movw	$0x0208, %ax	# /dev/ps0 - 1.2Mb
	cmpw	$15, %bx
	je	root_defined
	
	movb	$0x1c, %al		# /dev/PS0 - 1.44Mb
	cmpw	$18, %bx
	je	root_defined
	
	movb	$0x20, %al		# /dev/fd0H2880 - 2.88Mb
	cmpw	$36, %bx
	je	root_defined
	
	movb	$0, %al			# /dev/fd0 - autodetect
root_defined:
	movw	%ax, root_dev   # 定义根设备号

	ljmp	$SETUPSEG, $0     # 跳到setup模块执行
`````



参考：

[Interrupt Jump Table](http://www.ctyme.com/intr/int.htm)

[A.1 BIOS Interrupt Overview](https://docs.huihoo.com/gnu_linux/own_os/appendix-bios_interrupt_1.htm)

http://staff.ustc.edu.cn/~xyfeng/research/cos/resources/BIOS/Resources/assembly/int1e.html

