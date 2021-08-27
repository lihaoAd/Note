## 下载repo

直接到下面网站下载文件，repo就是一个python文件，下载下来直接用python运行即可

```java
https://storage.googleapis.com/git-repo-downloads/repo 
```

下载完成后，把  **REPO_URL = 'https://gerrit.googlesource.com/git-repo'** 修改为**REPO_URL = 'https://gerrit-googlesource.proxy.ustclug.org/git-repo'**

![image-20210818231325628](/img/image-20210818231325628.png)

## init

既然是python脚本，就直接运行即可，前提是先安装python,切换到该目录中，直接运行，使用**-b**指定下载某个分支 ，[分支查询](https://blog.csdn.net/L25000/article/details/118864791)

```java
python repo init -u git://mirrors.ustc.edu.cn/aosp/platform/manifest -b android-1.6_r1.2 --depth=1
```

## sync

接下来就简单了

```java
python repo sync
```

