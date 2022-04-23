## AMS的启动

frameworks\base\services\java\com\android\server\SystemServer.java

```java
// 调用ActivityManagerService.main设置context
context = ActivityManagerService.main(factoryTest);

// 这样system_server进程可加到AMS中，并被它管理
ActivityManagerService.setSystemProcess();

// 将SettingProvider放到system_server中运行
ActivityManagerService.installSystemProviders();

// 保存WMS
((ActivityManagerService)ServiceManager.getService("activity")).setWindowManager(wm);

```

`ActivityManagerService`的启动位于`SystemServer`中



## ActivityManagerService.main

### AThread



frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
    public static final Context main(int factoryTest) {
        AThread thr = new AThread();
        thr.start();

        // 等待AThread完成 ActivityManagerService 的创建
        synchronized (thr) {
            while (thr.mService == null) {
                try {
                    thr.wait();
                } catch (InterruptedException e) {
                }
            }
        }

        ActivityManagerService m = thr.mService;
        // 保存起来
        mSelf = m;
        
        ActivityThread at = ActivityThread.systemMain();
        mSystemThread = at;
        Context context = at.getSystemContext();
        m.mContext = context;
        m.mFactoryTest = factoryTest;
        m.mMainStack = new ActivityStack(m, context, true);
        
        m.mBatteryStatsService.publish(context);
        m.mUsageStatsService.publish(context);
        
        synchronized (thr) {
            thr.mReady = true;
            // 通知AThread
            thr.notifyAll();
        }

        m.startRunning(null, null, null, null);
        
        return context;
    }

    public static ActivityManagerService self() {
        return mSelf;
    }


    public static ActivityManagerService self() {
        return mSelf;
    }
```

虽然`ActivityManagerService`在`SystemServer`中的`ServerThread`中初始化，但是最后AMS自己的工作还是放在了自己的`AThread`线程中去做。



frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
static class AThread extends Thread {
        ActivityManagerService mService;
        boolean mReady = false;

        public AThread() {
            // 线程的名字叫ActivityManager
            super("ActivityManager");
        }

        public void run() {
            Looper.prepare();

            android.os.Process.setThreadPriority(
                    android.os.Process.THREAD_PRIORITY_FOREGROUND);
            android.os.Process.setCanSelfBackground(false);

            ActivityManagerService m = new ActivityManagerService();

            synchronized (this) {
                mService = m;
                // 通知前面的main函数所在的线程ActivityManagerService已经创造好了
                notifyAll();
            }

            synchronized (this) {
                // 等待前面的main函数完成后续的工作
                while (!mReady) {
                    try {
                        wait();
                    } catch (InterruptedException e) {
                    }
                }
            }

            Looper.loop();
        }
    }
```



frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
private ActivityManagerService() {
        String v = System.getenv("ANDROID_SIMPLE_PROCESS_MANAGEMENT");
        if (v != null && Integer.getInteger(v) != 0) {
            mSimpleProcessManagement = true;
        }
        v = System.getenv("ANDROID_DEBUG_APP");
        if (v != null) {
            mSimpleProcessManagement = true;
        }

        Slog.i(TAG, "Memory class: " + ActivityManager.staticGetMemoryClass());
        
    	// 指向/data/目录
        File dataDir = Environment.getDataDirectory();
    	// 指向/data/system目录
        File systemDir = new File(dataDir, "system");
        systemDir.mkdirs();
    
        mBatteryStatsService = new BatteryStatsService(new File(
                systemDir, "batterystats.bin").toString());
        mBatteryStatsService.getActiveStatistics().readLocked();
        mBatteryStatsService.getActiveStatistics().writeAsyncLocked();
        mOnBattery = DEBUG_POWER ? true
                : mBatteryStatsService.getActiveStatistics().getIsOnBattery();
        mBatteryStatsService.getActiveStatistics().setCallback(this);
        
        mUsageStatsService = new UsageStatsService(new File(
                systemDir, "usagestats").toString());

    	// 获取OpenGL版本
        GL_ES_VERSION = SystemProperties.getInt("ro.opengles.version",
            ConfigurationInfo.GL_ES_VERSION_UNDEFINED);

    	// 设置字体、语言等
        mConfiguration.setToDefaults();
        mConfiguration.locale = Locale.getDefault();
    	
    	// 用于统计信息
        mProcessStats.init();
        
        // Add ourself to the Watchdog monitors.
        Watchdog.getInstance().addMonitor(this);

    	// 定时更新系统信息
        mProcessStatsThread = new Thread("ProcessStats") {
            public void run() {
                while (true) {
                    try {
                        try {
                            synchronized(this) {
                                final long now = SystemClock.uptimeMillis();
                                long nextCpuDelay = (mLastCpuTime.get()+MONITOR_CPU_MAX_TIME)-now;
                                long nextWriteDelay = (mLastWriteTime+BATTERY_STATS_TIME)-now;
                                //Slog.i(TAG, "Cpu delay=" + nextCpuDelay
                                //        + ", write delay=" + nextWriteDelay);
                                if (nextWriteDelay < nextCpuDelay) {
                                    nextCpuDelay = nextWriteDelay;
                                }
                                if (nextCpuDelay > 0) {
                                    mProcessStatsMutexFree.set(true);
                                    this.wait(nextCpuDelay);
                                }
                            }
                        } catch (InterruptedException e) {
                        }
                        updateCpuStatsNow();
                    } catch (Exception e) {
                        Slog.e(TAG, "Unexpected exception collecting process stats", e);
                    }
                }
            }
        };
        mProcessStatsThread.start();
    }
