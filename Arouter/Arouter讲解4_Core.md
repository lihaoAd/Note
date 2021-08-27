## 复习



 经过前面的文章，我们知道注解处理后重新生成的文件，我们再来复习下

- 被Route注解的会生成类似下面这样的类

![image-20210513215345870](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513215345870.png)

如果是IProvider类型的，会生成类似下面的类

![image-20210513215611787](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513215611787.png)

- 如果是 IInterceptor 类型的，会生成类似下面的类，其实 IInterceptor 也是 IProvider类的子类

![image-20210513215732293](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513215732293.png)



- 可以用Class 来进行路由，是因为生成了类似下面这样的类，path就是类的全限定名。

  ![image-20210513215959795](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513215959795.png)



- 收集每个组的类。

![image-20210513220113496](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513220113496.png)

## ARouter.init

路由初始化

```java
ARouter.init(getApplication());
```

```java
public static void init(Application application) {
    if (!hasInit) {
        logger = _ARouter.logger;
        _ARouter.logger.info(Consts.TAG, "ARouter init start.");
        hasInit = _ARouter.init(application); // 初始化 _ARouter 

        if (hasInit) {
            _ARouter.afterInit();// 初始化后，获取 InterceptorService，，对拦截做统一处理
        }

        _ARouter.logger.info(Consts.TAG, "ARouter init over.");
    }
}
```



```java
protected static synchronized boolean init(Application application) {
    mContext = application;
    LogisticsCenter.init(mContext, executor);
    logger.info(Consts.TAG, "ARouter init success!");
    hasInit = true;
    mHandler = new Handler(Looper.getMainLooper());

    return true;
}
```



##  LogisticsCenter.init

```java
private static void loadRouterMap() {
    registerByPlugin = false;
    // auto generate register code by gradle plugin: arouter-auto-register
    // looks like below:
    // registerRouteRoot(new ARouter..Root..modulejava());
    // registerRouteRoot(new ARouter..Root..modulekotlin());
}
```

源码中是上面这样的，之前为了收集路由信息，程序启动后会扫描dex文件，不过这样会影响启动速度，不过后来经过 arouter-register 插件的插桩的处理，会扫描 jar 包中满足条件的类，收集后就会变成下面这样

```java
 private static void loadRouterMap()
  {
    registerByPlugin = false;
    register("com.alibaba.android.arouter.routes.ARouter$$Root$$modulejava");
    register("com.alibaba.android.arouter.routes.ARouter$$Root$$arouterapi");
    register("com.alibaba.android.arouter.routes.ARouter$$Interceptors$$modulejava");
    register("com.alibaba.android.arouter.routes.ARouter$$Providers$$modulejava");
    register("com.alibaba.android.arouter.routes.ARouter$$Providers$$arouterapi");
  }
```

在看下面之前线来看看 Warehouse 类，里面存了所有的路由信息。

```java
class Warehouse {
    // Cache route and metas
    static Map<String, Class<? extends IRouteGroup>> groupsIndex = new HashMap<>();
    static Map<String, RouteMeta> routes = new HashMap<>();

    // Cache provider
    static Map<Class, IProvider> providers = new HashMap<>();
    static Map<String, RouteMeta> providersIndex = new HashMap<>();

    // Cache interceptor
    static Map<Integer, Class<? extends IInterceptor>> interceptorsIndex = new UniqueKeyTreeMap<>("More than one interceptors use same priority [%s]");
    static List<IInterceptor> interceptors = new ArrayList<>();

    static void clear() {
        routes.clear();
        groupsIndex.clear();
        providers.clear();
        providersIndex.clear();
        interceptors.clear();
        interceptorsIndex.clear();
    }
}
```

很简单，就是注册我们指定的类。

