## 概述

还记得的setup被加载到什么内存地址了吗？

就是 0x9000:0x0200



## 光标

先来看看实模式下的内存布局，显示器有很多种模式，如图形模式、文本模式等，在文本模式中，又可以工作于 80 * 25 和 40 * 25 等显示方式， 默认情况下，所有个人计算机上的显卡在加电后都将自己置为 80 * 25 这种显示方式。 80 * 25 是指一屏可以显示 25 行、每行 80 列的字符，也就是 2000 个字符。但由于一个字符要用两字节来表示，低字符是字符的 ASCII 编码，高字节是字符属性，故显示一屏字符需要用 4000 字节（实际上，分配给一屏的容量是 4KB），这一屏就称为一页， 0 页是默认页。

  文本模式下显存物理地址范围为 0xb8000～0xbffff，  在 80 * 25 文本模式下屏幕可显示 2000 个字（字符），4000 字节的内容。显存有 32KB，按理说显存中可以存放 32KB/4000B约等于 8 屏的字符。这就是为什么 Linux 可以用 alt + Fn 键实现 tty 的切换  

<img src="img\image-20210609220902315.png" alt="image-20210609220902315" style="zoom:50%;" />

屏幕上每个字符的低字节是字符的 ASCII 码，高字节是字符属性元信息。在高字节中，低 4 位是字符前景色，高 4 位是字符的背景色。颜色用 RGB 红绿蓝三种基色调和，第 4 位用来控制亮度，若置 1 则呈高亮，若为 0 则为一般正常亮度值。第 7 位用来控制字符是否闪烁（不是背景闪烁）。  

<img src="img\image-20210609221707528.png" alt="image-20210609221707528" style="zoom:50%;" />

