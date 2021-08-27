#
# if you want the ram-disk device, define this to be the
# size in blocks.
#

# 如果你要使用RAM盘设备，就定义块的大小
RAMDISK =  #-DRAMDISK=512

# 定义了1个标识符，as86是16位汇编命令，-0 生成8086目标程序，-a 生成与gas和gld部分兼容的代码。
# AS86是一个能汇编16位8086汇编代码的命令，因为IBM PC（Linux0.11的宿主）一上电时会首先执行在
# 16位模式（实模式）下，在setup模块执行完以后才会切换到32位模式（保护模式），因此bootsect.s
# 和setup.s这两个程序都必须用16位的汇编来编写，所以需要用AS86来汇编，LD86来链接。
AS86	=as86 -0 -a

#-0 表示链接8086目标程序
LD86	=ld86 -0

#gas（as）即GNU AS汇编器，32位，其属于AT&T风格，我们常用的GNU的产品还有GCC/G++
#nasm是linux平台下常用的汇编器，是intel风格的汇编器
#masm是windows平台下的汇编器，也使用intel风格，我们学的8086汇编时使用的就是masm汇编器
AS	=as

# gld（ld）是GNU的连接器
LD	=ld

#LDFLAGS是gld运行时用到的选项。
#-m elf_i386 表示模拟器是elf_i386
#-Ttext 0 表示把0作为 输出文件 的段起始地址
#-e startup_32 表示把startup_32作为程序执行的开始端
LDFLAGS	=-m elf_i386 -Ttext 0 -e startup_32

#gcc是GNU C程序编译器
#-march xxx表示机器位数，i386是Intel 80386，是32位处理器。对UNIX类的脚本语言而言，在引用定义的标识符时，格式为$(xxx)
CC	=gcc -mcpu=i386 $(RAMDISK)

#CFLAGS表示C编译器的选项
#-32 表示生成32位机器的汇编代码
#-g 表示在可执行程序中包含标准调试信息
#-Wall 表示打印所有警告信息
#-O2 表示控制优化代码的生成，2代表一个级别，相比于O1有额外调整工作，如处理器指令调度
CFLAGS	=-Wall -O2 -fomit-frame-pointer 

#cpp是gcc的预处理程序
#-nostdinc -Iinclude 表示不要搜索标准目录中的头文件，而是使用-I选项指定目录或在当前目录中搜索头文件
CPP	=cpp -nostdinc -Iinclude

#
# ROOT_DEV specifies the default root-device when making the image.
# This can be either FLOPPY, /dev/xxxx or empty, in which case the
# default of /dev/hd6 is used by 'build'.
#

#ROOT_DEV指定在创建内核映像image文件时默认根文件系统所在的设备，这可以是软盘（FLOPPY）、/dev/xxx或空着。
#空着时使用build程序的默认值/dev/hd6
ROOT_DEV= #FLOPPY 

#kernel、mm和fs目录所产生的目标代码文件，为方便引用，用ARCHIVES标识符表示。
#分别表示操作系统中的进程管理、内存管理和文件系统的目标文件。
ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o

#同理，DRIVERS表示块和字符设备库文件，.a表示该文件是个归档文件，即包含很多可执行二进制代码子程序的集合的库文件，
# 通常由ar程序生成。ar是GNU的二进制文件处理程序，用于创建、修改以及从归档文件中抽取文件。
DRIVERS =kernel/blk_drv/blk_drv.a kernel/chr_drv/chr_drv.a
#数学运算库文件
MATH	=kernel/math/math.a
LIBS	=lib/lib.a

#make老式的隐式后缀规则，表示 make利用下面命令将所有的.c文件编译成.s汇编程序。
.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<

#表示 将所有.s文件编译成.o目标文件
.s.o:
	$(AS)  -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<

#all由Image产生，这里显而易见all是文件树的最顶层
all:	Image

# Image由bootsect、setup、system、build 4个文件产生
Image: boot/bootsect boot/setup tools/system tools/build
	objcopy -O binary -R .note -R .comment tools/system tools/kernel

	# 使用build，将bootsect、setup、kernel以ROOT_DEV为根文件系统设备组成Image
	tools/build boot/bootsect boot/setup tools/kernel $(ROOT_DEV) > Image
	
	rm tools/kernel -f
	sync
#disk由Image产生
disk: Image
	dd bs=8192 if=Image of=/dev/fd0

#执行程序build由build.c产生
tools/build: tools/build.c
	$(CC) $(CFLAGS) \
	-o tools/build tools/build.c

#head.o由head.s产生
boot/head.o: boot/head.s
	gcc -I./include -traditional -c boot/head.s

	# 把head.o移动到boot/
	mv head.o boot/

#system由head.o、main.o、$(ARCHIVES)、$(DRIVERS)、$(MATH)、$(LIBS)生成
tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(DRIVERS) \
	$(MATH) \
	$(LIBS) \
	-o tools/system 
	#nm 表示列出.o文件、可执行文件、静态库和动态库的函数名
	#grep -v 表示只打印没有匹配后面通配符的
	#| 表示通过管道操作传递给sort
	#sort 表示将要打印的函数名排序，默认按照ASCII码
	#> System.map 表示gld需要将连接映像重定向保存在System.map文件中
	nm tools/system | grep -v '\(compiled\)\|\(\.o$$\)\|\( [aU] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)'| sort > System.map 

kernel/math/math.a:
	(cd kernel/math; make)

kernel/blk_drv/blk_drv.a:
	(cd kernel/blk_drv; make)

kernel/chr_drv/chr_drv.a:
	(cd kernel/chr_drv; make)

kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

boot/setup: boot/setup.s
	$(AS86) -o boot/setup.o boot/setup.s
	$(LD86) -s -o boot/setup boot/setup.o

boot/bootsect:	boot/bootsect.s
	$(AS86) -o boot/bootsect.o boot/bootsect.s
	$(LD86) -s -o boot/bootsect boot/bootsect.o

tmp.s:	boot/bootsect.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/bootsect.s >> tmp.s

clean:
	rm -f Image System.map tmp_make core boot/bootsect boot/setup
	rm -f init/*.o tools/system tools/build boot/*.o
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress16 - > backup.Z)
	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o: init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/signal.h include/asm/system.h \
  include/asm/io.h include/stddef.h include/stdarg.h include/fcntl.h
