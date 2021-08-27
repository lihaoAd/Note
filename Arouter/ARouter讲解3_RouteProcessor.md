## Route

```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.CLASS)
public @interface Route {

    String path();
    String group() default "";
    String name() default "";
    int extras() default Integer.MIN_VALUE;
    int priority() default -1;
}
```

- path ：不能为空，而且必须以 “/”开头，
- group ：可以自己设置group的值，默认在path中获取，比如  @Route(path = "/test/activity1")，在构建 RouteMeta 时就会用test作为组名。
- name ：生成文档用的
- extras：可以带一些额外的参数
- priority： 优先级，值越小，优先级越高

## 概述

通过 Route 的注解，框架会把我们注解的Activity 、Fragment、Service、ContentProvider以及IProvider收集起来

![image-20210512234509772](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210512234509772.png)



按照不同的Group会生成类似这样的代码，这样框架在初始化的时候，就可以根据这些类把路由信息收集起来。

![image-20210512234700592](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210512234700592.png)



## 详情



~~~java
@Override
public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
    if (CollectionUtils.isNotEmpty(annotations)) {
        // 获取所有被 Route 注解的类
        Set<? extends Element> routeElements = roundEnv.getElementsAnnotatedWith(Route.class);
        try {=
            this.parseRoutes(routeElements);
        } catch (Exception e) {
            logger.error(e);
        }
        return true;
    }

    return false;
}



