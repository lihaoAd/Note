!
! SYS_SIZE is the number of clicks (16 bytes) to be loaded.
! 0x3000 is 0x30000 bytes = 196kB, more than enough for current
! versions of linux
!
SYSSIZE = 0x3000
!
!	bootsect.s		(C) 1991 Linus Torvalds
!
! bootsect.s is loaded at 0x7c00 by the bios-startup routines, and moves
! iself out of the way to address 0x90000, and jumps there.
!
! It then loads 'setup' directly after itself (0x90200), and the system
! at 0x10000, using BIOS interrupts. 
!
! NOTE! currently system is at most 8*65536 bytes long. This should be no
! problem, even in the future. I want to keep it simple. This 512 kB
! kernel size should be enough, especially as this doesn't contain the
! buffer cache as in minix
!
! The loader has been made as simple as possible, and continuos
! read errors will result in a unbreakable loop. Reboot by hand. It
! loads pretty fast by getting whole sectors at a time whenever possible.

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

SETUPLEN = 4				! nr of setup-sectors
BOOTSEG  = 0x07c0			! original address of boot-sector
INITSEG  = 0x9000			! we move boot here - out of the way
SETUPSEG = 0x9020			! setup starts here
SYSSEG   = 0x1000			! system loaded at 0x10000 (65536).
ENDSEG   = SYSSEG + SYSSIZE		! where to stop loading

! ROOT_DEV:	0x000 - same type of floppy as boot.
!		0x301 - first partition on first drive etc
ROOT_DEV = 0x306

! 程序入口
entry _start
_start:
	mov	ax,#BOOTSEG  ! ax = 0x07c0
	mov	ds,ax		 ! ds = 0x07c0,段寄存器
	mov	ax,#INITSEG  ! ax = 0x9000 
	mov	es,ax		 ! es = 0x9000,段寄存器
	mov	cx,#256		 ! cx = 256,循环	256次,每次1个字，一共512个字节，即一个扇区
	sub	si,si        ! si清0
	sub	di,di        ! di清0
	rep              ! 重复执行movw指令，一直到cx=0
	movw             ! 把ds:si处的字复制到es:di地址处 ，即把0x07c0:0地址处的数据复制到0x9000:0处
	jmpi	go,INITSEG  ！cs=0x9000，ip的内容就是go标号处的偏移地址 

!段寄存器全部修改为 0x9000	
go:	mov	ax,cs        ! ax = cs = 0x9000
	mov	ds,ax        ! ds = ax = 0x9000
	mov	es,ax        ! es = ax = 0x9000 
! put stack at 0x9ff00.
	mov	ss,ax        ! ss = ax = 0x9000
	mov	sp,#0xFF00	 ! arbitrary value >>512,把栈顶地址放在0x9000:0xFF00

! load the setup-sectors directly after the bootblock.
! Note that 'es' is already set up.

! 前面已经读取一个扇区，并将数据复制到0x9000：0处，load_setup的作用就是后面4个扇区到es:bx地址
! 上面已经对es赋值为 0x9000，bx的内容是0x0200，即把数据读取到0x9000：0x0200，0x0200的值就是512，
! 紧跟在bootsect的后面。读取失败就会一直重试
load_setup:
	mov	dx,#0x0000		! drive 0, head 0
	mov	cx,#0x0002		! sector 2, track 0
	mov	bx,#0x0200		! address = 512, in INITSEG
	mov	ax,#0x0200+SETUPLEN	! service 2, nr of sectors
	int	0x13			! read it
	jnc	ok_load_setup		! ok - continue
	mov	dx,#0x0000
	mov	ax,#0x0000		! reset the diskette
	int	0x13
	j	load_setup

! 已经把setup的4个扇区读取到0x9000：0x0200了，下面获取一个磁盘信息，尤其是每个磁道的扇区数
ok_load_setup:

! Get disk drive parameters, specifically nr of sectors/track
! ES:DI -> drive parameter table (floppies only)

	mov	dl,#0x00
	mov	ax,#0x0800		! AH=8 is get drive parameters
	int	0x13
	mov	ch,#0x00        ! 清除ch的内容 
	seg cs
	mov	sectors,cx      ! cl中存每磁道扇区数，ch被清0后，cx表示的就是每磁道扇区数，扇区数被存在cs:[sectors]的位置，cs已经是0x9000的段地址了
	mov	ax,#INITSEG     ! 读取驱动参数后，ax被赋值了，现在再次把ax的内容赋值为0x9000 
	mov	es,ax           ! es = 0x9000 

！现在拿到了每个磁道有sectors个扇区
! Print some inane message

	! int 0x10中断 功能号ah=0x03,读取光标位置
	mov	ah,#0x03		! read cursor pos

	! bh 置为0，作为int 0x10中断的输入：bh=页号
	xor	bh,bh

	! 发出中断， 返回：ch=扫描开始线；cl=扫描结束线；dh=行号； dl=列号
	int	0x10
	

	! 显示24个字符
	mov	cx,#24

	! bh=0，页=0；bl=7，字符属性=7
	mov	bx,#0x0007		! page 0, attribute 7 (normal)

	! es:bp寄存器指向要显示的字符串
	mov	bp,#msg1

	! BIOS中断0x10功能号ah=0x13，功能：显示字符串
	! 输入：al=放置光标方式及规定属性。0x01表示使用bl中属性值，光标停在字符串结尾处；
	! es:bp 指向要显示的字符串起始位置。 cx=显示字符串个数； bh=显示页面号
	! bl=字符属性； dh=行号； dl=页号
	mov	ax,#0x1301		! write string, move cursor
	int	0x10