[int 10 AH=3](http://www.ctyme.com/intr/rb-0088.htm)

```c++
    mov	ax,#INITSEG	! ax = 0x9000
	mov	ds,ax       ! ds = 0x9000
	mov	ah,#0x03	! read cursor pos
	xor	bh,bh
	int	0x10		! save it in known place, con_init fetches
	mov	[0],dx		! 把光标位置放在ds:[0]即 0x9000:0x0000这个位置,占2个字节
```

​                                                    <img src="img\image-20210609220025033.png" alt="image-20210609220025033" style="zoom: 80%;" />



## 扩展内存

利用 BIOS 中断 0x15 子功能 0x88 获取内存  ，该方法使用最简单，但功能也最简单，简单到只能识别最大 64MB 的内存。即使内存容量大于 64MB，也只会显示 63MB  ，为什么是63MB、很多问题都是祖上传下来的，即著名的历史遗留问题。 80286 拥有 24 位地址线，其寻址空间是 16MB。当时有一些 ISA 设备要用到地址 15MB 以上的内存作为缓冲区，也就是此缓冲区为 1MB 大小，所以硬件系统就把这部分内存保留下来，操作系统不可以用此段内存空间。保留的这部分内存区域就像不可以访问的黑洞，这就成了内存空洞 memory hole。现在虽然很少很少能碰到这些老 ISA 设备了，但为了兼容，这部分空间还是保留下来，只不过是通过 BIOS 选项的方式由用户自己选择是否开启。

以 1KB 为单位大小，内存空间 1MB 之上的连续单位数量，不包括低端 1MB 内存。故内存大小为 AX*1024 字节+1MB

扩展内存被存到了0x9000 : 0x0002这个位置，占2字节     

[int 15 AH-0x88](http://www.ctyme.com/intr/rb-1529.htm)或者在[这里](http://www.uruk.org/orig-grub/mem64mb.html#int15e801)找到相关中断资料


```c++
! 获取扩展内存的大小，kB为单位	
! Get memory size (extended mem, kB)
mov	ah,#0x88
int	0x15
mov	[2],ax    ! ds:[2]即 0x9000:0x0002这个位置存着扩展内存的大小（kB）
```

<img src="img\image-20210609225513729.png" alt="image-20210609225513729" style="zoom:80%;" />

## 显卡

[显卡的显示模式](http://vitaly_filatov.tripod.com/ng/asm/asm_023.1.html),或者到[这里](http://www.ctyme.com/intr/rb-0069.htm)找资料，

<img src="C:\Users\LIHAO\Desktop\Slash\linux\0.11\img\image-20210609231143923.png" alt="image-20210609231143923" style="zoom: 50%;" />

```c++
! Get video-card data:
	mov	ah,#0x0f
	int	0x10
	mov	[4],bx		! bh = display page， 0x9000:0x0004存着显示页
	mov	[6],ax		! al = video mode, ah = window width 
```

<img src="img\image-20210609231422147.png" alt="image-20210609231422147" style="zoom:80%;" />

```c++

! check for EGA/VGA and some config parameters

	mov	ah,#0x12
	mov	bl,#0x10
	int	0x10
	mov	[8],ax
	mov	[10],bx
	mov	[12],cx
	
```

<img src="C:\Users\LIHAO\Desktop\Slash\linux\0.11\img\image-20210609232149619.png" alt="image-20210609232149619" style="zoom: 50%;" />

<img src="C:\Users\LIHAO\Desktop\Slash\linux\0.11\img\image-20210609232338774.png" alt="image-20210609232338774" style="zoom:80%;" />



## 磁盘信息

第一个软盘的信息已经被bios存在4 * 0x41的内存地址处，如果有第二个磁盘的信息，就存在 4 * 46内存地址处，如果没有第二个硬盘，就会把该16字节的空间清0。

接下来就是准备进入保护模式了。

```c++
! Get hd0 data

	mov	ax,#0x0000
	mov	ds,ax           ! 段寄存器ds=0，内存地址从0开始
	lds	si,[4*0x41]     ! ds:si,即0x0000:4*0x41地址的地方存着hd0的参数
	mov	ax,#INITSEG     ! ax = 0x9000
	mov	es,ax           ! es = ax = 0x9000
	mov	di,#0x0080      ! di = 0x0080  
	mov	cx,#0x10        ! cx = 0x10,循环16次,
	rep                 ! 把ds:si的数据复制到es:di的地方，即 0x0000:4*0x41 -> 0x9000:0x0080,一共复制16字节
	movsb

! Get hd1 data

	mov	ax,#0x0000
	mov	ds,ax
	lds	si,[4*0x46]
	mov	ax,#INITSEG
	mov	es,ax
	mov	di,#0x0090
	mov	cx,#0x10
	rep
	movsb

! Check that there IS a hd1 :-)

	mov	ax,#0x01500
	mov	dl,#0x81
	int	0x13
	jc	no_disk1        ! CF = 1 就跳转到no_disk1，说明没有第二个磁盘
	cmp	ah,#3           !  是不是硬盘
	je	is_disk1  
no_disk1:
	mov	ax,#INITSEG     ! ax = 0x9000
	mov	es,ax           ! es = 0x9000
	mov	di,#0x0090      ! 第二个硬盘信息的地址
	mov	cx,#0x10        ! 循环16次
	mov	ax,#0x00        ！
	rep
	stosb               ! 将累加器al中的值传递到当前ES段的DI地址处，并且根据DF的值来影响DI的值，如果DF为0，则调用该指令后，DI自增1，如果DF为1,DI自减1
```

这里补充一点关于 `movsb、movsw`的知识，因为后面的代码会用到相关知识， 这两个指令通常用于把数据从内存中的一个地方批量地传送（复制）到另一个地方，处理器把它们看成数据串。但是，`movsb`的传送是以字节为单位的，而`movsw`的传送是以字为单位的。 `movsb`和`movsw`指令执行时，原始数据串的段地址由`DS`指定，偏移地址由`SI`指定，简写`DS：SI`；要传送到的目的地址由`ES：DI`指定；传送的字节数（movsb）或者字数（movsw）由`CX`指定。除此之外，还要指定是正向传送还是反向传送，正向传送是指传送操作的方向是从内存区域的低地址端到高地址端；反向传送则正好相反。正向传送时，每传送一个字节（movsb）或者一个字（movsw），`SI`和`DI`加1或者加2；反向传送时，每传送一个字节（movsb）或者一个字（movsw）时，`SI`和`DI`减去1或者减去2。不管是正向传送还是反向传送，也不管每次传送的是字节还是字，每传送一次，`CX`的内容自动减1。 标志寄存器的第10位是方向标志`DF（Direction Flag）`，`DF=0`表示正向传送，`DF=1`表示反向传送。 `cld`指令将DF标志清零，`std`指令将DF标志置1

<img src="img\image-20210610222949529.png" alt="image-20210610222949529" style="zoom: 50%;" />

图片来源https://stanislavs.org/helppc/int_13-15.html





## 关闭中断

准备进入保护模式，首先关闭中断，复制system到内存的0x0000，这个过程中不能被软中断打断执行，不过一些致命的中断计算机还是会执行的。初始化idtr和gdtr寄存器，打开A20，寻址达到4GB，覆盖了中断向量，后面就会用IDT来代替了。bootsect 引导程序是将system 模块读入到从0x10000（64k）开始的位置。由于当时假设system 模块最大长度不会超过0x80000（512k），也即其末端不会超过内存地址0x90000，所以bootsect 会将自己移动到0x90000 开始的地方，并把setup 加载到它的后面。 下面这段程序的用途是再把整个system 模块移动到0x00000 位置，即把从0x10000 到0x8ffff 的内存数据块(512k)，整块地向内存低端移动了0x10000（64k）的位置。

```c++
	cli			          ! 关闭中断，需要等到main.c中开启中断
	mov	ax,#0x0000        ! ax = 0x0000 
	cld			          ! DF=0,正向传送, 把system 地址0x1000:0x0000 所在的数据复制到0x0000:0x0000	
do_move:
	mov	es,ax		      ! es = 0x0000
	add	ax,#0x1000        ! ax = 0x1000
	cmp	ax,#0x9000        ! 
	jz	end_move
	mov	ds,ax		      ! ds = 0x1000
	sub	di,di
	sub	si,si
	mov 	cx,#0x8000
	rep
	movsw
	jmp	do_move
```

## system搬运结束

准备好IDT与GDT.

```c++
end_move:
	mov	ax,#SETUPSEG	! right, forgot this at first. didn't work :-)
	mov	ds, 
	lidt	idt_48		! 此时程序还在0x9000 这个段里运行，0x9020就是setup程序所在的地址，加载中断描述符表的地址到idtr寄存器
	lgdt	gdt_48		! 加载全局描述符表的地址到gdtr寄存器

! that was painless, now we enable A20

	call	empty_8042
	mov	al,#0xD1		! command write
	out	#0x64,al
	call	empty_8042
	mov	al,#0xDF		! A20 on
	out	#0x60,al
	call	empty_8042
```



## "8042" PS/2 Controller

<img src="img\Ps-2-ports.JPG" alt="image-20210610222949529"  />

**PS/2接口**是一种[PC兼容型](https://zh.wikipedia.org/wiki/PC相容型)电脑系统上的接口，可以用来链接[键盘](https://zh.wikipedia.org/wiki/鍵盤)及[鼠标](https://zh.wikipedia.org/wiki/滑鼠)。PS/2的命名来自于1987年时IBM所推出的[个人电脑](https://zh.wikipedia.org/wiki/個人電腦)：[PS/2](https://zh.wikipedia.org/wiki/PS/2)系列。PS/2鼠标连接通常用来取代旧式的序列鼠标接口（[DB-9](https://zh.wikipedia.org/w/index.php?title=DB-9&action=edit&redlink=1) [RS-232](https://zh.wikipedia.org/wiki/RS-232)）；而PS/2键盘连接则用来取代为[IBM PC/AT](https://zh.wikipedia.org/wiki/IBM_PC/AT)所设计的大型5-pin [DIN接口](https://zh.wikipedia.org/wiki/DIN连接器)。PS/2的键盘及鼠标接口在电气特性上十分类似，其中主要的差别在于键盘接口需要双向的沟通。在早期如果对调键盘和鼠标的插槽，大部分的台式机[主板](https://zh.wikipedia.org/wiki/主機板)不能将其正确识别。现在已经出现共享接口，能够随意插入键盘或鼠标并正确识别处理。

目前PS/2接口已经慢慢的被[USB](https://zh.wikipedia.org/wiki/通用序列匯流排)所取代，只有少部分的[台式机](https://zh.wikipedia.org/wiki/桌上型電腦)仍然提供完整的PS/2[键盘](https://zh.wikipedia.org/wiki/鍵盤)及[鼠标](https://zh.wikipedia.org/wiki/滑鼠)接口，少部分机器则已无PS/2，大部分的机器仅提供一组[键盘](https://zh.wikipedia.org/wiki/鍵盤)及[鼠标](https://zh.wikipedia.org/wiki/滑鼠)可以共享之PS/2接口或是仅可供[键盘](https://zh.wikipedia.org/wiki/鍵盤)使用。有些鼠标及键盘可以使用转换器将接口由USB转成PS/2，亦有可从USB分接成键盘鼠标用PS/2接口的转接线。不过，由于USB接口对键盘无特殊调整下最大只能支持6键无冲突，而PS/2键盘接口可以支持所有按键同时而无冲突。因此大部分主板PS/2键盘连接端口仍然被保留，或是仅保留一组PS/2[键盘](https://zh.wikipedia.org/wiki/鍵盤)及鼠标都可共享之PS/2端口，同时保留[键盘](https://zh.wikipedia.org/wiki/鍵盤)及[鼠标](https://zh.wikipedia.org/wiki/滑鼠)各自单独接口之主板目前已经比较少。

端口 0x64 是键盘控制器的 IO 端口，键盘控制器有两个端口 0x64 和 0x60。

端口 0x64（命令端口）用于向键盘控制器（PS/2）发送命令。

端口 0x60（数据端口）用于向/从 PS/2（键盘）控制器或 PS/2 设备本身发送数据。

<img src="img\image-20210611235008882.png" alt="image-20210611235008882" style="zoom: 80%;" />

````c++
empty_8042:
	.word	0x00eb,0x00eb
	in	al,#0x64	    ! 8042 status port， 读取PS/2控制器的8位长的状态寄存器。具体来说，它试图读取输入缓冲区的状态 
	test	al,#2		! is input buffer full? 这里检查输入缓冲区的状态以查看它是满还是空
	jnz	empty_8042	    ! yes - loop
	ret
````

![image-20210611234754356](img\image-20210611234754356.png)





第一个段描述符默认不用，第二个，段界限（limit）是0x07FF，即limit = 2047，同时G=1，那么这个段的大小就是（2047 +1）* 4096 =8Mb，P=1即这个段指向的内存地址还在内存中，DPL=0表示内核态， S=1表示非系统段，Type = 1010b表示的是以一个代码段，并且是一致性代码段，D/B=1表示地址是32位，段基址是0。

第三个段描述符，limit=2047，段大小8Mb，段基址是0，Type=0010表示的是这是一个数据段

```c++
gdt:
	.word	0,0,0,0		! 第一个默认不用，全是0

    ! 内核的代码段，大小8Mb，段基址0    
	.word	0x07FF		! 0000 0111 1111 1111,  8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! 0000 0000 0000 0000,  base address=0
	.word	0x9A00		! 1001 1010 0000 0000,  code read/exec
	.word	0x00C0		! 0000 0000 1100 0000,  granularity=4096, 386
        
    ! 内核的数据段，大小8Mb，段基址0   
	.word	0x07FF		! 0000 0111 1111 1111,  8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! 0000 0000 0000 0000,  base address=0
	.word	0x9200		! 1001 0010 0000 0000,  data read/write 
	.word	0x00C0		! 0000 0000 1100 0000,  granularity=4096, 386

idt_48:
	.word	0			! idt limit=0
	.word	0,0			! idt base=0L

gdt_48:
	.word	0x800		! gdt limit=2048, 256 GDT entries
	.word	512+gdt,0x9	! gdt base = 0X9xxxx
```

![img](img\5477b7a42f4142f7ab6a298faed29476~tplv-k3u1fbpfcp-watermark.image)



图片来源[英特尔® 64 位和 IA-32 架构开发人员手册：卷 3A](https://www.intel.cn/content/www/cn/zh/architecture-and-technology/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.html) 第196页,这个图描述的是32位计算机IDTR寄存器（48位），0-15位表示中断描述符的数量即2的16次方，16-47表示中断描述符表的内存地址，现在还在实模式，段地址+偏移地址就是物理地址了。后面进入保护模式，还会重新指定一个新的中断描述符表的，这个时候，IDT Base Address中存的地址可就是虚拟地址了（分页的条件下叫虚拟地址，没有分页就是线性地址）。

存储中断描述符表的寄存器是IDTR，48位，存储全局描述符表的寄存器是GDTR，48位，这 48 位内存数据划分为两部分，其中前 16 位是 GDT 以字节为单位的界限值，所以这 16 位相当于GDT 的字节大小减 1。后 32 位是 GDT 的起始地址。由于 GDT 的大小是 16 位二进制，其表示的范围是 2的16次方等于65536字节。每个描述符大小是8字节，故， GDT中最多可容纳的描述符数量是65536/8=8192个，即 GDT 中可容纳 8192 个段或门。  

![image-20210610234755785](C:\Users\LIHAO\Desktop\Slash\linux\0.11\img\image-20210610234755785.png)



无论是中断描述符表还是全局描述符表，里面存的都是段描述符，一个段描述符大小是64字节。

<img src="img\image-20210610235122127.png" alt="image-20210610235122127" style="zoom: 67%;" />

实模式下寻址是段地址+偏移地址，段寄存器中存的是段地址，到了保护模式下，段寄存器中存的是段选择子，如果把全局描述符表看成一个数组，选择子就是关于这个数组的索引,这个索引大小是13位的，即 2 的 13 次方是 8192，故最多可以索引 8192 个段，这和 GDT中最多定义 8192 个描述符是吻合的。  

![image-20210610235429509](img\image-20210610235429509.png)

再来看看 idt_48 处的数据，加载idt_48 到IDTR寄存器后，idt limit = 0 ，现在还没用到中断，大小是0，idt base address 也是0，这里也就是默认创建一个idt，只不过大小是0，加载gdt_48到GDTR后，gdt limit=2048,表示可以有256个段描述符，512+gdt,0x9表示

GDT 中的第 0 个段描述符是不可用的，原因是定义在 GDT 中的段描述符是要用选择子来访问的，如果使用的选择子忘记初始化，选择子的值便会是 0，这便会访问到第 0 个段描述符。为了避免出现这种因忘记初始化选择子而选择到第 0 个段描述符的情况， GDT 中的第 0 个段描述符不可用。也就是说，若选择到了 GDT 中的第 0 个描述符，处理器将发出异常。  

- S 字段，用来指出当前描述符是否是系统段。S 为 0 表示系统段， S 为 1 表示非系统段  ,S字段与Type字段结合起来才能知道这是一个什么段

![image-20210611230401119](C:\Users\LIHAO\Desktop\Slash\linux\0.11\img\image-20210611230401119.png)

表中的 A 位表示 Accessed 位，这是由 CPU 来设置的，每当该段被 CPU 访问过后， CPU 就将此位置 1。所以，创建一个新段描述符时，应该将此位置 0。  

- DPL 字段， Descriptor Privilege Level，即描述符特权级  
- P 字段， Present，即段是否存在。如果段存在于内存中， P 为 1，否则 P 为 0。P 字段是由 CPU 来检查的，如果为 0， CPU 将抛出异常，转到相应的异常处理程序，此异常处理程序是咱们来写的，在异常处理程序处理完成后要将 P 置 1。也就是说，对于 P 字段， CPU 只负责检查，咱们负责赋值。不过在通常情况下，段都是在内存中的。  
- AVL 字段，从名字上看它是 AVaiLable，可用的。不过这“可用的”是对用户来说的，也就是操作系统可以随意用此位。对硬件来说，它没有专门的用途，就当作是硬件给软件的馈赠吧  
- L 字段，用来设置是否是 64 位代码段。 L 为 1 表示 64 位代码段，否则表示 32位代码段。这目前属于保留位，在我们 32 位 CPU 下编程，将其置为 0 便可。  
- D/B 字段，用来指示有效地址（段内偏移地址）及操作数的大小。有没有觉得奇怪，实模式已经是 32 位的地址线和操作数了，难道操作数不是 32 位大小吗？其实这是为了兼容 286 的保护模式， 286 的保护模式下的操作数是 16 位。既然是指定“操作数”的大小，也就是对“指令”来说的，与指令相关的内存段是代码段和栈段，所以此字段是 D 或 B。对于代码段来说，此位是 D 位， 若 D 为 0，表示指令中的有效地址和操作数是 16 位，指令有效地址用 IP 寄存器。若 D 为 1，表示指令中的有效地址及操作数是 32 位，指令有效地址用 EIP 寄存器。对于栈段来说，此位是 B 位，用来指定操作数大小，此操作数涉及到栈指针寄存器的选择及栈的地址上限。若 B 为 0，使用的是 sp 寄存器，也就是栈的起始地址是 16 位寄存器的最大寻址范围， 0xFFFF。若 B 为 1，使用的是 esp 寄存器，也就是栈的起始地址是 32 位寄存器的最大寻址范围0xFFFFFFFF。  
- G 字段， Granularity，粒度，用来指定段界限的单位大小。所以此位是用来配合段界限的，它与段界限一起来决定段的大小。若 G 为 0，表示段界限的单位是 1 字节，这样段最大是 2的 20 次方 * 1 字节，即 1MB。若 G 为 1，表示段界限的单位是 4KB，这样段最大是 2 的 20 次方 * 4KB 字节，即 4GB。 



## 8259A

8259A 的作用是负责所有来自外设的中断，其中就包括来自时钟的中断  。



```c++
    mov	al,#0x11		! initialization sequence
	out	#0x20,al		! send it to 8259A-1
	.word	0x00eb,0x00eb		! jmp $+2, jmp $+2
	out	#0xA0,al		! and to 8259A-2
	.word	0x00eb,0x00eb
	mov	al,#0x20		! start of hardware int's (0x20)
	out	#0x21,al
	.word	0x00eb,0x00eb
	mov	al,#0x28		! start of hardware int's 2 (0x28)
	out	#0xA1,al
	.word	0x00eb,0x00eb
	mov	al,#0x04		! 8259-1 is master
	out	#0x21,al
	.word	0x00eb,0x00eb
	mov	al,#0x02		! 8259-2 is slave
	out	#0xA1,al
	.word	0x00eb,0x00eb
	mov	al,#0x01		! 8086 mode for both
	out	#0x21,al
	.word	0x00eb,0x00eb
	out	#0xA1,al
	.word	0x00eb,0x00eb
	mov	al,#0xFF		! mask off all interrupts for now
	out	#0x21,al
	.word	0x00eb,0x00eb
	out	#0xA1,al
```



## 进入保护模式

```c++
mov	ax,#0x0001	! protected mode (PE) bit
lmsw	ax		! This is it!
jmpi	0,8		! jmp offset 0 of segment 8 (cs)
```
前面我们准备了GDT，打开了A20，现在就差一部就可以进入保护模式，就是将CR0控制寄存器的PE置为1。lmsw就是把源操作数加载到CR0.。然后执行跳转，CS寄存器中的值就是8，此时已经是保护模式，这里的8已经不是段地址，而是段选择子，8的16位二进制数是 0000 1000b，RPL=0表示内核态，TI=0表示段描述符在GDT中，index=1，即GDT的第2个段描述符，也就是内核的代码段。该段的基址地址是0，

+<img src="img\image-20210612212932379.png" alt="image-20210612212932379" style="zoom:80%;" />

[图片来源: 英特尔® 64 位和 IA-32 架构开发人员手册：卷 3A](https://www.intel.cn/content/www/cn/zh/architecture-and-technology/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.html)第76页



参靠

http://ftp.ca.net/~pkern/stuff/cterm+/cterm/int-10

http://www.uruk.org/orig-grub/mem64mb.html#int15e801

http://www.ctyme.com/intr/rb-0108.htm

https://wiki.osdev.org/%228042%22_PS/2_Controller

https://www.intel.cn/content/www/cn/zh/architecture-and-technology/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.html