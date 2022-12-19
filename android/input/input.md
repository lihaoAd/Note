## InputManager初始化

frameworks/base/services/java/com/android/server/WindowManagerService.java

```java
public class WindowManagerService extends IWindowManager.Stub
        implements Watchdog.Monitor {
        
    ....
        
        
    public static WindowManagerService main(Context context,
            PowerManagerService pm, boolean haveInputMethods) {
        WMThread thr = new WMThread(context, pm, haveInputMethods);
        thr.start();

        synchronized (thr) {
            while (thr.mService == null) {
                try {
                    thr.wait();
                } catch (InterruptedException e) {
                }
            }
        }

        return thr.mService;
    }
    
    // WindowManagerService原来在WMThread线程中启动
    static class WMThread extends Thread {
        WindowManagerService mService;

        private final Context mContext;
        private final PowerManagerService mPM;
        private final boolean mHaveInputMethods;

        public WMThread(Context context, PowerManagerService pm,
                boolean haveInputMethods) {
            super("WindowManager");
            mContext = context;
            mPM = pm;
            mHaveInputMethods = haveInputMethods;
        }

        public void run() {
            Looper.prepare();
            WindowManagerService s = new WindowManagerService(mContext, mPM,
                    mHaveInputMethods);
            android.os.Process.setThreadPriority(
                    android.os.Process.THREAD_PRIORITY_DISPLAY);
            android.os.Process.setCanSelfBackground(false);

            synchronized (this) {
                mService = s;
                notifyAll();
            }

            Looper.loop();
        }
    }
    .....
}       
```

接下来看看`WindowManagerService`的构造函数，在构造函数中初始化`InputManager`

frameworks/base/services/java/com/android/server/WindowManagerService.java

```java
public class WindowManagerService extends IWindowManager.Stub
        implements Watchdog.Monitor {
        
	.....
    final InputManager mInputManager;
    .....
        
    private WindowManagerService(Context context, PowerManagerService pm,
            boolean haveInputMethods) {
       .....

        mInputManager = new InputManager(context, this);

        ....

        mInputManager.start();

        ....
    }    

    .....
}
```

## InputManager

frameworks/base/services/java/com/android/server/InputManager.java

```java
public class InputManager {

    ...
        
   public InputManager(Context context, WindowManagerService windowManagerService) {
        this.mContext = context;
        this.mWindowManagerService = windowManagerService;
        
        this.mCallbacks = new Callbacks();
        
        init();
    }
    
    private void init() {
        Slog.i(TAG, "Initializing input manager");
        nativeInit(mCallbacks);
    }
    
    public void start() {
        Slog.i(TAG, "Starting input manager");
        nativeStart();
    }
    
    ....
}
```

`InputManager`的构造函数中调用了`nativeInit`，就在C++层中创建了一个`NativeInputManager`



## NativeInputManager

frameworks/base/services/jni/com_android_server_InputManager.cpp

```c++
.....
    
static sp<NativeInputManager> gNativeInputManager;

static void android_server_InputManager_nativeInit(JNIEnv* env, jclass clazz,
        jobject callbacks) {
    if (gNativeInputManager == NULL) {
        gNativeInputManager = new NativeInputManager(callbacks);
    } else {
        LOGE("Input manager already initialized.");
        jniThrowRuntimeException(env, "Input manager already initialized.");
    }
}
...
```

创建一个全局的`gNativeInputManager`保存起来，接下来看看C++层`NativeInputManager`的构造函数

```c++
NativeInputManager::NativeInputManager(jobject callbacksObj) :
    mFilterTouchEvents(-1), mFilterJumpyTouchEvents(-1),
    mMaxEventsPerSecond(-1),
    mDisplayWidth(-1), mDisplayHeight(-1), mDisplayOrientation(ROTATION_0) {
    JNIEnv* env = jniEnv();

    mCallbacksObj = env->NewGlobalRef(callbacksObj);

    sp<EventHub> eventHub = new EventHub();
    mInputManager = new InputManager(eventHub, this, this);
}
```

创建了一个`EventHub`对象，接着创建C++层的`InputManager`对象，并将`EventHub`对象传递进去。

