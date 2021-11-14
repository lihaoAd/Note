*init/main.c*

```(void) open("/dev/tty0",O_RDWR,0);```  

open()系统调用用于将一个文件名转换成一个文件描述符。当调用成功时，返回的文件描述符将是进程没有打开的最小数值的描述符。该调用创建一个新的打开文件，并不与任何其它进程共享。在执行exec 函数时，该新的文件描述符将始终保持着打开状态。文件的读写指针被设置在文件开始位置。

参数 flag 是 `0_RDONLY`、`O_WRONLY`、`O_RDWR` 之一，分别代表文件只读打开、只写打开和读写打开方式，可以与其它一些标志一起使用。

*lib/open.c*

```c
int open(const char * filename, int flag, ...)
{
	register int res;
	va_list arg;

	va_start(arg,flag);
	__asm__("int $0x80"
		:"=a" (res)
		:"0" (__NR_open),"b" (filename),"c" (flag),
		"d" (va_arg(arg,int)));
	if (res>=0)
		return res;
	errno = -res;
	return -1;
}
```





```c
// 打开（或创建）文件系统调用。
// 参数filename是文件名，flag是打开文件标志，它可取值：O_RDONLY（只读）、O_WRONLY
// （只写）或O_RDWR(读写)，以及O_EXCL（被创建文件必须不存在）、O_APPEND（在文件
// 尾添加数据）等其他一些标志的组合。如果本调用创建了一个新文件，则mode就用于指
// 定文件的许可属性。这些属性有S_IRWXU（文件宿主具有读、写和执行权限）、S_IRUSR
// （用户具有读文件权限）、S_IRWXG（组成员具有读、写和执行权限）等等。对于新创
// 建的文件，这些属性只应用与将来对文件的访问，创建了只读文件的打开调用也将返回
// 一个可读写的文件句柄。如果调用操作成功，则返回文件句柄(文件描述符)，否则返回出错码。
int sys_open(const char * filename,int flag,int mode)
{
	struct m_inode * inode;
	struct file * f;
	int i,fd;

    // 首先对参数进行处理。将用户设置的文件模式和屏蔽码相与，产生许可的文件模式。
    // 为了为打开文件建立一个文件句柄，需要搜索进程结构中文件结构指针数组，以查
    // 找一个空闲项。空闲项的索引号fd即是文件句柄值。若已经没有空闲项，则返回出错码。
    // 注意：0777是八进制数
	mode &= 0777 & ~current->umask;
	for(fd=0 ; fd<NR_OPEN ; fd++)
		if (!current->filp[fd])
			break;
	if (fd>=NR_OPEN)
		return -EINVAL;
    
    // 然后我们设置当前进程的执行时关闭文件句柄(close_on_exec)位图，复位对应的
    // bit位。close_on_exec是一个进程所有文件句柄的bit标志。每个bit位代表一个打
    // 开着的文件描述符，用于确定在调用系统调用execve()时需要关闭的文件句柄。当
    // 程序使用fork()函数创建了一个子进程时，通常会在该子进程中调用execve()函数
    // 加载执行另一个新程序。此时子进程中开始执行新程序。若一个文件句柄在close_on_exec
    // 中的对应bit位被置位，那么在执行execve()时应对应文件句柄将被关闭，否则该
    // 文件句柄将始终处于打开状态。当打开一个文件时，默认情况下文件句柄在子进程
    // 中也处于打开状态。因此这里要复位对应bit位。
	current->close_on_exec &= ~(1<<fd);
    // 然后为打开文件在文件表中寻找一个空闲结构项。我们令f指向文件表数组开始处。
    // 搜索空闲文件结构项(引用计数为0的项)，若已经没有空闲文件表结构项，则返回
    // 出错码。
	f=0+file_table;
	for (i=0 ; i<NR_FILE ; i++,f++)
		if (!f->f_count) break;
	if (i>=NR_FILE)
		return -EINVAL;
    // 此时我们让进程对应文件句柄fd的文件结构指针指向搜索到的文件结构，并令文件
    // 引用计数递增1。然后调用函数open_namei()执行打开操作，若返回值小于0，则说
    // 明出错，于是释放刚申请到的文件结构，返回出错码i。若文件打开操作成功，则
    // inode是已打开文件的i节点指针。
	(current->filp[fd]=f)->f_count++;
	if ((i=open_namei(filename,flag,mode,&inode))<0) {
		current->filp[fd]=NULL;
		f->f_count=0;
		return i;
	}
    // 根据已打开文件的i节点的属性字段，我们可以知道文件的具体类型。对于不同类
    // 型的文件，我们需要操作一些特别的处理。如果打开的是字符设备文件，那么对于
    // 主设备号是4的字符文件(例如/dev/tty0)，如果当前进程是组首领并且当前进程的
    // tty字段小于0(没有终端)，则设置当前进程的tty号为该i节点的子设备号，并设置
    // 当前进程tty对应的tty表项的父进程组号等于当前进程的进程组号。表示为该进程
    // 组（会话期）分配控制终端。对于主设备号是5的字符文件(/dev/tty)，若当前进
    // 程没有tty，则说明出错，于是放回i节点和申请到的文件结构，返回出错码(无许可)。
/* ttys are somewhat special (ttyxx major==4, tty major==5) */
	if (S_ISCHR(inode->i_mode)) {
		if (MAJOR(inode->i_zone[0])==4) {
			if (current->leader && current->tty<0) {
				current->tty = MINOR(inode->i_zone[0]);
				tty_table[current->tty].pgrp = current->pgrp;
			}
		} else if (MAJOR(inode->i_zone[0])==5)
			if (current->tty<0) {
				iput(inode);
				current->filp[fd]=NULL;
				f->f_count=0;
				return -EPERM;
			}
	}
/* Likewise with block-devices: check for floppy_change */
    // 如果打开的是块设备文件，则检查盘片是否更换过。若更换过则需要让高速缓冲区
    // 中该设备的所有缓冲块失败。
	if (S_ISBLK(inode->i_mode))
		check_disk_change(inode->i_zone[0]);
    // 现在我们初始化打开文件的文件结构。设置文件结构属性和标志，置句柄引用计数
    // 为1，并设置i节点字段为打开文件的i节点，初始化文件读写指针为0.最后返回文
    // 件句柄号。
	f->f_mode = inode->i_mode;
	f->f_flags = flag;
	f->f_count = 1;
	f->f_inode = inode;
	f->f_pos = 0;
	return (fd);
}
```

