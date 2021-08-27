### 查看依赖树

 ```.\gradlew.bat :app:dependencies --configuration implementation ```

![image-20210201102208821](.\img\image-20210201102208821.png)



![image-20210201102341086](.\img\image-20210201102341086.png)

https://docs.gradle.org/current/userguide/viewing_debugging_dependencies.html

`+ ---` 是一个库分支的开始

`|` 表示继续显示这个库所依赖的分支

`\---` 表示分支的结束

`(*)` 在一个库的后面表示这个库的更多依赖没有显示，因为它们已经在其他子树中列出来了。

`->` 在 Gradle 中如果多个库依赖于相同的库的不同版本，那么它会做出选择。包含库的不同版本是不合理的。因此，Gradle 默认选择那个库的最新版本

 ![image-20210201110854698](.\img\image-20210201110854698.png)



```.\gradlew.bat :libCommon:dependencies --configuration releaseCompileClasspath```

![image-20210201111056291](.\img\image-20210201111056291.png)





```.\gradlew.bat :libCommon:androidDependencies```

```java
> Configure project :app
useNewCruncher has been deprecated. It will be removed in a future version of the gradle plugin. New cruncher is now always enabled.
WARNING: DSL element 'android.viewBinding.enabled' is obsolete and has been replaced with 'android.buildFeatures.viewBinding'.
It will be removed in version 5.0 of the Android Gradle plugin.

> Task :libCommon:androidDependencies
debug
debugCompileClasspath - Dependencies for compilation
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
+--- com.umeng.umsdk:crash:0.0.4@aar
...省略...
\--- org.reactivestreams:reactive-streams:1.0.3@jar

debugRuntimeClasspath - Dependencies for runtime/packaging
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
+--- androidx.constraintlayout:constraintlayout:2.0.4@aar
...省略...
+--- org.jetbrains.kotlin:kotlin-stdlib-common:1.4.10@jar
\--- org.jetbrains:annotations:13.0@jar

release
releaseCompileClasspath - Dependencies for compilation
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
+--- androidx.constraintlayout:constraintlayout:2.0.4@aar
...省略...
\--- org.reactivestreams:reactive-streams:1.0.3@jar

releaseRuntimeClasspath - Dependencies for runtime/packaging
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
...省略...
+--- org.jetbrains.kotlin:kotlin-stdlib-common:1.4.10@jar
\--- org.jetbrains:annotations:13.0@jar

debugAndroidTest
debugAndroidTestCompileClasspath - Dependencies for compilation
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
+--- :libCommon (variant: debug)
...省略...
+--- org.jetbrains:annotations:13.0@jar
+--- androidx.annotation:annotation-experimental:1.0.0@aar
+--- androidx.databinding:databinding-common:4.1.0-rc03@jar
\--- org.reactivestreams:reactive-streams:1.0.3@jar

debugAndroidTestRuntimeClasspath - Dependencies for runtime/packaging
+--- :libCommon (variant: debug)
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
...省略...
+--- com.google.code.findbugs:jsr305:2.0.1@jar
\--- org.hamcrest:hamcrest-core:1.3@jar

debugUnitTest
debugUnitTestCompileClasspath - Dependencies for compilation
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
+--- :libCommon (variant: debug)
..
+--- androidx.databinding:databinding-common:4.1.0-rc03@jar
\--- org.reactivestreams:reactive-streams:1.0.3@jar

debugUnitTestRuntimeClasspath - Dependencies for runtime/packaging
+--- :libCommon (variant: debug)
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
...省略...
+--- org.reactivestreams:reactive-streams:1.0.3@jar
+--- org.jetbrains.kotlin:kotlin-stdlib-common:1.4.10@jar
\--- org.jetbrains:annotations:13.0@jar

releaseUnitTest
releaseUnitTestCompileClasspath - Dependencies for compilation
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
+--- :libCommon (variant: release)
...省略...
\--- org.reactivestreams:reactive-streams:1.0.3@jar

releaseUnitTestRuntimeClasspath - Dependencies for runtime/packaging
+--- :libCommon (variant: release)
+--- D:\android\project\Build110\libCommon\libs\commons-io-2.4.jar
...省略...
+--- org.jetbrains.kotlin:kotlin-stdlib-common:1.4.10@jar
\--- org.jetbrains:annotations:13.0@jar

BUILD SUCCESSFUL in 2s
1 actionable task: 1 executed
```