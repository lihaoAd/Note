## 源码位置

```java
frameworks/base/libs/binder/ProcessState.cpp
frameworks/base/libs/binder/IServiceManager.cpp
frameworks/base/libs/binder/BpBinder.cpp
frameworks/base/libs/binder/IInterface.cpp
frameworks/base/libs/binder/Binder.cpp    
frameworks/base/libs/binder/IPCThreadState.cpp
frameworks/base/cmds/servicemanager/binder.c
frameworks/base/libs/binder/Static.cpp
frameworks/base/include/binder/IServiceManager.h    
  
frameworks/base/media/mediaserver/main_mediaserver.cpp   
frameworks/base/include/binder/IInterface.h
```

## MediaServer为例子

*main_mediaserver.cpp*

```c++
int main(int argc, char** argv)
{
    // 获取ProcessState单例，每个进程独一份
    sp<ProcessState> proc(ProcessState::self());
    
    // 获取 IServiceManager ，向ServiceManager注册服务
    sp<IServiceManager> sm = defaultServiceManager();
    LOGI("ServiceManager: %p", sm.get());
    
    // 初始化音频系统的AudioFlinger服务
    AudioFlinger::instantiate();
    
    //  MediaPlayer服务
    MediaPlayerService::instantiate();
    
    // CameraService 服务
    CameraService::instantiate();
    
    //  音频系统的AudioPolicyService服务
    AudioPolicyService::instantiate();
    
    ProcessState::self()->startThreadPool();
    
    IPCThreadState::self()->joinThreadPool();
}
```

## ProcessState

每个进程都有一份 ProcessState

```c++
sp<ProcessState> ProcessState::self()
{
    // gProcess 是Static.cpp中定义的一个全局变量
    // 程序刚开始运行，gProcess 一定为NULL
    if (gProcess != NULL) return gProcess;
    
    AutoMutex _l(gProcessMutex);
   
    // 创建一个ProcessState对象
    if (gProcess == NULL) gProcess = new ProcessState;
    return gProcess;
}
```