frameworks/base/libs/ui/InputManager.cpp

```c++
InputManager::InputManager(
        const sp<EventHubInterface>& eventHub,
        const sp<InputReaderPolicyInterface>& readerPolicy,
        const sp<InputDispatcherPolicyInterface>& dispatcherPolicy) {
    mDispatcher = new InputDispatcher(dispatcherPolicy);
    mReader = new InputReader(eventHub, readerPolicy, mDispatcher);
    initialize();
}
```

创建`InputDispatcher`和`InputReader`对象。

```c++
void InputManager::initialize() {
    mReaderThread = new InputReaderThread(mReader);
    mDispatcherThread = new InputDispatcherThread(mDispatcher);
}
```

frameworks/base/include/ui/InputDispatcher.h

```c++
/* Enqueues and dispatches input events, endlessly. */
class InputDispatcherThread : public Thread {
public:
    explicit InputDispatcherThread(const sp<InputDispatcherInterface>& dispatcher);
    ~InputDispatcherThread();

private:
    virtual bool threadLoop();

    sp<InputDispatcherInterface> mDispatcher;
};
```

需要覆写`threadLoop()`方法



frameworks/base/libs/ui/InputManager.cpp

```c++
InputDispatcherThread::InputDispatcherThread(const sp<InputDispatcherInterface>& dispatcher) :
        Thread(/*canCallJava*/ true), mDispatcher(dispatcher) {
}

InputDispatcherThread::~InputDispatcherThread() {
}

bool InputDispatcherThread::threadLoop() {
    mDispatcher->dispatchOnce();
    return true;
}
```

至此java层中的`InputManager`，以及C++层中的`InputManager`的创建过程就分析完成了，接下来分析它们的启动过程是。

## InputManager启动

frameworks/base/services/java/com/android/server/WindowManagerService.java

```c++
public class WindowManagerService extends IWindowManager.Stub
        implements Watchdog.Monitor {
        
	.....
    final InputManager mInputManager;
    .....
        
    private WindowManagerService(Context context, PowerManagerService pm,
            boolean haveInputMethods) {
       .....

        mInputManager = new InputManager(context, this);

        ....

        // 启动
        mInputManager.start();

        ....
    }    

    .....
}
```



frameworks/base/services/java/com/android/server/InputManager.java

```c++
public class InputManager {

    ...
    
    public void start() {
        Slog.i(TAG, "Starting input manager");
        nativeStart();
    }
    
    ....
}
```

最后调用的还是`nativeStart()`



frameworks/base/services/jni/com_android_server_InputManager.cpp

```c++
static void android_server_InputManager_nativeStart(JNIEnv* env, jclass clazz) {
    ...
    status_t result = gNativeInputManager->getInputManager()->start();
    if (result) {
        jniThrowRuntimeException(env, "Input manager could not be started.");
    }
}
```



frameworks/base/libs/ui/InputManager.cpp

```c++
status_t InputManager::start() {
    status_t result = mDispatcherThread->run("InputDispatcher", PRIORITY_URGENT_DISPLAY);
    if (result) {
        LOGE("Could not start InputDispatcher thread due to error %d.", result);
        return result;
    }

    result = mReaderThread->run("InputReader", PRIORITY_URGENT_DISPLAY);
    if (result) {
        LOGE("Could not start InputReader thread due to error %d.", result);

        mDispatcherThread->requestExit();
        return result;
    }

    return OK;
}
```

`InputManager`类成员变量`mDispatcherThread`、`mReaderThread`的类型分别是`InputDispatcherThread`和`InputReaderThread`,它们分别用来描述一个线程，调用run方法，就会创建一个线程，并且调用`threadLoop()`，作为线程的入口函数。

## InputDispatcher启动

frameworks/base/libs/ui/InputDispatcher.cpp

```c++
bool InputDispatcherThread::threadLoop() {
    mDispatcher->dispatchOnce();
    return true;
}
```



frameworks/base/libs/ui/InputDispatcher.cpp