```

### systemMain

frameworks\base\core\java\android\app\ActivityThread.java

```java
    public static final ActivityThread systemMain() {
        ActivityThread thread = new ActivityThread();
        thread.attach(true);
        return thread;
    }
```

`ActivityThread`代表应用程序（运行了apk的进程）的主线程，而system_server并非一个应用进程，那么为什么还需要`ActivityThread`?

- 在`PackageManagerService`中有framework-res.apk,这个apk除了一些资源外，还包含有一些activity（如关机对话框），而这些Activity实际是运行在system_server进程中，从这个角度看，system_server是一个特殊的应用进程
- 通过`ActivityThread`可以把Android系统提供的组件之间的交互机制和交互接口（如context提供的api）也扩展到system_server中。

frameworks\base\core\java\android\app\ActivityThread.java

```java
public final class ActivityThread {

	...
        
   private final void attach(boolean system) {
        sThreadLocal.set(this);
        
        // 是否是系统进程
        mSystemThread = system;
        if (!system) {
            // 应用进程处理逻辑
            ViewRoot.addFirstDrawHandler(new Runnable() {
                public void run() {
                    ensureJitEnabled();
                }
            });
            android.ddm.DdmHandleAppName.setAppName("<pre-initialized>");
            RuntimeInit.setApplicationObject(mAppThread.asBinder());
            IActivityManager mgr = ActivityManagerNative.getDefault();
            try {
                mgr.attachApplication(mAppThread);
            } catch (RemoteException ex) {
            }
        } else {
            // Don't set application object here -- if the system crashes,
            // we can't display an alert, we just want to die die die.
            android.ddm.DdmHandleAppName.setAppName("system_process");
            try {
                mInstrumentation = new Instrumentation();
                ContextImpl context = new ContextImpl();
                context.init(getSystemContext().mPackageInfo, null, this);
                Application app = Instrumentation.newApplication(Application.class, context);
                mAllApplications.add(app);
                mInitialApplication = app;
                app.onCreate();
            } catch (Exception e) {
                throw new RuntimeException(
                        "Unable to instantiate Application():" + e.toString(), e);
            }
        }
        
        // 注册Configuration变化回调
        ViewRoot.addConfigCallback(new ComponentCallbacks() {
            public void onConfigurationChanged(Configuration newConfig) {
                synchronized (mPackages) {
                    // We need to apply this change to the resources
                    // immediately, because upon returning the view
                    // hierarchy will be informed about it.
                    if (applyConfigurationToResourcesLocked(newConfig)) {
                        // This actually changed the resources!  Tell
                        // everyone about it.
                        if (mPendingConfiguration == null ||
                                mPendingConfiguration.isOtherSeqNewer(newConfig)) {
                            mPendingConfiguration = newConfig;
                            
                            queueOrSendMessage(H.CONFIGURATION_CHANGED, newConfig);
                        }
                    }
                }
            }
            public void onLowMemory() {
            }
        });
    }
        
