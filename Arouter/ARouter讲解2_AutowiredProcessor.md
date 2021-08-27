# Autowired



```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.CLASS)
public @interface Autowired {

    // Mark param's name or service name.
    String name() default "";

    // If required, app will be crash when value is null.
    // Primitive type wont be check!
    boolean required() default false;

    // Description of the field
    String desc() default "";
}
```



## 概述

Autowired的对用是对字段进行注入，要不然就要用 getIntent().getIntExtra()之类的方法。这也会生成一个新的类，注入的操作也就在这个类中操作。就如同类似下面的类

![image-20210511230216155](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210511230216155.png)



## 详解



```java
// Autowired 注解用在字段上，字段在类或者接口里，这里的HashMap中的key就是类或者接口，value是这个类里被Autowired注解的元素
private Map<TypeElement, List<Element>> parentAndChild = new HashMap<>();


public boolean process(Set<? extends TypeElement> set, RoundEnvironment roundEnvironment) {
    if (CollectionUtils.isNotEmpty(set)) {
        try {
            this.categories(roundEnvironment.getElementsAnnotatedWith(Autowired.class));
            this.generateHelper();
        } catch (Exception var4) {
            this.logger.error(var4);
        }

        return true;
    } else {
        return false;
    }
}


// 方法里的 elements 参数是字段元素，是字段一般都是在类或者接口里面
private void categories(Set<? extends Element> elements) throws IllegalAccessException {
        if (CollectionUtils.isNotEmpty(elements)) {
            for (Element element : elements) {
                // 获取这个字段所在的类或接口
                TypeElement enclosingElement = (TypeElement) element.getEnclosingElement();
				// 该类或者接口不能被 private 修饰
                if (element.getModifiers().contains(Modifier.PRIVATE)) {
                    throw new IllegalAccessException("The inject fields CAN NOT BE 'private'!!! please check field ["
                            + element.getSimpleName() + "] in class [" + enclosingElement.getQualifiedName() + "]");
                }
                
                if (parentAndChild.containsKey(enclosingElement)) { // Has categries
                    parentAndChild.get(enclosingElement).add(element);
                } else {
                    List<Element> childs = new ArrayList<>();
                    childs.add(element);
                    parentAndChild.put(enclosingElement, childs);
                }
            }

            logger.info("categories finished.");
        }
    }

```

![image-20210511215138090](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210511215138090.png)



parentAndChild就是收集类中所有被Autowired 注解的字段。

```java
package com.alibaba.android.arouter.facade.template;

public interface ISyringe {
    void inject(Object target);
}
```