```c++
void InputDispatcher::dispatchOnce() {
    // 键盘事件的分发策略
    // 时间单位纳秒
    nsecs_t keyRepeatTimeout = mPolicy->getKeyRepeatTimeout();
    nsecs_t keyRepeatDelay = mPolicy->getKeyRepeatDelay();

    nsecs_t nextWakeupTime = LONG_LONG_MAX;
    { // acquire lock
        AutoMutex _l(mLock);
        dispatchOnceInnerLocked(keyRepeatTimeout, keyRepeatDelay, & nextWakeupTime);

        if (runCommandsLockedInterruptible()) {
            nextWakeupTime = LONG_LONG_MIN;  // force next poll to wake up immediately
        }
    } // release lock

    // Wait for callback or timeout or wake.  (make sure we round up, not down)
    nsecs_t currentTime = now();
    int32_t timeoutMillis;
    if (nextWakeupTime > currentTime) {
        uint64_t timeout = uint64_t(nextWakeupTime - currentTime);
        timeout = (timeout + 999999LL) / 1000000LL;
        timeoutMillis = timeout > INT_MAX ? -1 : int32_t(timeout);
    } else {
        timeoutMillis = 0;
    }

    // 等待事件
    mLooper->pollOnce(timeoutMillis);
}
```

`InputDispatcher`处于睡眠等待状态期间，如果系统发生了键盘事件，那么`InputReader`就会提前将`InputDispatcher`唤醒。

## InputReader启动

`InputReader`是在一个`InputReaderThread`线程中启动的。

frameworks/base/libs/ui/InputReader.cpp

```c++
bool InputReaderThread::threadLoop() {
    mReader->loopOnce();
    return true;
}
```



frameworks/base/libs/ui/InputReader.cpp

```c++
void InputReader::loopOnce() {
    RawEvent rawEvent;
    // 获取事件
    mEventHub->getEvent(& rawEvent);

	...

    // 处理事件
    process(& rawEvent);
}
```

frameworks/base/libs/ui/EventHub.cpp

```c++
bool EventHub::getEvent(RawEvent* outEvent)
{
    // 初始化
    outEvent->deviceId = 0;
    outEvent->type = 0;
    outEvent->scanCode = 0;
    outEvent->keyCode = 0;
    outEvent->flags = 0;
    outEvent->value = 0;
    outEvent->when = 0;
    
     if (!mOpened) {
        // 打开系统的输入设备
        mError = openPlatformInput() ? NO_ERROR : UNKNOWN_ERROR;
        mOpened = true;
        mNeedToSendFinishedDeviceScan = true;
    }
    
    for (;;) {

        ....
            
           // Grab the next input event.
        for (;;) {
            // Consume buffered input events, if any.
            if (mInputBufferIndex < mInputBufferCount) {
                const struct input_event& iev = mInputBufferData[mInputBufferIndex++];
                const device_t* device = mDevices[mInputDeviceIndex];

                LOGV("%s got: t0=%d, t1=%d, type=%d, code=%d, v=%d", device->path.string(),
                     (int) iev.time.tv_sec, (int) iev.time.tv_usec, iev.type, iev.code, iev.value);
                if (device->id == mFirstKeyboardId) {
                    outEvent->deviceId = 0;
                } else {
                    outEvent->deviceId = device->id;
                }
                outEvent->type = iev.type;
                outEvent->scanCode = iev.code;
                if (iev.type == EV_KEY) {
                    status_t err = device->layoutMap->map(iev.code,
                            & outEvent->keyCode, & outEvent->flags);
                    LOGV("iev.code=%d keyCode=%d flags=0x%08x err=%d\n",
                        iev.code, outEvent->keyCode, outEvent->flags, err);
                    if (err != 0) {
                        outEvent->keyCode = AKEYCODE_UNKNOWN;
                        outEvent->flags = 0;
                    }
                } else {
                    outEvent->keyCode = iev.code;
                }
                outEvent->value = iev.value;

                // Use an event timestamp in the same timebase as
                // java.lang.System.nanoTime() and android.os.SystemClock.uptimeMillis()
                // as expected by the rest of the system.
                outEvent->when = systemTime(SYSTEM_TIME_MONOTONIC);
                return true;
            }
            
    ....
}    
```