![image-20211013225533796](img/image-20211013225533796.png)



*fs/namei.c*

```c
// 文件打开namei函数。
// 参数filename是文件名，flag是打开文件标志，他可取值：O_RDONLY(只读)、O_WRONLY(只写)
// 或O_RDWR(读写)，以及O_CREAT(创建)、O_EXCL(被创建文件必须不存在)、O_APPEND(在文件尾
// 添加数据)等其他一些标志的组合。如果本调用创建了一个新文件，则mode就用于指定文件的
// 许可属性。这些属性有S_IRWXU(文件宿主具有读、写和执行权限)、S_IRUSR(用户具有读文件
// 权限)、S_IRWXG(组成员具有读、写和执行权限)等等。对于新创建的文件，这些属性只应用于
// 将来对文件的访问，创建了只读文件的打开调用也将返回一个可读写的文件句柄。
// 返回：成功返回0，否则返回出错码；res_inode - 返回对应文件路径名的i节点指针。
int open_namei(const char * pathname, int flag, int mode,struct m_inode ** res_inode)
{
	const char * basename;
	int inr,dev,namelen;
	struct m_inode * dir, *inode;
	struct buffer_head * bh;
	struct dir_entry * de;

    // 首先对函数参数进行合理的处理。如果文件访问模式标志是只读(0)，但是文件截零标志
    // O_TRUNC却置位了，则在文件打开标志中添加只写O_WRONLY。这样做的原因是由于截零标志
    // O_TRUNC必须在文件可写情况下才有效。然后使用当前进程的文件访问许可屏蔽码，屏蔽掉
    // 给定模式中的相应位，并添上对普通文件标志I_REGULAR。该标志将用于打开的文件不存在
    // 而需要创建文件时，作为新文件的默认属性。
	if ((flag & O_TRUNC) && !(flag & O_ACCMODE))
		flag |= O_WRONLY;
	mode &= 0777 & ~current->umask;
	mode |= I_REGULAR;
    // 然后根据指定的路径名寻找对应的i节点，以及最顶端目录名及其长度。此时如果最顶端目录
    // 名长度为0（例如'/usr/'这种路径名的情况），那么若操作不是读写、创建和文件长度截0，
    // 则表示是在打开一个目录名文件操作。于是直接返回该目录的i节点并返回0退出。否则说明
    // 进程操作非法，于是放回该i节点，返回出错码。
	if (!(dir = dir_namei(pathname,&namelen,&basename)))
		return -ENOENT;
	if (!namelen) {			/* special case: '/usr/' etc */
		if (!(flag & (O_ACCMODE|O_CREAT|O_TRUNC))) {
			*res_inode=dir;
			return 0;
		}
		iput(dir);
		return -EISDIR;
	}
    // 接着根据上面得到的最顶层目录名的i节点dir，在其中查找取得路径名字符串中最后的文件名
    // 对应的目录项结构de，并同时得到该目录项所在的高速缓冲区指针。如果该高速缓冲指针为NULL，
    // 则表示没有找到对应文件名的目录项，因此只可能是创建文件操作。此时如果不是创建文件，则
    // 放回该目录的i节点，返回出错号退出。如果用户在该目录没有写的权力，则放回该目录的i节点，
    // 返回出错号退出。
	bh = find_entry(&dir,basename,namelen,&de);
	if (!bh) {
		if (!(flag & O_CREAT)) {
			iput(dir);
			return -ENOENT;
		}
		if (!permission(dir,MAY_WRITE)) {
			iput(dir);
			return -EACCES;
		}
        // 现在我们确定了是创建操作并且有写操作许可。因此我们就在目录i节点对设备上申请一个
        // 新的i节点给路径名上指定的文件使用。若失败则放回目录的i节点，并返回没有空间出错码。
        // 否则使用该新i节点，对其进行初始设置：置节点的用户id；对应节点访问模式；置已修改
        // 标志。然后并在指定目录dir中添加一个新目录项。
		inode = new_inode(dir->i_dev);
		if (!inode) {
			iput(dir);
			return -ENOSPC;
		}
		inode->i_uid = current->euid;
		inode->i_mode = mode;
		inode->i_dirt = 1;
		bh = add_entry(dir,basename,namelen,&de);
        // 如果返回的应该含有新目录项的高速缓冲区指针为NULL，则表示添加目录项操作失败。于是
        // 将该新i节点的引用计数减1，放回该i节点与目录的i节点并返回出错码退出。否则说明添加
        // 目录项操作成功。于是我们来设置该新目录的一些初始值：置i节点号为新申请的i节点的号
        // 码；并置高速缓冲区已修改标志。然后释放该高速缓冲区，放回目录的i节点。返回新目录
        // 项的i节点指针，并成功退出。
		if (!bh) {
			inode->i_nlinks--;
			iput(inode);
			iput(dir);
			return -ENOSPC;
		}
		de->inode = inode->i_num;
		bh->b_dirt = 1;
		brelse(bh);
		iput(dir);
		*res_inode = inode;
		return 0;
	}
    // 若上面在目录中取文件名对应目录项结构的操作成功（即bh不为NULL），则说明指定打开的文件已
    // 经存在。于是取出该目录项的i节点号和其所在设备号，并释放该高速缓冲区以及放回目录的i节点
    // 如果此时堵在操作标志O_EXCL置位，但现在文件已经存在，则返回文件已存在出错码退出。
	inr = de->inode;
	dev = dir->i_dev;
	brelse(bh);
	iput(dir);
	if (flag & O_EXCL)
		return -EEXIST;
    // 然后我们读取该目录项的i节点内容。若该i节点是一个目录i节点并且访问模式是只写或读写，或者
    // 没有访问的许可权限，则放回该i节点，返回访问权限出错码退出。
	if (!(inode=iget(dev,inr)))
		return -EACCES;
	if ((S_ISDIR(inode->i_mode) && (flag & O_ACCMODE)) ||
	    !permission(inode,ACC_MODE(flag))) {
		iput(inode);
		return -EPERM;
	}
    // 接着我们更新该i节点的访问时间字段值为当前时间。如果设立了截0标志，则将该i节点的文件长度
    // 截0.最后返回该目录项i节点的指针，并返回0（成功）。
	inode->i_atime = CURRENT_TIME;
	if (flag & O_TRUNC)
		truncate(inode);
	*res_inode = inode;
	return 0;
}


// 参数：pathname - 目录路径名；namelen - 路径名长度；name - 返回的最顶层目录名。
// 返回：指定目录名最顶层目录的i节点指针和最顶层目录名称及长度。出错时返回NULL。
// 注意！！这里"最顶层目录"是指路径名中最靠近末端的目录。
static struct m_inode * dir_namei(const char * pathname,int * namelen, const char ** name)
{
	char c;
	const char * basename;
	struct m_inode * dir;

    // 首先取得指定路径名最顶层目录的i节点。然后对路径名Pathname 进行搜索检测，查出
    // 最后一个'/'字符后面的名字字符串，计算其长度，并且返回最顶层目录的i节点指针。
    // 注意！如果路径名最后一个字符是斜杠字符'/'，那么返回的目录名为空，并且长度为0.
    // 但返回的i节点指针仍然指向最后一个'/'字符钱目录名的i节点。
	if (!(dir = get_dir(pathname)))
		return NULL;
	basename = pathname;
	while ((c=get_fs_byte(pathname++)))
		if (c=='/')
			basename=pathname;
	*namelen = pathname-basename-1;
	*name = basename;
	return dir;
}

// 搜寻指定路径的目录（或文件名）的i节点。
// 参数：pathname - 路径名
// 返回：目录或文件的i节点指针。
static struct m_inode * get_dir(const char * pathname)
{
	char c;
	const char * thisname;
	struct m_inode * inode;
	struct buffer_head * bh;
	int namelen,inr,idev;
	struct dir_entry * de;

    // 搜索操作会从当前任务结构中设置的根（或伪根）i节点或当前工作目录i节点
    // 开始，因此首先需要判断进程的根i节点指针和当前工作目录i节点指针是否有效。
    // 如果当前进程没有设定根i节点，或者该进程根i节点指向是一个空闲i节点（引用为0），
    // 则系统出错停机。如果进程的当前工作目录i节点指针为空，或者该当前工作目录
    // 指向的i节点是一个空闲i节点，这也是系统有问题，停机。
	if (!current->root || !current->root->i_count)
		panic("No root inode");
	if (!current->pwd || !current->pwd->i_count)
		panic("No cwd inode");
    // 如果用户指定的路径名的第1个字符是'/'，则说明路径名是绝对路径名。则从
    // 根i节点开始操作，否则第一个字符是其他字符，则表示给定的相对路径名。
    // 应从进程的当前工作目录开始操作。则取进程当前工作目录的i节点。如果路径
    // 名为空，则出错返回NULL退出。此时变量inode指向了正确的i节点 -- 进程的
    // 根i节点或当前工作目录i节点之一。
	if ((c=get_fs_byte(pathname))=='/') {
		inode = current->root;
		pathname++;
	} else if (c)
		inode = current->pwd;
	else
		return NULL;	/* empty name is bad */
    // 然后针对路径名中的各个目录名部分和文件名进行循环出路，首先把得到的i节点
    // 引用计数增1，表示我们正在使用。在循环处理过程中，我们先要对当前正在处理
    // 的目录名部分（或文件名）的i节点进行有效性判断，并且把变量thisname指向
    // 当前正在处理的目录名部分（或文件名）。如果该i节点不是目录类型的i节点，
    // 或者没有可进入该目录的访问许可，则放回该i节点，并返回NULL退出。当然，刚
    // 进入循环时，当前的i节点就是进程根i节点或者是当前工作目录的i节点。
	inode->i_count++;
	while (1) {
		thisname = pathname;
		if (!S_ISDIR(inode->i_mode) || !permission(inode,MAY_EXEC)) {
			iput(inode);
			return NULL;
		}
        // 每次循环我们处理路径名中一个目录名（或文件名）部分。因此在每次循环中
        // 我们都要从路径名字符串中分离出一个目录名（或文件名）。方法是从当前路径名
        // 指针pathname开始处搜索检测字符，知道字符是一个结尾符（NULL）或者是一
        // 个'/'字符。此时变量namelen正好是当前处理目录名部分的长度，而变量thisname
        // 正指向该目录名部分的开始处。此时如果字符是结尾符NULL，则表明以及你敢搜索
        // 到路径名末尾，并已到达最后指定目录名或文件名，则返回该i节点指针退出。
        // 注意！如果路径名中最后一个名称也是一个目录名，但其后面没有加上'/'字符，
        // 则函数不会返回该最后目录的i节点！例如：对于路径名/usr/src/linux，该函数
        // 将只返回src/目录名的i节点。
		for(namelen=0;(c=get_fs_byte(pathname++))&&(c!='/');namelen++)
			/* nothing */ ;
		if (!c)
			return inode;
        // 在得到当前目录名部分（或文件名）后，我们调用查找目录项函数find_entry()在
        // 当前处理的目录中寻找指定名称的目录项。如果没有找到，则返回该i节点，并返回
        // NULL退出。然后在找到的目录项中取出其i节点号inr和设备号idev，释放包含该目录
        // 项的高速缓冲块并放回该i节点。然后去节点号inr的i节点inode，并以该目录项为
        // 当前目录继续循环处理路径名中的下一目录名部分（或文件名）。
		if (!(bh = find_entry(&inode,thisname,namelen,&de))) {
			iput(inode);
			return NULL;
		}
		inr = de->inode;                        // 当前目录名部分的i节点号
		idev = inode->i_dev;
		brelse(bh);
		iput(inode);
		if (!(inode = iget(idev,inr)))          // 取i节点内容。
			return NULL;
	}
}

// 查找指定目录和文件名的目录项。
// 参数：*dir - 指定目录i节点的指针；name - 文件名；namelen - 文件名长度；
// 该函数在指定目录的数据（文件）中搜索指定文件名的目录项。并对指定文件名
// 是'..'的情况根据当前进行的相关设置进行特殊处理。关于函数参数传递指针的指针
// 作用，请参见seched.c中的注释。
// 返回：成功则函数高速缓冲区指针，并在*res_dir处返回的目录项结构指针。失败则
// 返回空指针NULL。
static struct buffer_head * find_entry(struct m_inode ** dir,const char * name, int namelen, struct dir_entry ** res_dir)
{
	int entries;
	int block,i;
	struct buffer_head * bh;
	struct dir_entry * de;
	struct super_block * sb;

    // 同样，本函数一上来也需要对函数参数的有效性进行判断和验证。如果我们在前面
    // 定义了符号常数NO_TRUNCATE,那么如果文件名长度超过最大长度NAME_LEN，则不予
    // 处理。如果没有定义过NO_TRUNCATE，那么在文件名长度超过最大长度NAME_LEN时截短之。
#ifdef NO_TRUNCATE
	if (namelen > NAME_LEN)
		return NULL;
#else
	if (namelen > NAME_LEN)
		namelen = NAME_LEN;
#endif
    // 首先计算本目录中目录项项数entries。目录i节点i_size字段中含有本目录包含的数据
    // 长度，因此其除以一个目录项的长度（16字节）即课得到该目录中目录项数。然后置空
    // 返回目录项结构指针。如果长度等于0，则返回NULL，退出。
	entries = (*dir)->i_size / (sizeof (struct dir_entry));
	*res_dir = NULL;
	if (!namelen)
		return NULL;
    // 接下来我们对目录项文件名是'..'的情况进行特殊处理。如果当前进程指定的根i节点就是
    // 函数参数指定的目录，则说明对于本进程来说，这个目录就是它伪根目录，即进程只能访问
    // 该目录中的项而不能后退到其父目录中去。也即对于该进程本目录就如同是文件系统的根目录，
    // 因此我们需要将文件名修改为‘.’。
    // 否则，如果该目录的i节点号等于ROOT_INO（1号）的话，说明确实是文件系统的根i节点。
    // 则取文件系统的超级块。如果被安装到的i节点存在，则先放回原i节点，然后对被安装到
    // 的i节点进行处理。于是我们让*dir指向该被安装到的i节点；并且该i节点的引用数加1.
    // 即针对这种情况，我们悄悄的进行了“偷梁换柱”工程。:-)
/* check for '..', as we might have to do some "magic" for it */
	if (namelen==2 && get_fs_byte(name)=='.' && get_fs_byte(name+1)=='.') {
/* '..' in a pseudo-root results in a faked '.' (just change namelen) */
		if ((*dir) == current->root)
			namelen=1;
		else if ((*dir)->i_num == ROOT_INO) {
/* '..' over a mount-point results in 'dir' being exchanged for the mounted
   directory-inode. NOTE! We set mounted, so that we can iput the new dir */
			sb=get_super((*dir)->i_dev);
			if (sb->s_imount) {
				iput(*dir);
				(*dir)=sb->s_imount;
				(*dir)->i_count++;
			}
		}
	}
    // 现在我们开始正常操作，查找指定文件名的目录项在什么地方。因此我们需要读取目录的
    // 数据，即取出目录i节点对应块设备数据区中的数据块（逻辑块）信息。这些逻辑块的块号
    // 保存在i节点结构的i_zone[9]数组中。我们先取其中第一个块号。如果目录i节点指向的
    // 第一个直接磁盘块好为0，则说明该目录竟然不含数据，这不正常。于是返回NULL退出，
    // 否则我们就从节点所在设备读取指定的目录项数据块。当然，如果不成功，则也返回NULL 退出。
	if (!(block = (*dir)->i_zone[0]))
		return NULL;
	if (!(bh = bread((*dir)->i_dev,block)))
		return NULL;
    // 此时我们就在这个读取的目录i节点数据块中搜索匹配指定文件名的目录项。首先让de指向
    // 缓冲块中的数据块部分。并在不超过目录中目录项数的条件下，循环执行搜索。其中i是目录中
    // 的目录项索引号。在循环开始时初始化为0.
	i = 0;
	de = (struct dir_entry *) bh->b_data;
	while (i < entries) {
        // 如果当前目录项数据块已经搜索完，还没有找到匹配的目录项，则释放当前目录项数据块。
        // 再读入目录的下一个逻辑块。若这块为空。则只要还没有搜索完目录中的所有目录项，就
        // 跳过该块，继续读目录的下一逻辑块。若该块不空，就让de指向该数据块，然后在其中继续
        // 搜索。其中DIR_ENTRIES_PER_BLOCK可得到当前搜索的目录项所在目录文件中的块号，而bmap()
        // 函数则课计算出在设备上对应的逻辑块号.
		if ((char *)de >= BLOCK_SIZE+bh->b_data) {
			brelse(bh);
			bh = NULL;
			if (!(block = bmap(*dir,i/DIR_ENTRIES_PER_BLOCK)) ||
			    !(bh = bread((*dir)->i_dev,block))) {
				i += DIR_ENTRIES_PER_BLOCK;
				continue;
			}
			de = (struct dir_entry *) bh->b_data;
		}
        // 如果找到匹配的目录项的话，则返回该目录项结构指针de和该目录项i节点指针*dir以及该目录项
        // 数据块指针bh，并退出函数。否则继续在目录项数据块中比较下一个目录项。
		if (match(namelen,name,de)) {
			*res_dir = de;
			return bh;
		}
		de++;
		i++;
	}
    // 如果指定目录中的所有目录项都搜索完后，还没有找到相应的目录项，则释放目录的数据块，
    // 最后返回NULL（失败）。
	brelse(bh);
	return NULL;
}
```





```c
#define S_IFMT  00170000
#define S_IFDIR  0040000

#define S_ISDIR(m)	(((m) & S_IFMT) == S_IFDIR)

```