private void parseRoutes(Set<? extends Element> routeElements) throws IOException {
        if (CollectionUtils.isNotEmpty(routeElements)) {
            
            rootMap.clear();
            
            TypeMirror type_Activity = elementUtils.getTypeElement(ACTIVITY).asType();
            TypeMirror type_Service = elementUtils.getTypeElement(SERVICE).asType();
            TypeMirror fragmentTm = elementUtils.getTypeElement(FRAGMENT).asType();
            TypeMirror fragmentTmV4 = elementUtils.getTypeElement(Consts.FRAGMENT_V4).asType();

            // Interface of ARouter
            // com.alibaba.android.arouter.facade.template.IRouteGroup
            TypeElement type_IRouteGroup = elementUtils.getTypeElement(IROUTE_GROUP);
            // com.alibaba.android.arouter.facade.template.IProviderGroup
            TypeElement type_IProviderGroup = elementUtils.getTypeElement(IPROVIDER_GROUP);
            ClassName routeMetaCn = ClassName.get(RouteMeta.class);
            ClassName routeTypeCn = ClassName.get(RouteType.class);

            /*
               Build input type, format as :

               ```Map<String, Class<? extends IRouteGroup>>```
             */
            // 方法的参数类型
            ParameterizedTypeName inputMapTypeOfRoot = ParameterizedTypeName.get(
                    ClassName.get(Map.class),
                    ClassName.get(String.class),
                    ParameterizedTypeName.get(
                            ClassName.get(Class.class),
                            WildcardTypeName.subtypeOf(ClassName.get(type_IRouteGroup))
                    )
            );

            /*

              ```Map<String, RouteMeta>```
             */
             // 方法的参数类型
            ParameterizedTypeName inputMapTypeOfGroup = ParameterizedTypeName.get(
                    ClassName.get(Map.class),
                    ClassName.get(String.class),
                    ClassName.get(RouteMeta.class)
            );

            /*
              Build input param name.
             */
            // 方法的参数名
            ParameterSpec rootParamSpec = ParameterSpec.builder(inputMapTypeOfRoot, "routes").build();
            ParameterSpec groupParamSpec = ParameterSpec.builder(inputMapTypeOfGroup, "atlas").build();
            ParameterSpec providerParamSpec = ParameterSpec.builder(inputMapTypeOfGroup, "providers").build();  

            /*
              Build method : 'loadInto'
             */
            // 构建一个方法  public void loadInto(Map<String, Class<? extends IRouteGroup>> routes)
            MethodSpec.Builder loadIntoMethodOfRootBuilder = MethodSpec.methodBuilder(METHOD_LOAD_INTO)
                    .addAnnotation(Override.class)
                    .addModifiers(PUBLIC)
                    .addParameter(rootParamSpec);

            //  Follow a sequence, find out metas of group first, generate java file, then statistics them as root.
            // 遍历被Route注解的类
            for (Element element : routeElements) {
                TypeMirror tm = element.asType();
                Route route = element.getAnnotation(Route.class);
                RouteMeta routeMeta;

                // 构建 RouteMeta
                // 因为Activity 或者 Fragment 是可以传递参数的，getIntent()、getArguments(),就收集该类中被 Autowired 注解的字段
                // Activity or Fragment
                if (types.isSubtype(tm, type_Activity) || types.isSubtype(tm, fragmentTm) || types.isSubtype(tm, fragmentTmV4)) {
                    // 当前的类是 Activity 或  Fragment
                    
                    // Get all fields annotation by @Autowired
                    // paramsType 与 injectConfig 用来生成文档的，不用关心
                    Map<String, Integer> paramsType = new HashMap<>();
                    Map<String, Autowired> injectConfig = new HashMap<>();
                    //收集类中的被Autowired注解的字段，但字段不能是IProvider类型
                    injectParamCollector(element, paramsType, injectConfig);

                    
                    
                    if (types.isSubtype(tm, type_Activity)) {
                        // Activity
                        routeMeta = new RouteMeta(route, element, RouteType.ACTIVITY, paramsType);
                    } else {
                        // Fragment
                        routeMeta = new RouteMeta(route, element, RouteType.parse(FRAGMENT), paramsType);
                    }

                    routeMeta.setInjectConfig(injectConfig);
                } else if (types.isSubtype(tm, iProvider)) {         // IProvider
                    routeMeta = new RouteMeta(route, element, RouteType.PROVIDER, null);
                } else if (types.isSubtype(tm, type_Service)) {           // Service
                    routeMeta = new RouteMeta(route, element, RouteType.parse(SERVICE), null);
                } else {
                    throw new RuntimeException("The @Route is marked on unsupported class, look at [" + tm.toString() + "].");
                }
				// 收集具有相同的group的RouteMeta到 Map<String, Set<RouteMeta>>
                categories(routeMeta);
            }

            // 生成 loadInto  方法
            // public void loadInto(Map<Integer, Class<? extends IInterceptor>> interceptors)
            MethodSpec.Builder loadIntoMethodOfProviderBuilder = MethodSpec.methodBuilder(METHOD_LOAD_INTO)
                    .addAnnotation(Override.class)
                    .addModifiers(PUBLIC)
                    .addParameter(providerParamSpec);

           

            // Start generate java source, structure is divided into upper and lower levels, used for demand initialization.
            for (Map.Entry<String, Set<RouteMeta>> entry : groupMap.entrySet()) {
                
                String groupName = entry.getKey();

                //public void loadInto(Map<String, RouteMeta> atlas)
                MethodSpec.Builder loadIntoMethodOfGroupBuilder = MethodSpec.methodBuilder(METHOD_LOAD_INTO)
                        .addAnnotation(Override.class)
                        .addModifiers(PUBLIC)
                        .addParameter(groupParamSpec);

                // Build group method body
                Set<RouteMeta> groupData = entry.getValue();
                for (RouteMeta routeMeta : groupData) {

                    // 这个ClassName就是被Route注解的类名
                    ClassName className = ClassName.get((TypeElement) routeMeta.getRawType());

                    //这是给 IProvider 的类型做了一次特殊服务
                    
                    switch (routeMeta.getType()) {
                        case PROVIDER:  // Need cache provider's super class
							// 注意 routeMeta 返回的是RouteType类型，比如 PROVIDER类型，就是说element是 IProvider 的子类。
                            // 获取这个TypeElement的直接父接口
                            // 比如我们一般定义XXXServiceImpl， XXXService ，然后XXXService接口继承自IProvider
                            List<? extends TypeMirror> interfaces = ((TypeElement) routeMeta.getRawType()).getInterfaces();
                            // 遍历这个父接口
                            for (TypeMirror tm : interfaces) {

                                if (types.isSameType(tm, iProvider)) {   // Its implements iProvider interface himself.
                                    // This interface extend the IProvider, so it can be used for mark provider
                                    // 该element是 IProvider的直接子类
                                    
                                    // 就会生成类似  providers.put("com.alibaba.android.arouter.demo.module1.testservice.SingleService",
                                    // RouteMeta.build(RouteType.PROVIDER, SingleService.class, "/yourservicegroupname/single",                                                 // "yourservicegroupname", null, -1, -2147483648));
                                    loadIntoMethodOfProviderBuilder.addStatement(
                                            "providers.put($S, $T.build($T." + routeMeta.getType() + ", $T.class, $S, $S, null, " + routeMeta.getPriority() + ", " + routeMeta.getExtra() + "))",
                                            (routeMeta.getRawType()).toString(),
                                            routeMetaCn,
                                            routeTypeCn,
                                            className,
                                            routeMeta.getPath(),
                                            routeMeta.getGroup());
                                    
                                } else if (types.isSubtype(tm, iProvider)) {
                                    
                                    // This interface extend the IProvider, so it can be used for mark provider
                                    // 类似这样 providers.put("com.alibaba.android.arouter.demo.service.HelloService", 
                                    // RouteMeta.build(RouteType.PROVIDER, HelloServiceImpl.class, "/yourservicegroupname/hello",
                                    // "yourservicegroupname", null, -1, -2147483648));
                                    
                                    loadIntoMethodOfProviderBuilder.addStatement(
                                            "providers.put($S, $T.build($T." + routeMeta.getType() + ", $T.class, $S, $S, null, " + routeMeta.getPriority() + ", " + routeMeta.getExtra() + "))",
                                            tm.toString(),    // So stupid, will duplicate only save class name.
                                            routeMetaCn,
                                            routeTypeCn,
                                            className,
                                            routeMeta.getPath(),
                                            routeMeta.getGroup());
                                }
                            }
                            break;
                        default:
                            break;
                    }

                    // Make map body for paramsType
                   ....... 省略一部分代码........
                }

                // Generate groups
                // ARouter$$Group$$groupName
                // 见图ARouter$$Group$$groupName
                String groupFileName = NAME_OF_GROUP + groupName;
                JavaFile.builder(PACKAGE_OF_GENERATE_FILE,  // com.alibaba.android.arouter.routes
                        TypeSpec.classBuilder(groupFileName)
                                .addJavadoc(WARNING_TIPS)
                                .addSuperinterface(ClassName.get(type_IRouteGroup))
                                .addModifiers(PUBLIC)
                                .addMethod(loadIntoMethodOfGroupBuilder.build())
                                .build()
                ).build().writeTo(mFiler);
                
                // 组名和用组名生成的类缓存起来
                rootMap.put(groupName, groupFileName);
               
            }

            if (MapUtils.isNotEmpty(rootMap)) {
                // Generate root meta by group name, it must be generated before root, then I can find out the class of group.
                for (Map.Entry<String, String> entry : rootMap.entrySet()) {
                     // 会生成类似这样的代码
                     //  routes.put("test", ARouter$$Group$$test.class);
                     //  routes.put("yourservicegroupname", ARouter$$Group$$yourservicegroupname.class);
                    loadIntoMethodOfRootBuilder.addStatement("routes.put($S, $T.class)", entry.getKey(), ClassName.get(PACKAGE_OF_GENERATE_FILE, entry.getValue()));
                }
            }

            // Output route doc
             ....... 省略一部分代码........

            // Write provider into disk
            // ARouter$$Providers$$moduleName
            // 见图ARouter$$Providers$$moduleName
            String providerMapFileName = NAME_OF_PROVIDER + SEPARATOR + moduleName;
            JavaFile.builder(PACKAGE_OF_GENERATE_FILE,  // com.alibaba.android.arouter.routes
                    TypeSpec.classBuilder(providerMapFileName)
                            .addJavadoc(WARNING_TIPS)
                            .addSuperinterface(ClassName.get(type_IProviderGroup))
                            .addModifiers(PUBLIC)
                            .addMethod(loadIntoMethodOfProviderBuilder.build())
                            .build()
            ).build().writeTo(mFiler);

            //  ARouter$$Root$$moduleName
            // 见图 ARouter$$Root$$moduleName
            String rootFileName = NAME_OF_ROOT + SEPARATOR + moduleName;
            JavaFile.builder(PACKAGE_OF_GENERATE_FILE,
                    TypeSpec.classBuilder(rootFileName)
                            .addJavadoc(WARNING_TIPS)
                            .addSuperinterface(ClassName.get(elementUtils.getTypeElement(ITROUTE_ROOT)))
                            .addModifiers(PUBLIC)
                            .addMethod(loadIntoMethodOfRootBuilder.build())
                            .build()
            ).build().writeTo(mFiler);
        }
    }



 private void injectParamCollector(Element element, Map<String, Integer> paramsType, Map<String, Autowired> injectConfig) {
        for (Element field : element.getEnclosedElements()) {
            // 获取 被Route 注解的类中的所有元素，主要是字段
            if (field.getKind().isField() && field.getAnnotation(Autowired.class) != null && !types.isSubtype(field.asType(), iProvider)) {
                // It must be field, then it has annotation, but it not be provider.
                // 是一个带有Autowired注解的字段，但不能是IProvider类型
                // 
                Autowired paramConfig = field.getAnnotation(Autowired.class);
                String injectName = StringUtils.isEmpty(paramConfig.name()) ? field.getSimpleName().toString() : paramConfig.name();
                paramsType.put(injectName, typeUtils.typeExchange(field));
                injectConfig.put(injectName, paramConfig);
            }
        }

        // 是不是还有父类
        TypeMirror parent = ((TypeElement) element).getSuperclass();
        if (parent instanceof DeclaredType) {
            // 一个类或者接口
            Element parentElement = ((DeclaredType) parent).asElement();
            if (parentElement instanceof TypeElement && !((TypeElement) parentElement).getQualifiedName().toString().startsWith("android")) {
                injectParamCollector(parentElement, paramsType, injectConfig);
            }
        }
    }


