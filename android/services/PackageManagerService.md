frameworks\base\services\java\com\android\server\SystemServer.java

```java
pm = PackageManagerService.main(context,factoryTest != SystemServer.FACTORY_TEST_OFF);



```



frameworks\base\services\java\com\android\server\PackageManagerService.java

```java
    public static final IPackageManager main(Context context, boolean factoryTest) {
        PackageManagerService m = new PackageManagerService(context, factoryTest);
        // 注册服务
        ServiceManager.addService("package", m);
        return m;
    }
```



frameworks\base\services\java\com\android\server\PackageManagerService.java

```java
final int mSdkVersion = Build.VERSION.SDK_INT;


public PackageManagerService(Context context, boolean factoryTest) {
        EventLog.writeEvent(EventLogTags.BOOT_PROGRESS_PMS_START,SystemClock.uptimeMillis());

        if (mSdkVersion <= 0) {
            // mSdkVersion 是PKMS的成员变量，定义的时候已经赋值，即编译的SDK版本，如果没有定义，则APK就无法知道自己运行在Android的哪个版本上
            Slog.w(TAG, "**** ro.build.version.sdk not set!");
        }

        mContext = context;
        mFactoryTest = factoryTest;
    
    	// 如果此版本是eng版，则扫描后，不做dex优化
        mNoDexOpt = "eng".equals(SystemProperties.get("ro.build.type"));
    
        mMetrics = new DisplayMetrics();
    
    	// 存储运行过程中的一些设置
        mSettings = new Settings();
        // 
        mSettings.addSharedUserLP("android.uid.system",Process.SYSTEM_UID, ApplicationInfo.FLAG_SYSTEM);
        mSettings.addSharedUserLP("android.uid.phone",
                MULTIPLE_APPLICATION_UIDS
                        ? RADIO_UID : FIRST_APPLICATION_UID,
                ApplicationInfo.FLAG_SYSTEM);
        mSettings.addSharedUserLP("android.uid.log",
                MULTIPLE_APPLICATION_UIDS
                        ? LOG_UID : FIRST_APPLICATION_UID,
                ApplicationInfo.FLAG_SYSTEM);
        mSettings.addSharedUserLP("android.uid.nfc",
                MULTIPLE_APPLICATION_UIDS
                        ? NFC_UID : FIRST_APPLICATION_UID,
                ApplicationInfo.FLAG_SYSTEM);

        // 和调试有关
        String separateProcesses = SystemProperties.get("debug.separate_processes");
        if (separateProcesses != null && separateProcesses.length() > 0) {
            if ("*".equals(separateProcesses)) {
                mDefParseFlags = PackageParser.PARSE_IGNORE_PROCESSES;
                mSeparateProcesses = null;
                Slog.w(TAG, "Running with debug.separate_processes: * (ALL)");
            } else {
                mDefParseFlags = 0;
                mSeparateProcesses = separateProcesses.split(",");
                Slog.w(TAG, "Running with debug.separate_processes: "
                        + separateProcesses);
            }
        } else {
            mDefParseFlags = 0;
            mSeparateProcesses = null;
        }

        Installer installer = new Installer();
        // Little hacky thing to check if installd is here, to determine
        // whether we are running on the simulator and thus need to take
        // care of building the /data file structure ourself.
        // (apparently the sim now has a working installer)
        if (installer.ping() && Process.supportsProcesses()) {
            mInstaller = installer;
        } else {
            mInstaller = null;
        }

        WindowManager wm = (WindowManager)context.getSystemService(Context.WINDOW_SERVICE);
        Display d = wm.getDefaultDisplay();
        d.getMetrics(mMetrics);

        synchronized (mInstallLock) {
        synchronized (mPackages) {
            mHandlerThread.start();
            mHandler = new PackageHandler(mHandlerThread.getLooper());

            File dataDir = Environment.getDataDirectory();
            mAppDataDir = new File(dataDir, "data");
            mSecureAppDataDir = new File(dataDir, "secure/data");
            mDrmAppPrivateInstallDir = new File(dataDir, "app-private");

            if (mInstaller == null) {
                // Make sure these dirs exist, when we are running in
                // the simulator.
                // Make a wide-open directory for random misc stuff.
                File miscDir = new File(dataDir, "misc");
                miscDir.mkdirs();
                mAppDataDir.mkdirs();
                mSecureAppDataDir.mkdirs();
                mDrmAppPrivateInstallDir.mkdirs();
            }

            readPermissions();

            mRestoredSettings = mSettings.readLP();
            long startTime = SystemClock.uptimeMillis();

            EventLog.writeEvent(EventLogTags.BOOT_PROGRESS_PMS_SYSTEM_SCAN_START,
                    startTime);

            // Set flag to monitor and not change apk file paths when
            // scanning install directories.
            int scanMode = SCAN_MONITOR | SCAN_NO_PATHS;
            if (mNoDexOpt) {
                Slog.w(TAG, "Running ENG build: no pre-dexopt!");
                scanMode |= SCAN_NO_DEX;
            }

            final HashSet<String> libFiles = new HashSet<String>();

            mFrameworkDir = new File(Environment.getRootDirectory(), "framework");
            mDalvikCacheDir = new File(dataDir, "dalvik-cache");

            if (mInstaller != null) {
                boolean didDexOpt = false;

                /**
                 * Out of paranoia, ensure that everything in the boot class
                 * path has been dexed.
                 */
                String bootClassPath = System.getProperty("java.boot.class.path");
                if (bootClassPath != null) {
                    String[] paths = splitString(bootClassPath, ':');
                    for (int i=0; i<paths.length; i++) {
                        try {
                            if (dalvik.system.DexFile.isDexOptNeeded(paths[i])) {
                                libFiles.add(paths[i]);
                                mInstaller.dexopt(paths[i], Process.SYSTEM_UID, true);
                                didDexOpt = true;
                            }
                        } catch (FileNotFoundException e) {
                            Slog.w(TAG, "Boot class path not found: " + paths[i]);
                        } catch (IOException e) {
                            Slog.w(TAG, "Exception reading boot class path: " + paths[i], e);
                        }
                    }
                } else {
                    Slog.w(TAG, "No BOOTCLASSPATH found!");
                }

                /**
                 * Also ensure all external libraries have had dexopt run on them.
                 */
                if (mSharedLibraries.size() > 0) {
                    Iterator<String> libs = mSharedLibraries.values().iterator();
                    while (libs.hasNext()) {
                        String lib = libs.next();
                        try {
                            if (dalvik.system.DexFile.isDexOptNeeded(lib)) {
                                libFiles.add(lib);
                                mInstaller.dexopt(lib, Process.SYSTEM_UID, true);
                                didDexOpt = true;
                            }
                        } catch (FileNotFoundException e) {
                            Slog.w(TAG, "Library not found: " + lib);
                        } catch (IOException e) {
                            Slog.w(TAG, "Exception reading library: " + lib, e);
                        }
                    }
                }

                // Gross hack for now: we know this file doesn't contain any
                // code, so don't dexopt it to avoid the resulting log spew.
                libFiles.add(mFrameworkDir.getPath() + "/framework-res.apk");

                /**
                 * And there are a number of commands implemented in Java, which
                 * we currently need to do the dexopt on so that they can be
                 * run from a non-root shell.
                 */
                String[] frameworkFiles = mFrameworkDir.list();
                if (frameworkFiles != null) {
                    for (int i=0; i<frameworkFiles.length; i++) {
                        File libPath = new File(mFrameworkDir, frameworkFiles[i]);
                        String path = libPath.getPath();
                        // Skip the file if we alrady did it.
                        if (libFiles.contains(path)) {
                            continue;
                        }
                        // Skip the file if it is not a type we want to dexopt.
                        if (!path.endsWith(".apk") && !path.endsWith(".jar")) {
                            continue;
                        }
                        try {
                            if (dalvik.system.DexFile.isDexOptNeeded(path)) {
                                mInstaller.dexopt(path, Process.SYSTEM_UID, true);
                                didDexOpt = true;
                            }
                        } catch (FileNotFoundException e) {
                            Slog.w(TAG, "Jar not found: " + path);
                        } catch (IOException e) {
                            Slog.w(TAG, "Exception reading jar: " + path, e);
                        }
                    }
                }

                if (didDexOpt) {
                    // If we had to do a dexopt of one of the previous
                    // things, then something on the system has changed.
                    // Consider this significant, and wipe away all other
                    // existing dexopt files to ensure we don't leave any
                    // dangling around.
                    String[] files = mDalvikCacheDir.list();
                    if (files != null) {
                        for (int i=0; i<files.length; i++) {
                            String fn = files[i];
                            if (fn.startsWith("data@app@")
                                    || fn.startsWith("data@app-private@")) {
                                Slog.i(TAG, "Pruning dalvik file: " + fn);
                                (new File(mDalvikCacheDir, fn)).delete();
                            }
                        }
                    }
                }
            }

            // Find base frameworks (resource packages without code).
            mFrameworkInstallObserver = new AppDirObserver(
                mFrameworkDir.getPath(), OBSERVER_EVENTS, true);
            mFrameworkInstallObserver.startWatching();
            scanDirLI(mFrameworkDir, PackageParser.PARSE_IS_SYSTEM
                    | PackageParser.PARSE_IS_SYSTEM_DIR,
                    scanMode | SCAN_NO_DEX, 0);
            
            // Collect all system packages.
            mSystemAppDir = new File(Environment.getRootDirectory(), "app");
            mSystemInstallObserver = new AppDirObserver(
                mSystemAppDir.getPath(), OBSERVER_EVENTS, true);
            mSystemInstallObserver.startWatching();
            scanDirLI(mSystemAppDir, PackageParser.PARSE_IS_SYSTEM
                    | PackageParser.PARSE_IS_SYSTEM_DIR, scanMode, 0);
            
            // Collect all vendor packages.
            mVendorAppDir = new File("/vendor/app");
            mVendorInstallObserver = new AppDirObserver(
                mVendorAppDir.getPath(), OBSERVER_EVENTS, true);
            mVendorInstallObserver.startWatching();
            scanDirLI(mVendorAppDir, PackageParser.PARSE_IS_SYSTEM
                    | PackageParser.PARSE_IS_SYSTEM_DIR, scanMode, 0);

            if (mInstaller != null) {
                if (DEBUG_UPGRADE) Log.v(TAG, "Running installd update commands");
                mInstaller.moveFiles();
            }
            
            // Prune any system packages that no longer exist.
            Iterator<PackageSetting> psit = mSettings.mPackages.values().iterator();
            while (psit.hasNext()) {
                PackageSetting ps = psit.next();
                if ((ps.pkgFlags&ApplicationInfo.FLAG_SYSTEM) != 0
                        && !mPackages.containsKey(ps.name)
                        && !mSettings.mDisabledSysPackages.containsKey(ps.name)) {
                    psit.remove();
                    String msg = "System package " + ps.name
                            + " no longer exists; wiping its data";
                    reportSettingsProblem(Log.WARN, msg);
                    if (mInstaller != null) {
                        // XXX how to set useEncryptedFSDir for packages that
                        // are not encrypted?
                        mInstaller.remove(ps.name, true);
                    }
                }
            }
            
            mAppInstallDir = new File(dataDir, "app");
            if (mInstaller == null) {
                // Make sure these dirs exist, when we are running in
                // the simulator.
                mAppInstallDir.mkdirs(); // scanDirLI() assumes this dir exists
            }
            //look for any incomplete package installations
            ArrayList<PackageSetting> deletePkgsList = mSettings.getListOfIncompleteInstallPackages();
            //clean up list
            for(int i = 0; i < deletePkgsList.size(); i++) {
                //clean up here
                cleanupInstallFailedPackage(deletePkgsList.get(i));
            }
            //delete tmp files
            deleteTempPackageFiles();

            EventLog.writeEvent(EventLogTags.BOOT_PROGRESS_PMS_DATA_SCAN_START,
                    SystemClock.uptimeMillis());
            mAppInstallObserver = new AppDirObserver(
                mAppInstallDir.getPath(), OBSERVER_EVENTS, false);
            mAppInstallObserver.startWatching();
            scanDirLI(mAppInstallDir, 0, scanMode, 0);

            mDrmAppInstallObserver = new AppDirObserver(
                mDrmAppPrivateInstallDir.getPath(), OBSERVER_EVENTS, false);
            mDrmAppInstallObserver.startWatching();
            scanDirLI(mDrmAppPrivateInstallDir, PackageParser.PARSE_FORWARD_LOCK,
                    scanMode, 0);

            EventLog.writeEvent(EventLogTags.BOOT_PROGRESS_PMS_SCAN_END,
                    SystemClock.uptimeMillis());
            Slog.i(TAG, "Time to scan packages: "
                    + ((SystemClock.uptimeMillis()-startTime)/1000f)
                    + " seconds");

            // If the platform SDK has changed since the last time we booted,
            // we need to re-grant app permission to catch any new ones that
            // appear.  This is really a hack, and means that apps can in some
            // cases get permissions that the user didn't initially explicitly
            // allow...  it would be nice to have some better way to handle
            // this situation.
            final boolean regrantPermissions = mSettings.mInternalSdkPlatform
                    != mSdkVersion;
            if (regrantPermissions) Slog.i(TAG, "Platform changed from "
                    + mSettings.mInternalSdkPlatform + " to " + mSdkVersion
                    + "; regranting permissions for internal storage");
            mSettings.mInternalSdkPlatform = mSdkVersion;
            
            updatePermissionsLP(null, null, true, regrantPermissions, regrantPermissions);

            mSettings.writeLP();

            EventLog.writeEvent(EventLogTags.BOOT_PROGRESS_PMS_READY,
                    SystemClock.uptimeMillis());

            // Now after opening every single application zip, make sure they
            // are all flushed.  Not really needed, but keeps things nice and
            // tidy.
            Runtime.getRuntime().gc();
        } // synchronized (mPackages)
        } // synchronized (mInstallLock)
    }
```