```java
private static void register(String className) {
    if (!TextUtils.isEmpty(className)) {
        try {
            Class<?> clazz = Class.forName(className);
            Object obj = clazz.getConstructor().newInstance(); //实例化一个对象
            if (obj instanceof IRouteRoot) {
                registerRouteRoot((IRouteRoot) obj);
            } else if (obj instanceof IProviderGroup) {
                registerProvider((IProviderGroup) obj);
            } else if (obj instanceof IInterceptorGroup) {
                registerInterceptor((IInterceptorGroup) obj);
            } else {
                logger.info(TAG, "register failed, class name: " + className
                        + " should implements one of IRouteRoot/IProviderGroup/IInterceptorGroup.");
            }
        } catch (Exception e) {
            logger.error(TAG,"register class error:" + className, e);
        }
    }
}

 private static void registerRouteRoot(IRouteRoot routeRoot) {
        markRegisteredByPlugin(); // 会改变 registerByPlugin 为true，这样后面就不会扫描dex了。
        if (routeRoot != null) {
            routeRoot.loadInto(Warehouse.groupsIndex); // 对照上面的图看就很容易懂了。
        }
    }

  private static void registerProvider(IProviderGroup providerGroup) {
        markRegisteredByPlugin();
        if (providerGroup != null) {
            providerGroup.loadInto(Warehouse.providersIndex);
        }
    }

 private static void registerInterceptor(IInterceptorGroup interceptorGroup) {
        markRegisteredByPlugin();
        if (interceptorGroup != null) {
            interceptorGroup.loadInto(Warehouse.interceptorsIndex);
        }
    }

```

经过 loadRouterMap()方法的执行，已经收集了所有的路由信息，下面就是根据path路由到其他类的操作了。



## navigation

```java
public <T> T navigation(Class<? extends T> service) {
    return _ARouter.getInstance().navigation(service);
}
```

我们先对 navigation 源码分析，因为后面build里面还会调用 navigation ，在demo中，有个HelloService，有一个直接的子类 HelloServiceImpl，想要得到 HelloServiceImpl ，可以 用 navigation(HelloService.class)得到，也可以用path得到。



```java
public interface HelloService extends IProvider {
    void sayHello(String name);
}
```

```java
@Route(path = "/yourservicegroupname/hello")
public class HelloServiceImpl implements HelloService {
    Context mContext;

    @Override
    public void sayHello(String name) {
        Toast.makeText(mContext, "Hello " + name, Toast.LENGTH_SHORT).show();
    }

    @Override
    public void init(Context context) {
        mContext = context;
        Log.e("testService", HelloService.class.getName() + " has init.");
    }
}
```



```java
protected <T> T navigation(Class<? extends T> service) {
    try {
        Postcard postcard = LogisticsCenter.buildProvider(service.getName());

        // Compatible 1.0.5 compiler sdk.
        // Earlier versions did not use the fully qualified name to get the service
        if (null == postcard) {
            // No service, or this service in old version.
            postcard = LogisticsCenter.buildProvider(service.getSimpleName());
        }

        if (null == postcard) {
            return null;
        }

        // Set application to postcard.
        postcard.setContext(mContext);

        LogisticsCenter.completion(postcard);
        return (T) postcard.getProvider();
    } catch (NoRouteFoundException ex) {
        logger.warning(Consts.TAG, ex.getMessage());
        return null;
    }
}
```

从Warehouse.providersIndex 的HashMap中根据全限定名得到 RouteMeta

```java
public static Postcard buildProvider(String serviceName) {
    RouteMeta meta = Warehouse.providersIndex.get(serviceName);

    if (null == meta) {
        return null;
    } else {
        return new Postcard(meta.getPath(), meta.getGroup());
    }
}
```

刚刚new 出来的 Postcard 只含有 path 和Group，还需要对其他信息进行补充。先从 routes 缓存中根据path获取 RouteMeta，如果缓存中没有，可以动态添加。

如果缓存中有了，就把数据填充到 Postcard

