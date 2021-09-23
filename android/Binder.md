## Binder 驱动

`goldfish/drivers/staging/android/binder.c`

`goldfish/drivers/staging/android/binder.h`

### 基本数据结构



```c
// goldfish/drivers/staging/android/binder.c

struct binder_work {
	struct list_head entry;
	enum {
		BINDER_WORK_TRANSACTION = 1,
		BINDER_WORK_TRANSACTION_COMPLETE,
		BINDER_WORK_NODE,
		BINDER_WORK_DEAD_BINDER,
		BINDER_WORK_DEAD_BINDER_AND_CLEAR,
		BINDER_WORK_CLEAR_DEATH_NOTIFICATION,
	} type;
};
```

`binder_work`用来描述待处理的工作项，这些工作项有可能属于一个进程，也有会可能属于一个进程中的某一个线程。成员变量`entry`用来将结构体嵌入到一个宿主结构中，成员变量`type`用来描述工作的类型。

```c
// goldfish/drivers/staging/android/binder.c

struct binder_node {
	int debug_id;
	struct binder_work work;
	union {
		struct rb_node rb_node;
		struct hlist_node dead_node;
	};
	struct binder_proc *proc;
	struct hlist_head refs;
	int internal_strong_refs;
	int local_weak_refs;
	int local_strong_refs;
	void __user *ptr;
	void __user *cookie;
	unsigned has_strong_ref : 1;
	unsigned pending_strong_ref : 1;
	unsigned has_weak_ref : 1;
	unsigned pending_weak_ref : 1;
	unsigned has_async_transaction : 1;
	unsigned accept_fds : 1;
	int min_priority : 8;
	struct list_head async_todo;
};
```

`binder_node`用来描述一个Binder实体对象。每一个Service组件在Binder驱动中都有对应的一个实体Binder实体对象，用来描述它在内核中的状态。Binder驱动通过强引用和弱引用计数技术来维护它们的生命周期。

成员变量`proc`指向一个Binder实体对象的宿主进程。









































## main_mediaserver

**frameworks/av/media/mediaserver/main_mediaserver.cpp**

```c++
  		sp<ProcessState> proc(ProcessState::self());
        sp<IServiceManager> sm = defaultServiceManager();
        ALOGI("ServiceManager: %p", sm.get());
        AudioFlinger::instantiate();
        MediaPlayerService::instantiate();
        CameraService::instantiate();
        AudioPolicyService::instantiate();
        registerExtensions();
        ProcessState::self()->startThreadPool();
        IPCThreadState::self()->joinThreadPool();
```

```c++
class ProcessState : public virtual RefBase
```



**frameworks\native\include\private\binder\Static.h**

````c++
namespace android {

// For TextStream.cpp
extern Vector<int32_t> gTextBuffers;

// For ProcessState.cpp
extern Mutex gProcessMutex;
extern sp<ProcessState> gProcess;

// For ServiceManager.cpp
extern Mutex gDefaultServiceManagerLock;
extern sp<IServiceManager> gDefaultServiceManager;
extern sp<IPermissionController> gPermissionController;

} 
````

```c++

sp<ProcessState> ProcessState::self()
{
    Mutex::Autolock _l(gProcessMutex);
    if (gProcess != NULL) {
        return gProcess;
    }
    gProcess = new ProcessState;
    return gProcess;
}
```

初始化ProcessState

````c++
ProcessState::ProcessState()
    : mDriverFD(open_driver()) // 拿到 /dev/binder这个文件描述符
    , mVMStart(MAP_FAILED)
    , mManagesContexts(false)
    , mBinderContextCheckFunc(NULL)
    , mBinderContextUserData(NULL)
    , mThreadPoolStarted(false)
    , mThreadPoolSeq(1)
{
    if (mDriverFD >= 0) {
        // XXX Ideally, there should be a specific define for whether we
        // have mmap (or whether we could possibly have the kernel module
        // availabla).
#if !defined(HAVE_WIN32_IPC)
        // mmap the binder, providing a chunk of virtual address space to receive transactions.
        // 内存映射，用于接收 Binder传递来的数据
        mVMStart = mmap(0, BINDER_VM_SIZE, PROT_READ, MAP_PRIVATE | MAP_NORESERVE, mDriverFD, 0);
        if (mVMStart == MAP_FAILED) {
            // *sigh*
            ALOGE("Using /dev/binder failed: unable to mmap transaction memory.\n");
            close(mDriverFD);
            mDriverFD = -1;
        }
#else
        mDriverFD = -1;
#endif
    }

    LOG_ALWAYS_FATAL_IF(mDriverFD < 0, "Binder driver could not be opened.  Terminating.");
}
````

```c++
static int open_driver()
{
    int fd = open("/dev/binder", O_RDWR);
    if (fd >= 0) {
        fcntl(fd, F_SETFD, FD_CLOEXEC);
        int vers;
        status_t result = ioctl(fd, BINDER_VERSION, &vers);
        if (result == -1) {
            ALOGE("Binder ioctl to obtain version failed: %s", strerror(errno));
            close(fd);
            fd = -1;
        }
        if (result != 0 || vers != BINDER_CURRENT_PROTOCOL_VERSION) {
            ALOGE("Binder driver protocol does not match user space protocol!");
            close(fd);
            fd = -1;
        }
        size_t maxThreads = 15;
        result = ioctl(fd, BINDER_SET_MAX_THREADS, &maxThreads);
        if (result == -1) {
            ALOGE("Binder ioctl to set max threads failed: %s", strerror(errno));
        }
    } else {
        ALOGW("Opening '/dev/binder' failed: %s\n", strerror(errno));
    }
    return fd;
}
```