```c++
#define BINDER_VM_SIZE ((1*1024*1024) - (4096 *2))   // 1MB - 8KB


ProcessState::ProcessState()
    : mDriverFD(open_driver())
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



打开/dev/binder 设备，告诉Binder驱动,最大支持的线程数

```c++
static int open_driver()
{
    if (gSingleProcess) {
        return -1;
    }

    int fd = open("/dev/binder", O_RDWR); // 打开 /dev/binder 设备
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
        size_t maxThreads = 15;  // 告诉Binder驱动，这个fd最大支持15个线程
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

## defaultServiceManager

一个单例，重点是 interface_cast 

*IServiceManager.cpp*

```c++
sp<IServiceManager> defaultServiceManager()
{
    if (gDefaultServiceManager != NULL) return gDefaultServiceManager;
   
    {
        AutoMutex _l(gDefaultServiceManagerLock);
        if (gDefaultServiceManager == NULL) {
            gDefaultServiceManager = interface_cast<IServiceManager>(
                ProcessState::self()->getContextObject(NULL)); // 这个NULL的值就是0，0就代表ServerManager
        }
    }
    
    return gDefaultServiceManager;
}
```



*ProcessState.cpp*

```c++
sp<IBinder> ProcessState::getContextObject(const sp<IBinder>& caller)
{
    if (supportsProcesses()) {
        // 真实设备一定支持进程
        return getStrongProxyForHandle(0);
    } else {
        return getContextObject(String16("default"), caller);
    }
}
```



```c++
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
            b = new BpBinder(handle);   //创建一个BpBinder
            e->binder = b;   // 填充entry
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
```

经过上面，相当于

```c++
interface_cast<IServiceManager>(new BpBinder(NULL));
```

*BpBinder.cpp*

```c++
BpBinder::BpBinder(int32_t handle)
    : mHandle(handle)  // 上面我们传进来的是一个NULL，即 0
    , mAlive(1)
    , mObitsSent(0)
    , mObituaries(NULL)
{
    LOGV("Creating BpBinder %p handle %d\n", this, mHandle);

    extendObjectLifetime(OBJECT_LIFETIME_WEAK);
    
    // 注意，这里有个 IPCThreadState ，也很重要
    IPCThreadState::self()->incWeakHandle(handle);
}
```



## interface_cast

*IInterface.h*

```c++
template<typename INTERFACE>
inline sp<INTERFACE> interface_cast(const sp<IBinder>& obj)
{
    return INTERFACE::asInterface(obj);
}
```

interface_cast 仅仅是一个模板函数，所以

```c++
interface_cast<IServiceManager>(const sp<IBinder>& obj);
```

等价于

```c++
inline sp<IServiceManager> interface_cast(const sp<IBinder>& obj)
{
    return IServiceManager::asInterface(obj);
}
```

## IServiceManager

*IServiceManager.h*

```c++
class IServiceManager : public IInterface
{
public:
    
    // 一个关键无比的宏
    DECLARE_META_INTERFACE(ServiceManager);

    /**
     * Retrieve an existing service, blocking for a few seconds
     * if it doesn't yet exist.
     */
    virtual sp<IBinder>         getService( const String16& name) const = 0;

    /**
     * Retrieve an existing service, non-blocking.
     */
    virtual sp<IBinder>         checkService( const String16& name) const = 0;

    /**
     * Register a service.
     */
    virtual status_t            addService( const String16& name,
                                            const sp<IBinder>& service) = 0;

    /**
     * Return list of all existing services.
     */
    virtual Vector<String16>    listServices() = 0;

    enum {
        GET_SERVICE_TRANSACTION = IBinder::FIRST_CALL_TRANSACTION,
        CHECK_SERVICE_TRANSACTION,
        ADD_SERVICE_TRANSACTION,
        LIST_SERVICES_TRANSACTION,
    };
};

sp<IServiceManager> defaultServiceManager();

template<typename INTERFACE>
status_t getService(const String16& name, sp<INTERFACE>* outService)
{
    const sp<IServiceManager> sm = defaultServiceManager();
    if (sm != NULL) {
        *outService = interface_cast<INTERFACE>(sm->getService(name));
        if ((*outService) != NULL) return NO_ERROR;
    }
    return NAME_NOT_FOUND;
}

bool checkCallingPermission(const String16& permission);
bool checkCallingPermission(const String16& permission,
                            int32_t* outPid, int32_t* outUid);
bool checkPermission(const String16& permission, pid_t pid, uid_t uid);


// ----------------------------------------------------------------------

class BnServiceManager : public BnInterface<IServiceManager>
{
public:
    virtual status_t    onTransact( uint32_t code,
                                    const Parcel& data,
                                    Parcel* reply,
                                    uint32_t flags = 0);
};

// ----------------------------------------------------------------------

};
```

展开  DECLARE_META_INTERFACE(ServiceManager);

IInterface.h

```c++
#define DECLARE_META_INTERFACE(INTERFACE)                               \
    static const android::String16 descriptor;                          \
    static android::sp<I##INTERFACE> asInterface(                       \
            const android::sp<android::IBinder>& obj);                  \
    virtual const android::String16& getInterfaceDescriptor() const;    \
    I##INTERFACE();                                                     \
    virtual ~I##INTERFACE();  
```

等价于,就是在头文件中进行一些声明，在 IServiceManager.cpp 进行实现 IMPLEMENT_META_INTERFACE(ServiceManager, "android.os.IServiceManager");

```c++
 static const android::String16 descriptor;
 static android::sp<IServiceManager> asInterface(const android::sp<android::IBinder>& obj);
 virtual const android::String16& getInterfaceDescriptor() const;
 IServiceManager();  
 virtual ~IServiceManager();  
```



*IServiceManager.cpp*

```c++
IMPLEMENT_META_INTERFACE(ServiceManager, "android.os.IServiceManager");
```

IInterface.h

```c++
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
```

等价于

```c++
 const android::String16 IServiceManager::descriptor("android.os.IServiceManager");
 const android::String16& IServiceManager::getInterfaceDescriptor() const 
 {
     return IServiceManager::descriptor;  // android.os.IServiceManager                     
  }                                                
 
 android::sp<IServiceManager> IServiceManager::asInterface(const android::sp<android::IBinder>& obj)               
  {                                                                  
        android::sp<IServiceManager> intr;                                 
        if (obj != NULL) {                                              
            intr = static_cast<IServiceManager*>(obj->queryLocalInterface(IServiceManager::descriptor).get());               
            if (intr == NULL) {      
                // 注意这个obj还是从上面传下来的 new BpBinder(0)
                intr = new BpServiceManager(obj);                          
            }                                                           
        }                                                               
        return intr;                                                    
    }    

  IServiceManager::IServiceManager() { }                                    
  IServiceManager::~IServiceManager() { }
```

