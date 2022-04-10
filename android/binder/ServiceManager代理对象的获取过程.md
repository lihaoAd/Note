## 源码路径

```c
frameworks\base\include\utils\RefBase.h
frameworks\base\libs\utils\RefBase.cpp
frameworks\base\libs\binder\IInterface.cpp
frameworks\base\include\binder\IBinder.h   
frameworks\base\libs\binder\Binder.cpp
frameworks\base\include\binder\BpBinder.h
frameworks\base\include\binder\IServiceManager.h  
frameworks\base\libs\binder\IServiceManager.cpp   
```

![](img/Service Manager代理对象类图.jpg)



`client`获取Service Manager的代理对象可以使用`defaultServiceManager()`方法

frameworks\base\libs\binder\IServiceManager.cpp 

```c
sp<IServiceManager> defaultServiceManager()
{
    if (gDefaultServiceManager != NULL) return gDefaultServiceManager;
    {
        AutoMutex _l(gDefaultServiceManagerLock);
        if (gDefaultServiceManager == NULL) {
            gDefaultServiceManager = interface_cast<IServiceManager>(ProcessState::self()->getContextObject(NULL));
        }
    }
    
    return gDefaultServiceManager;
}
```



frameworks\base\libs\binder\ProcessState.cpp

```c
sp<ProcessState> ProcessState::self()
{
    if (gProcess != NULL) return gProcess;
    
    AutoMutex _l(gProcessMutex);
    if (gProcess == NULL) gProcess = new ProcessState;
    return gProcess;
}
```

`ProcessState`是每个进程一份，`client`进程调用`ProcessState::self()`就会打开binder设备，并将文件描述符放在`mDriverFD`中。如果一个进程使用`ProcessState`这个类来初始化`Binder`服务，这个进程的Binder内核内存上限就是`BINDER_VM_SIZE`，也就是`1MB-8KB`

能否不用ProcessState来初始化Binder服务，来突破1M-8KB的限制？

答案是当然可以了，Binder服务的初始化有两步，open打开Binder驱动，mmap在Binder驱动中申请内核空间内存，所以我们只要手写open，mmap就可以轻松突破这个限制。源码中已经给了类似的例子。

```c
// frameworks\base\cmds\servicemanager\bctest.c
int main(int argc, char **argv)
{
    int fd;
    struct binder_state *bs;
    void *svcmgr = BINDER_SERVICE_MANAGER;

    bs = binder_open(128*1024);

   ...
    return 0;
}
```

那么能否随便申请内存大小呢？

答案肯定是不能的，在Binder驱动中mmap的具体实现中还有一个4M的限制。

那么可以可以申请的内存是`1MB-8KB`到`4M`吗？

不是的，如果是异步的话是这个值的一半，具体我们到分析binder驱动时再讲



frameworks\base\libs\binder\ProcessState.cpp

```c
#define BINDER_VM_SIZE ((1*1024*1024) - (4096 *2))  // 1M - 8K

ProcessState::ProcessState()
    : mDriverFD(open_driver())
    , mVMStart(MAP_FAILED)
    ...
{
    if (mDriverFD >= 0) {
        // XXX Ideally, there should be a specific define for whether we
        // have mmap (or whether we could possibly have the kernel module
        // availabla).
#if !defined(HAVE_WIN32_IPC)
        // mmap the binder, providing a chunk of virtual address space to receive transactions.
        mVMStart = mmap(0, BINDER_VM_SIZE, PROT_READ, MAP_PRIVATE | MAP_NORESERVE, mDriverFD, 0);
        if (mVMStart == MAP_FAILED) {
            // *sigh*
            LOGE("Using /dev/binder failed: unable to mmap transaction memory.\n");
            close(mDriverFD);
            mDriverFD = -1;
        }
#else
        mDriverFD = -1;
#endif
    }
    if (mDriverFD < 0) {
        // Need to run without the driver, starting our own thread pool.
    }
}
```



