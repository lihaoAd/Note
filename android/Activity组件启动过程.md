## Launcher.startActivitySafely

packages\apps\Launcher2\src\com\android\launcher2\Launcher.java

````java
public final class Launcher extends Activity
       implements View.OnClickListener, OnLongClickListener, LauncherModel.Callbacks, AllAppsView.Watcher {
       
       
       ....
       
   void startActivitySafely(Intent intent, Object tag) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(intent);
        } catch (ActivityNotFoundException e) {
           ...
        } catch (SecurityException e) {
           ...
        }
    }
       
       
       ..... 
 }  
        
````

## Activity.startActivity,Activity.startActivityForResult



frameworks\base\core\java\android\app\Activity.java

```java
public class Activity extends ContextThemeWrapper implements LayoutInflater.Factory,
        Window.Callback, KeyEvent.Callback,
        OnCreateContextMenuListener, ComponentCallbacks {
        
        ...
        
    private Instrumentation mInstrumentation;
    private IBinder mToken;   // 一个IBinder代理对象,指向ActivityManagerService中一个类型为ActivityRecord的本地对象 
    
    ...
            
	@Override
    public void startActivity(Intent intent) {
        startActivityForResult(intent, -1);
    }
            
    public void startActivityForResult(Intent intent, int requestCode) {
        if (mParent == null) {
            Instrumentation.ActivityResult ar =
                mInstrumentation.execStartActivity(
                    this, 
                  	mMainThread.getApplicationThread(),  // Binder本地对象
                	mToken, 
                	this,
                    intent, requestCode);
            if (ar != null) {
                mMainThread.sendActivityResult(
                    mToken, mEmbeddedID, requestCode, ar.getResultCode(),
                    ar.getResultData());
            }
            if (requestCode >= 0) {
                // If this start is requesting a result, we can avoid making
                // the activity visible until the result is received.  Setting
                // this code during onCreate(Bundle savedInstanceState) or onResume() will keep the
                // activity hidden during this time, to avoid flickering.
                // This can only be done when a result is requested because
                // that guarantees we will get information back when the
                // activity is finished, no matter what happens to it.
                mStartedActivity = true;
            }
        } else {
            mParent.startActivityFromChild(this, intent, requestCode);
        }
    }
    
 		...
 
 }
```



frameworks\base\core\java\android\app\ActivityThread.java

```java
public final class ActivityThread {
    
    ...
    
    // Binder本地对象
    final ApplicationThread mAppThread = new ApplicationThread();    
    
    ...
        
	ActivityThread() {
    }

 	public ApplicationThread getApplicationThread()
    {
        return mAppThread;
    }


    ...
        
        
    private final class ApplicationThread extends ApplicationThreadNative {
    ...
    }
        
}

```



frameworks\base\core\java\android\app\ApplicationThreadNative.java

````java
public abstract class ApplicationThreadNative extends Binder implements IApplicationThread {
    ...
        
}      
        
````



## Instrumentation.execStartActivity

frameworks\base\core\java\android\app\Instrumentation.java

```java
 public ActivityResult execStartActivity(
        Context who,             
     	IBinder contextThread, 
     	IBinder token, 
     	Activity target,
        Intent intent, int requestCode) {
        IApplicationThread whoThread = (IApplicationThread) contextThread;
        if (mActivityMonitors != null) {
            synchronized (mSync) {
                final int N = mActivityMonitors.size();
                for (int i=0; i<N; i++) {
                    final ActivityMonitor am = mActivityMonitors.get(i);
                    if (am.match(who, null, intent)) {
                        am.mHits++;
                        if (am.isBlocking()) {
                            return requestCode >= 0 ? am.getResult() : null;
                        }
                        break;
                    }
                }
            }
        }
        try {
            
            // 使用ActivityManagerService的一个代理对象
            int result = ActivityManagerNative.getDefault()
                .startActivity(whoThread, intent,
                        intent.resolveTypeIfNeeded(who.getContentResolver()),
                        null, 0, token, target != null ? target.mEmbeddedID : null,
                        requestCode, false, false);
            checkStartActivityResult(result, intent);
        } catch (RemoteException e) {
        }
        return null;
    }
```



frameworks\base\core\java\android\app\ActivityManagerNative.java

```java
public abstract class ActivityManagerNative extends Binder implements IActivityManager
{

....

	public int startActivity(IApplicationThread caller, Intent intent,
            String resolvedType, Uri[] grantedUriPermissions, int grantedMode,
            IBinder resultTo, String resultWho,
            int requestCode, boolean onlyIfNeeded,
            boolean debug) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        data.writeInterfaceToken(IActivityManager.descriptor);
        data.writeStrongBinder(caller != null ? caller.asBinder() : null);
        intent.writeToParcel(data, 0);
        data.writeString(resolvedType);
        data.writeTypedArray(grantedUriPermissions, 0);
        data.writeInt(grantedMode);
        data.writeStrongBinder(resultTo);
        data.writeString(resultWho);
        data.writeInt(requestCode);
        data.writeInt(onlyIfNeeded ? 1 : 0);
        data.writeInt(debug ? 1 : 0);
        mRemote.transact(START_ACTIVITY_TRANSACTION, data, reply, 0);
        reply.readException();
        int result = reply.readInt();
        reply.recycle();
        data.recycle();
        return result;
    }


    
     public boolean onTransact(int code, Parcel data, Parcel reply, int flags)
            throws RemoteException {
        switch (code) {
        case START_ACTIVITY_TRANSACTION:
        {
            data.enforceInterface(IActivityManager.descriptor);
            IBinder b = data.readStrongBinder();
            IApplicationThread app = ApplicationThreadNative.asInterface(b);
            Intent intent = Intent.CREATOR.createFromParcel(data);
            String resolvedType = data.readString();
            Uri[] grantedUriPermissions = data.createTypedArray(Uri.CREATOR);
            int grantedMode = data.readInt();
            IBinder resultTo = data.readStrongBinder();
            String resultWho = data.readString();    
            int requestCode = data.readInt();
            boolean onlyIfNeeded = data.readInt() != 0;
            boolean debug = data.readInt() != 0;
            
            int result = startActivity(app, intent, resolvedType,
                    grantedUriPermissions, grantedMode, resultTo, resultWho,
                    requestCode, onlyIfNeeded, debug);
            reply.writeNoException();
            reply.writeInt(result);
            return true;
        }
                
                ....
                    
                    
                    
      }
....

}
```

向`ActivityManagerService`发送`START_ACTIVITY_TRANSACTION`进程间通信请求.

`ActivityManagerService`要在自己的`onTransact`方法中处理接收的消息。因为它是继承自`ActivityManagerNative`的，自己也没有重写这个方法，所以调用的是`ActivityManagerNative`的`onTransact`方法。这个方法调用了`startActivity`方法，也就是调用了`ActivityManagerService`的`startActivity`方法

## ActivityManagerService.startActivity

frameworks\base\services\java\com\android\server\am\ActivityManagerService.java

```java
public final class ActivityManagerService extends ActivityManagerNative
        implements Watchdog.Monitor, BatteryStatsImpl.BatteryCallback{
    ...

    public final int startActivity(IApplicationThread caller,
            Intent intent, String resolvedType, Uri[] grantedUriPermissions,
            int grantedMode, IBinder resultTo,
            String resultWho, int requestCode, boolean onlyIfNeeded,
            boolean debug) {
        
        return mMainStack.startActivityMayWait(caller, intent, resolvedType,
                grantedUriPermissions, grantedMode, resultTo, resultWho,
                requestCode, onlyIfNeeded, debug, null, null);
    }

    ...

}
```