```java
public synchronized static void completion(Postcard postcard) {
    if (null == postcard) {
        throw new NoRouteFoundException(TAG + "No postcard!");
    }

    // 先从缓存类找
    RouteMeta routeMeta = Warehouse.routes.get(postcard.getPath());
    
    if (null == routeMeta) {
        // Maybe its does't exist, or didn't load.
        // 缓存里没有
        // 可以动态添加，但是先要把group添加进来
        if (!Warehouse.groupsIndex.containsKey(postcard.getGroup())) {
            throw new NoRouteFoundException(TAG + "There is no route match the path [" + postcard.getPath() + "], in group [" + postcard.getGroup() + "]");
        } else {
            // Load route and cache it into memory, then delete from metas.
            try {
                if (ARouter.debuggable()) {
                    logger.debug(TAG, String.format(Locale.getDefault(), "The group [%s] starts loading, trigger by [%s]", postcard.getGroup(), postcard.getPath()));
                }

                // 动态添加
                addRouteGroupDynamic(postcard.getGroup(), null);

                if (ARouter.debuggable()) {
                    logger.debug(TAG, String.format(Locale.getDefault(), "The group [%s] has already been loaded, trigger by [%s]", postcard.getGroup(), postcard.getPath()));
                }
            } catch (Exception e) {
                throw new HandlerException(TAG + "Fatal exception when loading group meta. [" + e.getMessage() + "]");
            }

            completion(postcard);   // Reload
        }
    } else {
        // 从缓存取数据
        postcard.setDestination(routeMeta.getDestination()); // 路由目标类
        postcard.setType(routeMeta.getType());  // 路由的类型 RouteType ，可以是  ACTIVITY、SERVICE、PROVIDER 、CONTENT_PROVIDER、FRAGMENT等
        postcard.setPriority(routeMeta.getPriority()); // 权限值
        postcard.setExtra(routeMeta.getExtra()); // 额外的信息

        Uri rawUri = postcard.getUri();
        if (null != rawUri) {   // Try to set params into bundle.
            Map<String, String> resultMap = TextUtils.splitQueryParameters(rawUri);
            Map<String, Integer> paramsType = routeMeta.getParamsType();

            if (MapUtils.isNotEmpty(paramsType)) {
                // Set value by its type, just for params which annotation by @Param
                for (Map.Entry<String, Integer> params : paramsType.entrySet()) {
                    setValue(postcard,
                            params.getValue(),
                            params.getKey(),
                            resultMap.get(params.getKey()));
                }

                // Save params name which need auto inject.
                postcard.getExtras().putStringArray(ARouter.AUTO_INJECT, paramsType.keySet().toArray(new String[]{}));
            }

            // Save raw uri
            postcard.withString(ARouter.RAW_URI, rawUri.toString());
        }

        switch (routeMeta.getType()) {
            case PROVIDER:  // if the route is provider, should find its instance
                // Its provider, so it must implement IProvider
                Class<? extends IProvider> providerMeta = (Class<? extends IProvider>) routeMeta.getDestination();
                IProvider instance = Warehouse.providers.get(providerMeta); // 从缓存中取
                if (null == instance) { // There's no instance of this provider
                    // 没有缓存
                    IProvider provider;
                    try {
                        provider = providerMeta.getConstructor().newInstance();
                        provider.init(mContext);
                        Warehouse.providers.put(providerMeta, provider); // 放到缓存中
                        instance = provider;
                    } catch (Exception e) {
                        logger.error(TAG, "Init provider failed!", e);
                        throw new HandlerException("Init provider failed!");
                    }
                }
                postcard.setProvider(instance); // 拿到了实例对象
                postcard.greenChannel();    // 绿色通道， Provider不受拦截器的影响
                break;
            case FRAGMENT:
                postcard.greenChannel();    // Fragment  类型也走绿色通道，不受拦截器的影响
            default:
                break;
        }
    }
}
```



## build

```java
public Postcard build(String path) {
    return _ARouter.getInstance().build(path);
}
```

我们用build进行源码分析，首先