###  sp<IServiceManager> sm = defaultServiceManager();

**frameworks/native/include/binder/IServiceManager.h**

````c++
class IServiceManager : public IInterface
````

**frameworks/native/libs/binder/IServiceManager.cpp**

````c++
sp<IServiceManager> defaultServiceManager()
{
    if (gDefaultServiceManager != NULL) return gDefaultServiceManager;
    
    {
        AutoMutex _l(gDefaultServiceManagerLock);
        while (gDefaultServiceManager == NULL) {
            gDefaultServiceManager = interface_cast<IServiceManager>(
                ProcessState::self()->getContextObject(NULL));
            if (gDefaultServiceManager == NULL)
                sleep(1);
        }
    }
    
    return gDefaultServiceManager;
}
````

````c++
// 注意上面传递来的 caller 是一个NULL，也就是0，这个0后面有用
sp<IBinder> ProcessState::getContextObject(const sp<IBinder>& caller)
{
    return getStrongProxyForHandle(0);
}
````



````c++
sp<IBinder> ProcessState::getStrongProxyForHandle(int32_t handle)
{
    sp<IBinder> result;

    AutoMutex _l(mLock);

    handle_entry* e = lookupHandleLocked(handle);

    if (e != NULL) {
        // We need to create a new BpBinder if there isn't currently one, OR we
        // are unable to acquire a weak reference on this current one.  See comment
        // in getWeakProxyForHandle() for more info about this.
        IBinder* b = e->binder;
        if (b == NULL || !e->refs->attemptIncWeak(this)) {
            if (handle == 0) {
                // Special case for context manager...
                // The context manager is the only object for which we create
                // a BpBinder proxy without already holding a reference.
                // Perform a dummy transaction to ensure the context manager
                // is registered before we create the first local reference
                // to it (which will occur when creating the BpBinder).
                // If a local reference is created for the BpBinder when the
                // context manager is not present, the driver will fail to
                // provide a reference to the context manager, but the
                // driver API does not return status.
                //
                // Note that this is not race-free if the context manager
                // dies while this code runs.
                //
                // TODO: add a driver API to wait for context manager, or
                // stop special casing handle 0 for context manager and add
                // a driver API to get a handle to the context manager with
                // proper reference counting.

                Parcel data;
                status_t status = IPCThreadState::self()->transact(
                        0, IBinder::PING_TRANSACTION, data, NULL, 0);
                if (status == DEAD_OBJECT)
                   return NULL;
            }

            // 注意这个 handle 是 0 
            b = new BpBinder(handle); 
            e->binder = b;
            if (b) e->refs = b->getWeakRefs();
            result = b;
        } else {
            // This little bit of nastyness is to allow us to add a primary
            // reference to the remote proxy when this team doesn't have one
            // but another team is sending the handle to us.
            result.force_set(b);
            e->refs->decWeak(this);
        }
    }

    return result;
}
````



````c++
BpBinder::BpBinder(int32_t handle)
    : mHandle(handle) // 0
    , mAlive(1)
    , mObitsSent(0)
    , mObituaries(NULL)
{
    ALOGV("Creating BpBinder %p handle %d\n", this, mHandle);

    extendObjectLifetime(OBJECT_LIFETIME_WEAK);
    IPCThreadState::self()->incWeakHandle(handle);
}
````







````c++
class IInterface : public virtual RefBase
{
public:
            IInterface();
            sp<IBinder>         asBinder();
            sp<const IBinder>   asBinder() const;
            
protected:
    virtual                     ~IInterface();
    virtual IBinder*            onAsBinder() = 0;
};
````



`````c++
template<typename INTERFACE>
inline sp<INTERFACE> interface_cast(const sp<IBinder>& obj)
{
    return INTERFACE::asInterface(obj);
}
`````





````c++
class IServiceManager : public IInterface
{
public:
    DECLARE_META_INTERFACE(ServiceManager);
    
    ...
 }
````



````c++
#define DECLARE_META_INTERFACE(INTERFACE)                               \
    static const android::String16 descriptor;                          \
    static android::sp<I##INTERFACE> asInterface(                       \
            const android::sp<android::IBinder>& obj);                  \
    virtual const android::String16& getInterfaceDescriptor() const;    \
    I##INTERFACE();                                                     \
    virtual ~I##INTERFACE(); 
````

展开

```c++
static const android::String16 descriptor; 
static android::sp<IServiceManager> asInterface(const android::sp<android::IBinder>& obj);  
virtual const android::String16& getInterfaceDescriptor() const;
IServiceManager(); 
 virtual ~IServiceManager(); 
```

````c++
IMPLEMENT_META_INTERFACE(ServiceManager, "android.os.IServiceManager");
````



`````c++
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
    I##INTERFACE::~I##INTERFACE() { }  
`````

展开后

```c++
  const android::String16 ServiceManager::descriptor("android.os.IServiceManager");
  const android::String16& ServiceManager::getInterfaceDescriptor() const {              
        return ServiceManager::descriptor;                                
    }   

  android::sp<ServiceManager> ServiceManager::asInterface(const android::sp<android::IBinder>& obj){                                       
        android::sp<ServiceManager> intr;                                
        if (obj != NULL) {                                              
            intr = static_cast<ServiceManager>(obj->queryLocalInterface(ServiceManager::descriptor).get());               
            if (intr == NULL) {                                         
                intr = new BpServiceManager(obj);                          
            }                                                           
        }                                                               
        return intr;                                                    
    }  
```