    ...
}
```



### startRunning

frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
public final void startRunning(String pkg, String cls, String action,String data) {
        synchronized(this) {
            if (mStartRunning) { //只会调用一次
                return;
            }
            mStartRunning = true;
            mTopComponent = pkg != null && cls != null? new ComponentName(pkg, cls) : null;
            mTopAction = action != null ? action : Intent.ACTION_MAIN;
            mTopData = data;
             // 能走到这，mSystemReady为false
            if (!mSystemReady) {
                return;
            }
        }

        systemReady(null);
 }
```

`m.startRunning(null, null, null, null);`所以`mTopComponent`最终为null

## ActivityManagerService.setSystemProcess

frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
public static void setSystemProcess() {
        try {
            ActivityManagerService m = mSelf;
            
            // 将AMS注册到ServiceManager
            ServiceManager.addService("activity", m);
           
            // 用于打印内存信息
            ServiceManager.addService("meminfo", new MemBinder(m));
            if (MONITOR_CPU_USAGE) {
                ServiceManager.addService("cpuinfo", new CpuBinder(m));
            }
            ServiceManager.addService("permission", new PermissionController(m));

            // 查询包名为“android”的ApplicationInfo,即framework-res.apk
            ApplicationInfo info =
                mSelf.mContext.getPackageManager().getApplicationInfo(
                        "android", STOCK_PM_FLAGS);
            
            // 调用ActivityThread的installSystemApplicationInfo函数
            mSystemThread.installSystemApplicationInfo(info);
       
            synchronized (mSelf) {
                ProcessRecord app = mSelf.newProcessRecordLocked(
                        mSystemThread.getApplicationThread(), info,
                        info.processName);
                app.persistent = true;
                app.pid = MY_PID;
                app.maxAdj = SYSTEM_ADJ;
                mSelf.mProcessNames.put(app.processName, app.info.uid, app);
                synchronized (mSelf.mPidsSelfLocked) {
                    mSelf.mPidsSelfLocked.put(app.pid, app);
                }
                mSelf.updateLruProcessLocked(app, true, true);
            }
        } catch (PackageManager.NameNotFoundException e) {
            throw new RuntimeException(
                    "Unable to find android system package", e);
        }
    }
```



frameworks\base\core\java\android\app\ActivityThread.java

```java
    public void installSystemApplicationInfo(ApplicationInfo info) {
        synchronized (this) {
            ContextImpl context = getSystemContext();
            context.init(new LoadedApk(this, "android", context, info), null, this);
        }
    }
```



## ActivityManagerService.installSystemProviders

frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
public static final void installSystemProviders() {
        List providers;
        synchronized (mSelf) {
            // 获取前面 installSystemApplicationInfo 创建的进程信息
            ProcessRecord app = mSelf.mProcessNames.get("system", Process.SYSTEM_UID);
            providers = mSelf.generateApplicationProvidersLocked(app);
            if (providers != null) {
                for (int i=providers.size()-1; i>=0; i--) {
                    ProviderInfo pi = (ProviderInfo)providers.get(i);
                    if ((pi.applicationInfo.flags&ApplicationInfo.FLAG_SYSTEM) == 0) {
                        // 去除非系统provider
                        Slog.w(TAG, "Not installing system proc provider " + pi.name
                                + ": not system .apk");
                        providers.remove(i);
                    }
                }
            }
        }
        if (providers != null) {
            mSystemThread.installSystemProviders(providers);
        }
    }
```



frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
private final List generateApplicationProvidersLocked(ProcessRecord app) {
        List providers = null;
        try {
            providers = AppGlobals.getPackageManager().
                queryContentProviders(app.processName, app.info.uid,
                        STOCK_PM_FLAGS | PackageManager.GET_URI_PERMISSION_PATTERNS);
        } catch (RemoteException ex) {
        }
        if (providers != null) {
            final int N = providers.size();
            for (int i=0; i<N; i++) {
                ProviderInfo cpi = (ProviderInfo)providers.get(i);
                ContentProviderRecord cpr = mProvidersByClass.get(cpi.name);
                if (cpr == null) {
                    cpr = new ContentProviderRecord(cpi, app.info);
                    mProvidersByClass.put(cpi.name, cpr);
                }
                // 将信息保存到 ProcessRecord
                app.pubProviders.put(cpi.name, cpr);
                app.addPackage(cpi.applicationInfo.packageName);
                // 优化odex
                ensurePackageDexOpt(cpi.applicationInfo.packageName);
            }
        }
        return providers;
    }
```