```c
static int open_driver()
{
    if (gSingleProcess) {
        return -1;
    }

    // 会调用驱动的binder_open方法
    int fd = open("/dev/binder", O_RDWR);
    if (fd >= 0) {
        fcntl(fd, F_SETFD, FD_CLOEXEC);
        int vers;
#if defined(HAVE_ANDROID_OS)
        status_t result = ioctl(fd, BINDER_VERSION, &vers);
#else
        status_t result = -1;
        errno = EPERM;
#endif
        if (result == -1) {
            LOGE("Binder ioctl to obtain version failed: %s", strerror(errno));
            close(fd);
            fd = -1;
        }
        if (result != 0 || vers != BINDER_CURRENT_PROTOCOL_VERSION) {
            LOGE("Binder driver protocol does not match user space protocol!");
            close(fd);
            fd = -1;
        }
#if defined(HAVE_ANDROID_OS)
        // 告诉binder驱动，该client进程最多可以有15个binder线程
        size_t maxThreads = 15;
        result = ioctl(fd, BINDER_SET_MAX_THREADS, &maxThreads);
        if (result == -1) {
            LOGE("Binder ioctl to set max threads failed: %s", strerror(errno));
        }
#endif
        
    } else {
        LOGW("Opening '/dev/binder' failed: %s\n", strerror(errno));
    }
    return fd;
}
```

调用完`open_driver`后，会在内核中生成该进程的`binder_proc`结构，用来描述该进程，再执行`mmap`后，映射了设备，分配了内核缓冲区，缓冲区的起始地址放在`mVMStart`中。

```c
sp<IBinder> ProcessState::getContextObject(const sp<IBinder>& caller)
{
    if (supportsProcesses()) {
        // 支持binder设备
        return getStrongProxyForHandle(0);
    } else {
        return getContextObject(String16("default"), caller);
    }
}

bool ProcessState::supportsProcesses() const
{
    return mDriverFD >= 0;
}
```



设备是支持binder设备的，所以会执行`getStrongProxyForHandle(0)`。这个`0`是一个句柄值，因为service Manager对应的句柄就是`0`



```c
struct handle_entry {
      IBinder* binder; // Binder代理对象，即BpBinder
      RefBase::weakref_type* refs; // 内部的一个弱引用计数对象
  };
```



```c++
wp<IBinder> ProcessState::getWeakProxyForHandle(int32_t handle)
{
    wp<IBinder> result;

    AutoMutex _l(mLock);

    handle_entry* e = lookupHandleLocked(handle);s

    if (e != NULL) {        
        // We need to create a new BpBinder if there isn't currently one, OR we
        // are unable to acquire a weak reference on this current one.  The
        // attemptIncWeak() is safe because we know the BpBinder destructor will always
        // call expungeHandle(), which acquires the same lock we are holding now.
        // We need to do this because there is a race condition between someone
        // releasing a reference on this BpBinder, and a new reference on its handle
        // arriving from the driver.
        IBinder* b = e->binder;
        if (b == NULL || !e->refs->attemptIncWeak(this)) {
            b = new BpBinder(handle);
            result = b;
            e->binder = b;
            if (b) e->refs = b->getWeakRefs();
        } else {
            result = b;
            e->refs->decWeak(this);
        }
    }

    return result;
}

ProcessState::handle_entry* ProcessState::lookupHandleLocked(int32_t handle)
{
    const size_t N=mHandleToObject.size();
    if (N <= (size_t)handle) {
        handle_entry e;
        e.binder = NULL;
        e.refs = NULL;
        status_t err = mHandleToObject.insertAt(e, N, handle+1-N);
        if (err < NO_ERROR) return NULL;
    }
    return &mHandleToObject.editItemAt(handle);
}
```

如果b为NULL，就会创建一个`BpBinder`,如果不为NULL，需要检查这个Binder代理对象是否还活着，即调用`attemptIncWeak`来尝试增加它的弱引用计数

frameworks\base\include\binder\ProcessState.h

```c++
Vector<handle_entry>mHandleToObject;
```