// 把具有相同group的 RouteMeta 放在一个Set里
// Map<String, Set<RouteMeta>>
private void categories(RouteMeta routeMete) {
        // 设置路由path时必须是"/"开头，如果没有设置 group ，RouteMeta就会自动设置 group
        if (routeVerify(routeMete)) {
            // 排个序，把相同group的RouteMeta放在一个Set
            Set<RouteMeta> routeMetas = groupMap.get(routeMete.getGroup());
            if (CollectionUtils.isEmpty(routeMetas)) {
                Set<RouteMeta> routeMetaSet = new TreeSet<>(new Comparator<RouteMeta>() {
                    @Override
                    public int compare(RouteMeta r1, RouteMeta r2) {
                        try {
                            return r1.getPath().compareTo(r2.getPath());
                        } catch (NullPointerException npe) {
                            logger.error(npe.getMessage());
                            return 0;
                        }
                    }
                });
                routeMetaSet.add(routeMete);
                groupMap.put(routeMete.getGroup(), routeMetaSet);
            } else {
                routeMetas.add(routeMete);
            }
        } else {
            logger.warning(">>> Route meta verify error, group is " + routeMete.getGroup() + " <<<");
        }
    }
~~~



```java
// ARouter$$Group$$groupName
String groupFileName = NAME_OF_GROUP + groupName;
JavaFile.builder(PACKAGE_OF_GENERATE_FILE,  // com.alibaba.android.arouter.routes
        TypeSpec.classBuilder(groupFileName)
                .addJavadoc(WARNING_TIPS)
                .addSuperinterface(ClassName.get(type_IRouteGroup))
                .addModifiers(PUBLIC)
                .addMethod(loadIntoMethodOfGroupBuilder.build())
                .build()
).build().writeTo(mFiler);
```

