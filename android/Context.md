## 相关继承



## 创建Context



### Application



frameworks\base\core\java\android\app\ActivityThread.java

```java
private final void handleBindApplication(AppBindData data) {
	....
	
	
	ContextImpl appContext = new ContextImpl();
    appContext.init(data.info, null, this);
    InstrumentationInfo ii = null;
    try {
        ii = appContext.getPackageManager().getInstrumentationInfo(data.instrumentationName, 0);
        } catch (PackageManager.NameNotFoundException e) {
    }
	
	....
}
```



frameworks\base\core\java\android\app\ContextImpl.java

```java
    final void init(LoadedApk packageInfo,IBinder activityToken, ActivityThread mainThread) {
        init(packageInfo, activityToken, mainThread, null);
    }
```



### Activity

frameworks\base\core\java\android\app\ActivityThread.java

```java

private final void handleLaunchActivity(ActivityClientRecord r, Intent customIntent) {
	...
	
	
	...
	
}	
```