! ok, we've written the message, now
! we want to load the system (at 0x10000)

! 上面已经加载了setup 4个扇区的数据，下面加载system数据
	mov	ax,#SYSSEG  ! ax = 0x1000
	mov	es,ax		! segment of 0x010000 ，es = ax  = 0x1000
	call	read_it ! 执行call指令，先把后面的地址存到ip中，然后跳转 read_it 标号处执行  
	call	kill_motor

! After that we check which root-device to use. If the device is
! defined (!= 0), nothing is done and the given device is used.
! Otherwise, either /dev/PS0 (2,28) or /dev/at0 (2,8), depending
! on the number of sectors that the BIOS reports currently.

	seg cs
	mov	ax,root_dev
	cmp	ax,#0
	jne	root_defined
	seg cs
	mov	bx,sectors
	mov	ax,#0x0208		! /dev/ps0 - 1.2Mb
	cmp	bx,#15
	je	root_defined
	mov	ax,#0x021c		! /dev/PS0 - 1.44Mb
	cmp	bx,#18
	je	root_defined
undef_root:
	jmp undef_root
root_defined:
	seg cs
	mov	root_dev,ax

! after that (everyting loaded), we jump to
! the setup-routine loaded directly after
! the bootblock:

	jmpi	0,SETUPSEG

! This routine loads the system at address 0x10000, making sure
! no 64kB boundaries are crossed. We try to load it as fast as
! possible, loading whole tracks whenever we can.
!
! in:	es - starting address segment (normally 0x1000)
!
! 定义局部变量，已读扇区数，由于前面加载了bootsect(1个扇区数据)和setup(4个扇区数据),
! 所以这里1+SETUPLEN
sread:	.word 1+SETUPLEN	! sectors read of current track

!磁头号
head:	.word 0			! current head

! 磁道号
track:	.word 0			! current track

read_it:

	mov ax,es     ! 前面已经设置了es的内容是0x1000， ax = 0x1000

	! 正常情况下：test ax,#0x0fff结果为0，则ZF=1。不满足JNE跳转条件（ZF=0）
	test ax,#0x0fff

die:	jne die			! es must be at 64kB boundary

	! bx 为段内偏移
	! 清bx 寄存器，用于表示当前段内存放数据的开始位置
	xor bx,bx		! bx is starting address within segment

rp_read:
	mov ax,es

	! ax - ENDSEG的结果会修改ZF标志，如果结果为0，则ZF=1，否则ZF=0
	! 
	cmp ax,#ENDSEG		! have we loaded all yet?
	
	! jb指令当进位CF标志位为1时跳转到ok1_read标号处
	! cmp是减法，如果CF = 1,说明有借位，此时ax的值比#ENDSEG的值小
	! 说明没有读完,跳转ok1_read处执行
	jb ok1_read

	ret
ok1_read:
	seg cs
	mov ax,sectors
	sub ax,sread
	mov cx,ax
	shl cx,#9
	add cx,bx
	jnc ok2_read
	je ok2_read
	xor ax,ax
	sub ax,bx
	shr ax,#9
ok2_read:
	call read_track
	mov cx,ax
	add ax,sread
	seg cs
	cmp ax,sectors
	jne ok3_read
	mov ax,#1
	sub ax,head
	jne ok4_read
	inc track
ok4_read:
	mov head,ax
	xor ax,ax
ok3_read:
	mov sread,ax
	shl cx,#9
	add bx,cx
	jnc rp_read
	mov ax,es
	add ax,#0x1000
	mov es,ax
	xor bx,bx
	jmp rp_read

read_track:
	push ax
	push bx
	push cx
	push dx
	mov dx,track
	mov cx,sread
	inc cx
	mov ch,dl
	mov dx,head
	mov dh,dl
	mov dl,#0
	and dx,#0x0100
	mov ah,#2
	int 0x13
	jc bad_rt
	pop dx
	pop cx
	pop bx
	pop ax
	ret
bad_rt:	mov ax,#0
	mov dx,#0
	int 0x13
	pop dx
	pop cx
	pop bx
	pop ax
	jmp read_track

!/*
! * This procedure turns off the floppy drive motor, so
! * that we enter the kernel in a known state, and
! * don't have to worry about it later.
! */
kill_motor:
	push dx
	mov dx,#0x3f2
	mov al,#0
	outb
	pop dx
	ret

sectors:
	.word 0

msg1:
	
	! \r\n
	.byte 13,10

	! ascii码"Loading system ..."占据18字节 
	.ascii "Loading system ..."

	! \r\n\r\n
	.byte 13,10,13,10

.org 508
root_dev:
	.word ROOT_DEV
boot_flag:
	.word 0xAA55

.text
endtext:
.data
enddata:
.bss
endbss:
