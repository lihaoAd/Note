## 简述

使用的Gradle版本是6.2.2



## Gradle启动

在gradle项目中会有`gradlew` 与`gradlew.bat`两个文件，前者用于Unix,后者用于windows。

就拿windows环境来说，当我们输入`gradlew`命令时，就会执行`gradlew.bat`脚本。

就会执行到这条命令

````c#
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %CMD_LINE_ARGS%
````

- JAVA_EXE的值就是 java.exe
- DEFAULT_JVM_OPTS 默认为空
- JAVA_OPTS 默认为空
- GRADLE_OPTS 默认为空
- APP_BASE_NAME  就是gradlew
- CLASSPATH 就是gradle-wrapper.jar的路径
- CMD_LINE_ARGS 就是类似assemble这样的参数

这个命令就是执行` gradle-wrapper.jar`中的`org.gradle.wrapper.GradleWrapperMain`类

该类的源码位于`src\wrapper`

```java
 public static void main(String[] args) throws Exception {
 
 		// jar包路径
        File wrapperJar = wrapperJar();  
        //gradle-wrapper.properties 文件路径
        File propertiesFile = wrapperProperties(wrapperJar);
        // 项目路径
        File rootDir = rootDir(wrapperJar);

       // 命令行参数
        CommandLineParser parser = new CommandLineParser();
        parser.allowUnknownOptions();
        parser.option(GRADLE_USER_HOME_OPTION, GRADLE_USER_HOME_DETAILED_OPTION).hasArgument();
        parser.option(GRADLE_QUIET_OPTION, GRADLE_QUIET_DETAILED_OPTION);

        SystemPropertiesCommandLineConverter converter = new SystemPropertiesCommandLineConverter();
        converter.configure(parser);

        ParsedCommandLine options = parser.parse(args);

        Properties systemProperties = System.getProperties();
        systemProperties.putAll(converter.convert(options, new HashMap<String, String>()));

		// gradleUserHome 路径
        File gradleUserHome = gradleUserHome(options);

        addSystemProperties(gradleUserHome, rootDir);

        Logger logger = logger(options);

        WrapperExecutor wrapperExecutor = WrapperExecutor.forWrapperPropertiesFile(propertiesFile);
        wrapperExecutor.execute(
                args,
                new Install(logger, new Download(logger, "gradlew", UNKNOWN_VERSION), new PathAssembler(gradleUserHome)),
                new BootstrapMainStarter());
    }
```



```java
private static File gradleUserHome(ParsedCommandLine options) {
        if (options.hasOption(GRADLE_USER_HOME_OPTION)) {
            // 如果使用 g 指定gradle home ，就用这个
            return new File(options.option(GRADLE_USER_HOME_OPTION).getValue());
        }
        return GradleUserHomeLookup.gradleUserHome();
}
```



```java
public class GradleUserHomeLookup {
    public static final String DEFAULT_GRADLE_USER_HOME = System.getProperty("user.home") + "/.gradle";
    public static final String GRADLE_USER_HOME_PROPERTY_KEY = "gradle.user.home";
    public static final String GRADLE_USER_HOME_ENV_KEY = "GRADLE_USER_HOME";

    public static File gradleUserHome() {
        String gradleUserHome;
        if ((gradleUserHome = System.getProperty(GRADLE_USER_HOME_PROPERTY_KEY)) != null) {
            return new File(gradleUserHome);
        }
        if ((gradleUserHome = System.getenv(GRADLE_USER_HOME_ENV_KEY)) != null) {
            return new File(gradleUserHome);
        }
        return new File(DEFAULT_GRADLE_USER_HOME);
    }
}
```

先根据`gradle.user.home`系统属性获取路径，如果没有就从`GRADLE_USER_HOME`环境变量中获取，如果还没有就从`user.home`系统属性中获取。如果想修改gradle文件下载路径，就可以从这里修改。

到`org.gradle.wrapper.WrapperExecutor`中分析

````v
    public static final String DISTRIBUTION_URL_PROPERTY = "distributionUrl";
    public static final String DISTRIBUTION_BASE_PROPERTY = "distributionBase";
    public static final String DISTRIBUTION_PATH_PROPERTY = "distributionPath";
    public static final String DISTRIBUTION_SHA_256_SUM = "distributionSha256Sum";
    public static final String ZIP_STORE_BASE_PROPERTY = "zipStoreBase";
    public static final String ZIP_STORE_PATH_PROPERTY = "zipStorePath";
````

这个是和我们gradle-wrapper.properties文件中的类似

````java
 public static WrapperExecutor forWrapperPropertiesFile(File propertiesFile) {
        if (!propertiesFile.exists()) {
            throw new RuntimeException(String.format("Wrapper properties file '%s' does not exist.", propertiesFile));
        }
        return new WrapperExecutor(propertiesFile, new Properties());
    }
````

```java
WrapperExecutor(File propertiesFile, Properties properties) {
        this.properties = properties;
        this.propertiesFile = propertiesFile; // 我们的gradle-wrapper.properties文件
        if (propertiesFile.exists()) {
            try {
                // 把gradle-wrapper.properties文件中的值加载到 properties中
                loadProperties(propertiesFile, properties);
                
                // distributionUrl=https\://services.gradle.org/distributions/gradle-6.2.2-bin.zip
                config.setDistribution(prepareDistributionUri());
                
                // distributionBase=GRADLE_USER_HOME
                config.setDistributionBase(getProperty(DISTRIBUTION_BASE_PROPERTY, config.getDistributionBase()));
                
                // distributionPath=wrapper/dists
                config.setDistributionPath(getProperty(DISTRIBUTION_PATH_PROPERTY, config.getDistributionPath()));
                
                // 没有
                config.setDistributionSha256Sum(getProperty(DISTRIBUTION_SHA_256_SUM, config.getDistributionSha256Sum(), false));
                
                // zipStoreBase=GRADLE_USER_HOME
                config.setZipBase(getProperty(ZIP_STORE_BASE_PROPERTY, config.getZipBase()));
                
                // zipStorePath=wrapper/dists
                config.setZipPath(getProperty(ZIP_STORE_PATH_PROPERTY, config.getZipPath()));
            } catch (Exception e) {
                throw new RuntimeException(String.format("Could not load wrapper properties from '%s'.", propertiesFile), e);
            }
        }
    }
```

上面已经把路径准备好



```java
 public void execute(String[] args, Install install, BootstrapMainStarter bootstrapMainStarter) throws Exception {
        File gradleHome = install.createDist(config);
        bootstrapMainStarter.start(args, gradleHome);
    }
```