上面的会生成类似这样的类

![图ARouter$$Group$$groupName](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210512230841403.png)



```java
// ARouter$$Providers$$moduleName
String providerMapFileName = NAME_OF_PROVIDER + SEPARATOR + moduleName;
JavaFile.builder(PACKAGE_OF_GENERATE_FILE,  // com.alibaba.android.arouter.routes
        TypeSpec.classBuilder(providerMapFileName)
                .addJavadoc(WARNING_TIPS)
                .addSuperinterface(ClassName.get(type_IProviderGroup))
                .addModifiers(PUBLIC)
                .addMethod(loadIntoMethodOfProviderBuilder.build())
                .build()
).build().writeTo(mFiler);
```

上面的会生成类似这样的类

![ARouter$$Providers$$moduleName](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210512231418206.png)





```java
//  ARouter$$Root$$moduleName
String rootFileName = NAME_OF_ROOT + SEPARATOR + moduleName;
JavaFile.builder(PACKAGE_OF_GENERATE_FILE,  //com.alibaba.android.arouter.routes
        TypeSpec.classBuilder(rootFileName)
                .addJavadoc(WARNING_TIPS)
                .addSuperinterface(ClassName.get(elementUtils.getTypeElement(ITROUTE_ROOT)))
                .addModifiers(PUBLIC)
                .addMethod(loadIntoMethodOfRootBuilder.build())
                .build()
).build().writeTo(mFiler);
```

上面的会生成类似这样的类

![ARouter$$Root$$moduleName](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210512231641905.png)



























