```java
private void generateHelper() throws IOException, IllegalAccessException {

    // 先准备一些element
    // com.alibaba.android.arouter.facade.template.ISyringe
    TypeElement type_ISyringe = elementUtils.getTypeElement(ISYRINGE);
    // com.alibaba.android.arouter.facade.service.SerializationService  这个是一个 IProvider ，我们后面讲
    TypeElement type_JsonService = elementUtils.getTypeElement(JSON_SERVICE);
    
    // com.alibaba.android.arouter.facade.template.IProvider
    TypeMirror iProvider = elementUtils.getTypeElement(Consts.IPROVIDER).asType();
    
    // android.app.Activity
    TypeMirror activityTm = elementUtils.getTypeElement(Consts.ACTIVITY).asType();
    
    // android.app.Fragment
    TypeMirror fragmentTm = elementUtils.getTypeElement(Consts.FRAGMENT).asType();
    
    // android.support.v4.app.Fragment
    TypeMirror fragmentTmV4 = elementUtils.getTypeElement(Consts.FRAGMENT_V4).asType();

    
    // Build input param name.
    // 方法的参数类型与参数名
    ParameterSpec objectParamSpec = ParameterSpec.builder(TypeName.OBJECT, "target").build();

    if (MapUtils.isNotEmpty(parentAndChild)) {
        // 遍历一个每一个类内部带有Autowired 注解的字段
        for (Map.Entry<TypeElement, List<Element>> entry : parentAndChild.entrySet()) {
            // Build method : 'inject'
            // 构建一个方法，public void inject(Object target)
            MethodSpec.Builder injectMethodBuilder = MethodSpec.methodBuilder(METHOD_INJECT)
                    .addAnnotation(Override.class)
                    .addModifiers(PUBLIC)
                    .addParameter(objectParamSpec);

            TypeElement parent = entry.getKey();
            List<Element> childs = entry.getValue();

            // 该类的全限定名
            String qualifiedName = parent.getQualifiedName().toString();
            // 类的包名
            String packageName = qualifiedName.substring(0, qualifiedName.lastIndexOf("."));
            // 类的名字，注意 生成薪的类的后面追加了 $$ARouter$$Autowired
            String fileName = parent.getSimpleName() + NAME_OF_AUTOWIRED;


            // 构建一个类，实现 ISyringe 接口，访问方式是public
            TypeSpec.Builder helper = TypeSpec.classBuilder(fileName)
                    .addJavadoc(WARNING_TIPS)
                    .addSuperinterface(ClassName.get(type_ISyringe))
                    .addModifiers(PUBLIC);

            // 添加一个成员变量 serializationService
            FieldSpec jsonServiceField = FieldSpec.builder(TypeName.get(type_JsonService.asType()), "serializationService", Modifier.PRIVATE).build();
            helper.addField(jsonServiceField);

            // 在inject 方法内部
            // serializationService = ARouter.getInstance().navigation(SerializationService.class);
            // serializationService 的作用是序列化对象，将对象转换成json进行传递
            injectMethodBuilder.addStatement("serializationService = $T.getInstance().navigation($T.class)", ARouterClass, ClassName.get(type_JsonService));
            injectMethodBuilder.addStatement("$T substitute = ($T)target", ClassName.get(parent), ClassName.get(parent));

            // Generate method body, start inject.
            for (Element element : childs) {
                Autowired fieldConfig = element.getAnnotation(Autowired.class);
                // 元素的名字
                String fieldName = element.getSimpleName().toString();
                
                if (types.isSubtype(element.asType(), iProvider)) {  // It's provider
                    // 如果 element 是 IProvider 的子类
                    if ("".equals(fieldConfig.name())) {    // User has not set service path, then use byType.

                        // Getter
                        //  substitute.{fieldName} = ARouter.getInstance().navigation( {elementClass}.class),{}表示占位
                        injectMethodBuilder.addStatement(
                                "substitute." + fieldName + " = $T.getInstance().navigation($T.class)",
                                ARouterClass,
                                ClassName.get(element.asType())
                        );
                    } else {    // use byName
                        // Getter
                          //  substitute.{fieldName} =({elementClass}) ARouter.getInstance().build({ConfigName}).navigation()
                        injectMethodBuilder.addStatement(
                                "substitute." + fieldName + " = ($T)$T.getInstance().build($S).navigation()",
                                ClassName.get(element.asType()),
                                ARouterClass,
                                fieldConfig.name()
                        );
                    }

                    // Validator
                    if (fieldConfig.required()) {
                        // 如果 required 是true，注入后需要检查是不是null
                        injectMethodBuilder.beginControlFlow("if (substitute." + fieldName + " == null)");
                        injectMethodBuilder.addStatement(
                                "throw new RuntimeException(\"The field '" + fieldName + "' is null, in class '\" + $T.class.getName() + \"!\")", ClassName.get(parent));
                        injectMethodBuilder.endControlFlow();
                    }
                } else {    // It's normal intent value
                   
                    String originalValue = "substitute." + fieldName;
                    String statement = "substitute." + fieldName + " = " + buildCastCode(element) + "substitute.";
                    boolean isActivity = false;
                    if (types.isSubtype(parent.asType(), activityTm)) {  // Activity, then use getIntent()
                        // 类似 这样   substitute.age = substitute.getIntent().getIntExtra("age", substitute.age);
                        isActivity = true;
                        statement += "getIntent().";
                    } else if (types.isSubtype(parent.asType(), fragmentTm) || types.isSubtype(parent.asType(), fragmentTmV4)) {   // Fragment, then use getArguments()
                        // 类似  substitute.name = substitute.getArguments().getString("name", substitute.name);
                        statement += "getArguments().";
                    } else {
                        throw new IllegalAccessException("The field [" + fieldName + "] need autowired from intent, its parent must be activity or fragment!");
                    }

                    statement = buildStatement(originalValue, statement, typeUtils.typeExchange(element), isActivity, isKtClass(parent));
                    if (statement.startsWith("serializationService.")) {   // Not mortals
                        injectMethodBuilder.beginControlFlow("if (null != serializationService)");
                        injectMethodBuilder.addStatement(
                                "substitute." + fieldName + " = " + statement,
                                (StringUtils.isEmpty(fieldConfig.name()) ? fieldName : fieldConfig.name()),
                                ClassName.get(element.asType())
                        );
                        injectMethodBuilder.nextControlFlow("else");
                        injectMethodBuilder.addStatement(
                                "$T.e(\"" + Consts.TAG + "\", \"You want automatic inject the field '" + fieldName + "' in class '$T' , then you should implement 'SerializationService' to support object auto inject!\")", AndroidLog, ClassName.get(parent));
                        injectMethodBuilder.endControlFlow();
                    } else {
                        injectMethodBuilder.addStatement(statement, StringUtils.isEmpty(fieldConfig.name()) ? fieldName : fieldConfig.name());
                    }

                    // Validator
                    if (fieldConfig.required() && !element.asType().getKind().isPrimitive()) {  // Primitive wont be check.
                        injectMethodBuilder.beginControlFlow("if (null == substitute." + fieldName + ")");
                        injectMethodBuilder.addStatement(
                                "$T.e(\"" + Consts.TAG + "\", \"The field '" + fieldName + "' is null, in class '\" + $T.class.getName() + \"!\")", AndroidLog, ClassName.get(parent));
                        injectMethodBuilder.endControlFlow();
                    }
                }
            }

            helper.addMethod(injectMethodBuilder.build());

            // Generate autowire helper
            JavaFile.builder(packageName, helper.build()).build().writeTo(mFiler);

            logger.info(">>> " + parent.getSimpleName() + " has been processed, " + fileName + " has been generated. <<<");
        }

        logger.info(">>> Autowired processor stop. <<<");
    }
}
```

最后生成的类就类似下面这样

![image-20210511223609007](C:\Users\LIHAO\Desktop\Slash\Arouter\image-20210511223609007.png)