```java
protected Postcard build(String path) {
    if (TextUtils.isEmpty(path)) {
        throw new HandlerException(Consts.TAG + "Parameter is invalid!");
    } else {
        PathReplaceService pService = ARouter.getInstance().navigation(PathReplaceService.class);
        if (null != pService) {
            path = pService.forString(path);
        }
        // 如果有PathReplaceService ，这里的path已经经过PathReplaceService， afterReplace就是为true，后面就不要到 PathReplaceService了
        return build(path, extractGroup(path), true);
    }
}
```

如果实现 PathReplaceService ，可以对path进行拦截与修改。

```java
public interface PathReplaceService extends IProvider {

    /**
     * For normal path.
     *
     * @param path raw path
     */
    String forString(String path);

    /**
     * For uri type.
     *
     * @param uri raw uri
     */
    Uri forUri(Uri uri);
}
```





```java
protected Postcard build(String path, String group, Boolean afterReplace) {
    if (TextUtils.isEmpty(path) || TextUtils.isEmpty(group)) {
        throw new HandlerException(Consts.TAG + "Parameter is invalid!");
    } else {
        if (!afterReplace) {
            PathReplaceService pService = ARouter.getInstance().navigation(PathReplaceService.class);
            if (null != pService) {
                path = pService.forString(path);
            }
        }
        return new Postcard(path, group);
    }
}
```



```java
protected Object navigation(final Context context, final Postcard postcard, final int requestCode, final NavigationCallback callback) {
    
    // 在 navigation之前 我们还有一次机会修改Postcard，是否需要被路由
    PretreatmentService pretreatmentService = ARouter.getInstance().navigation(PretreatmentService.class);
    if (null != pretreatmentService && !pretreatmentService.onPretreatment(context, postcard)) {
        // 条件不满足，不再 navigation
        // Pretreatment failed, navigation canceled.
        return null;
    }

    // Set context to postcard.
    postcard.setContext(null == context ? mContext : context);

    try {
        LogisticsCenter.completion(postcard); // 把数据填充到 Postcard
    } catch (NoRouteFoundException ex) {
       ...........

        if (null != callback) {
            callback.onLost(postcard);//给出回调
        } else {
            // No callback for this invoke, then we use the global degrade service.
            DegradeService degradeService = ARouter.getInstance().navigation(DegradeService.class);
            if (null != degradeService) {
                degradeService.onLost(context, postcard);
            }
        }

        return null;
    }

    if (null != callback) {
        callback.onFound(postcard); //给出回调，已经找到 postcard
    }

    // Arouter init后，会获取 InterceptorService
    if (!postcard.isGreenChannel()) {   // It must be run in async thread, maybe interceptor cost too mush time made ANR.
        //fragment、provide都是绿色通道
        interceptorService.doInterceptions(postcard, new InterceptorCallback() {
            /**
             * Continue process
             *
             * @param postcard route meta
             */
            @Override
            public void onContinue(Postcard postcard) {
                _navigation(postcard, requestCode, callback);
            }

            /**
             * Interrupt process, pipeline will be destory when this method called.
             *
             * @param exception Reson of interrupt.
             */
            @Override
            public void onInterrupt(Throwable exception) {
                if (null != callback) {
                    callback.onInterrupt(postcard);
                }

                logger.info(Consts.TAG, "Navigation failed, termination by interceptor : " + exception.getMessage());
            }
        });
    } else {
        return _navigation(postcard, requestCode, callback);
    }

    return null;
}
```