```c
ProcessState::handle_entry* ProcessState::lookupHandleLocked(int32_t handle)
{
    const size_t N=mHandleToObject.size();
    if (N <= (size_t)handle) {
        handle_entry e;
        e.binder = NULL;
        e.refs = NULL;
        status_t err = mHandleToObject.insertAt(e, N, handle+1-N);
        if (err < NO_ERROR) return NULL;
    }
    return &mHandleToObject.editItemAt(handle);
}
```

进程的binder代理对象都保存在`ProcessState`类的成员变量`mHandleToObject`中

![image-20220409113459503](./img/image-20220409113459503.png)



```c
template<typename INTERFACE>
inline sp<INTERFACE> interface_cast(const sp<IBinder>& obj)
{
    return INTERFACE::asInterface(obj);
}
```

```c
#define DECLARE_META_INTERFACE(INTERFACE)                               \
    static const android::String16 descriptor;                          \
    static android::sp<I##INTERFACE> asInterface(                       \
            const android::sp<android::IBinder>& obj);                  \
    virtual const android::String16& getInterfaceDescriptor() const;    \
    I##INTERFACE();                                                     \
    virtual ~I##INTERFACE();                                            \
```



```c
DECLARE_META_INTERFACE(ServiceManager);
```

展开就是

```c
static const android::String16 descriptor;
static android::sp<IServiceManager> asInterface(const android::sp<android::IBinder>& obj);
virtual const android::String16& getInterfaceDescriptor() const;
IServiceManager(); 
virtual ~IServiceManager();
```



```c
IMPLEMENT_META_INTERFACE(ServiceManager, "android.os.IServiceManager");
```

```c
#define IMPLEMENT_META_INTERFACE(INTERFACE, NAME)                       \
    const android::String16 I##INTERFACE::descriptor(NAME);             \
    const android::String16&                                            \
            I##INTERFACE::getInterfaceDescriptor() const {              \
        return I##INTERFACE::descriptor;                                \
    }                                                                   \
    android::sp<I##INTERFACE> I##INTERFACE::asInterface(                \
            const android::sp<android::IBinder>& obj)                   \
    {                                                                   \
        android::sp<I##INTERFACE> intr;                                 \
        if (obj != NULL) {                                              \
            intr = static_cast<I##INTERFACE*>(                          \
                obj->queryLocalInterface(                               \
                        I##INTERFACE::descriptor).get());               \
            if (intr == NULL) {                                         \
                intr = new Bp##INTERFACE(obj);                          \
            }                                                           \
        }                                                               \
        return intr;                                                    \
    }                                                                   \
    I##INTERFACE::I##INTERFACE() { }                                    \
    I##INTERFACE::~I##INTERFACE() { }                                   \
```

```c
const android::String16 IServiceManager:descriptor("android.os.IServiceManager");            
const android::String16& IServiceManager::getInterfaceDescriptor() const 
{              
    return IServiceManager::descriptor;                                
}                                                                   
android::sp<IServiceManager> IServiceManager::asInterface(const android::sp<android::IBinder>& obj)                   
{   
    	// obj就是BpBinder
        android::sp<IServiceManager> intr;                                 
        if (obj != NULL) {                                              
            intr = static_cast<IServiceManager*>(obj->queryLocalInterface(IServiceManager::descriptor).get());               
            if (intr == NULL) {                                         
                intr = new BpServiceManager(obj);                          
            }                                                           
        }                                                               
        return intr;                                                    
    }                                                                   
IServiceManager::IServiceManager() { }                                    
IServiceManager::~IServiceManager() { }                                   
```



frameworks\base\include\binder\BpBinder.h

```c++
class BpBinder : public IBinder
{
....
}
```



frameworks\base\libs\binder\Binder.cpp

```c++
sp<IInterface>  IBinder::queryLocalInterface(const String16& descriptor)
{
    return NULL;
}
```

`BpBinder`的`queryLocalInterface`返方法返返回的是NULL，那么`asInterface`返回的就是`BpServiceManager`