```java
private Object _navigation(final Postcard postcard, final int requestCode, final NavigationCallback callback) {
    final Context currentContext = postcard.getContext();

    switch (postcard.getType()) {
        case ACTIVITY:
            // 和我们平时用Intetn打开Activity一样
            // Build intent
            final Intent intent = new Intent(currentContext, postcard.getDestination());
            intent.putExtras(postcard.getExtras()); // 额外的参数

            // Set flags.
            int flags = postcard.getFlags();
            if (0 != flags) {
                intent.setFlags(flags);
            }

            // Non activity, need FLAG_ACTIVITY_NEW_TASK
            if (!(currentContext instanceof Activity)) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }

            // Set Actions
            String action = postcard.getAction();
            if (!TextUtils.isEmpty(action)) {
                intent.setAction(action);
            }

            // Navigation in main looper.
            runInMainThread(new Runnable() {
                @Override
                public void run() {
                    startActivity(requestCode, currentContext, intent, postcard, callback);
                }
            });

            break;
        case PROVIDER:
            return postcard.getProvider();// 如果是provide，之间返回
        case BOARDCAST:
        case CONTENT_PROVIDER:
        case FRAGMENT:
            Class<?> fragmentMeta = postcard.getDestination();
            try {
                Object instance = fragmentMeta.getConstructor().newInstance();
                if (instance instanceof Fragment) {
                    ((Fragment) instance).setArguments(postcard.getExtras());
                } else if (instance instanceof android.support.v4.app.Fragment) {
                    ((android.support.v4.app.Fragment) instance).setArguments(postcard.getExtras());
                }

                return instance;
            } catch (Exception ex) {
                logger.error(Consts.TAG, "Fetch fragment instance error, " + TextUtils.formatStackTrace(ex.getStackTrace()));
            }
        case METHOD:
        case SERVICE:
        default:
            return null;
    }

    return null;
}
```



## InterceptorService



```java
@Route(path = "/arouter/service/interceptor")
public class InterceptorServiceImpl implements InterceptorService
```



先到子线程中初始化，按照顺序执行我们定义的拦截器，因为拦截方法中可能有耗时操作，引起ANR，所以放在子线程中执行拦截操作。

```java
@Override
public void init(final Context context) {
    LogisticsCenter.executor.execute(new Runnable() {
        @Override
        public void run() {
            if (MapUtils.isNotEmpty(Warehouse.interceptorsIndex)) {
                for (Map.Entry<Integer, Class<? extends IInterceptor>> entry : Warehouse.interceptorsIndex.entrySet()) {
                    Class<? extends IInterceptor> interceptorClass = entry.getValue();
                    try {
                        IInterceptor iInterceptor = interceptorClass.getConstructor().newInstance();
                        iInterceptor.init(context);
                        Warehouse.interceptors.add(iInterceptor);
                    } catch (Exception ex) {
                        throw new HandlerException(TAG + "ARouter init interceptor error! name = [" + interceptorClass.getName() + "], reason = [" + ex.getMessage() + "]");
                    }
                }

                interceptorHasInit = true;

                logger.info(TAG, "ARouter interceptors init over.");

                synchronized (interceptorInitLock) {
                    interceptorInitLock.notifyAll();
                }
            }
        }
    });
}
```



```java

@Override
public void doInterceptions(final Postcard postcard, final InterceptorCallback callback) {
    if (MapUtils.isNotEmpty(Warehouse.interceptorsIndex)) {

        checkInterceptorsInitStatus();

        if (!interceptorHasInit) {
            callback.onInterrupt(new HandlerException("Interceptors initialization takes too much time."));
            return;
        }

        LogisticsCenter.executor.execute(new Runnable() {
            @Override
            public void run() {
                //
                CancelableCountDownLatch interceptorCounter = new CancelableCountDownLatch(Warehouse.interceptors.size());
                try {
                    _execute(0, interceptorCounter, postcard);
                    interceptorCounter.await(postcard.getTimeout(), TimeUnit.SECONDS);
                    if (interceptorCounter.getCount() > 0) {    // Cancel the navigation this time, if it hasn't return anythings.
                        callback.onInterrupt(new HandlerException("The interceptor processing timed out."));
                    } else if (null != postcard.getTag()) {    // Maybe some exception in the tag.
                        callback.onInterrupt((Throwable) postcard.getTag());
                    } else {
                        callback.onContinue(postcard);
                    }
                } catch (Exception e) {
                    callback.onInterrupt(e);
                }
            }
        });
    } else {
        callback.onContinue(postcard);
    }
}
```





```java
 private static void _execute(final int index, final CancelableCountDownLatch counter, final Postcard postcard) {
        if (index < Warehouse.interceptors.size()) {
            // 我们自定义的拦截器
            IInterceptor iInterceptor = Warehouse.interceptors.get(index);
            iInterceptor.process(postcard, new InterceptorCallback() {
                @Override
                public void onContinue(Postcard postcard) {
                    // Last interceptor excute over with no exception.
                    counter.countDown();
                    // 处理完成，交给下一个拦截器
                    _execute(index + 1, counter, postcard);  // When counter is down, it will be execute continue ,but index bigger than interceptors size, then U know.
                }

                @Override
                public void onInterrupt(Throwable exception) {
                    // Last interceptor execute over with fatal exception.

                    postcard.setTag(null == exception ? new HandlerException("No message.") : exception);    // save the exception message for backup.
                    counter.cancel();
                    // Be attention, maybe the thread in callback has been changed,
                    // then the catch block(L207) will be invalid.
                    // The worst is the thread changed to main thread, then the app will be crash, if you throw this exception!
//                    if (!Looper.getMainLooper().equals(Looper.myLooper())) {    // You shouldn't throw the exception if the thread is main thread.
//                        throw new HandlerException(exception.getMessage());
//                    }
                }
            });
        }
    }
```





## inject

依赖注入，经过 Autowired 注解的 类，会自动生成类似下面这样的类，先获取Test3Activity这个类名，利用这个类名追加 `  $ $ARouter$$Autowired,会得到


Test3Activity$ $ARouter$$Autowired 这个类，实例化这个对象，调用这个对象中的inject方法，参数就是 Test3Activity 对象。



![image-20210513234722439](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513234722439.png)



![image-20210513234800196](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210513234800196.png)



调用inject会



```java
public void inject(Object thiz) {
    _ARouter.inject(thiz);
}
```

```java
static void inject(Object thiz) {
    AutowiredService autowiredService = ((AutowiredService) ARouter.getInstance().build("/arouter/service/autowired").navigation());
    if (null != autowiredService) {
        autowiredService.autowire(thiz);
    }
}
```



```java
@Route(path = "/arouter/service/autowired")
public class AutowiredServiceImpl implements AutowiredService {
    private LruCache<String, ISyringe> classCache;
    private List<String> blackList;

    @Override
    public void init(Context context) {
        classCache = new LruCache<>(50);
        blackList = new ArrayList<>();
    }

    @Override
    public void autowire(Object instance) {
        doInject(instance, null);
    }

    /**
     * Recursive injection
     *
     * @param instance who call me.
     * @param parent   parent of me.
     */
    private void doInject(Object instance, Class<?> parent) {
        Class<?> clazz = null == parent ? instance.getClass() : parent;

        ISyringe syringe = getSyringe(clazz);
        if (null != syringe) {
            syringe.inject(instance);
        }

        Class<?> superClazz = clazz.getSuperclass();
        // has parent and its not the class of framework.
        if (null != superClazz && !superClazz.getName().startsWith("android")) {
            doInject(instance, superClazz);
        }
    }

    private ISyringe getSyringe(Class<?> clazz) {
        String className = clazz.getName();

        try {
            if (!blackList.contains(className)) {
                ISyringe syringeHelper = classCache.get(className);
                if (null == syringeHelper) {  // No cache.
                    syringeHelper = (ISyringe) Class.forName(clazz.getName() + SUFFIX_AUTOWIRED).getConstructor().newInstance();
                }
                classCache.put(className, syringeHelper);
                return syringeHelper;
            }
        } catch (Exception e) {
            blackList.add(className);    // This instance need not autowired.
        }

        return null;
    }
}
```





































































