## 安装git和curl

```java
sudo apt-get install git-core curl
```

## 建立AOSP目录

```java
mkdir ~/AOSP
cd ~/AOSP
```

AOSP随便你命名，就是一个目录，存放我们clone下来的源码

## 配置 Git

```java
git config --global user.name Your Name
git config --global user.email you@example.com
```

## 下载并配置repo

Repo 是我们建立在 Git 之上的工具。 Repo 帮助我们管理许多 Git 存储库，上传到我们的版本控制系统，并自动化部分 Android 开发工作流程。 Repo 并不是要取代 Git，只是为了让在 Android 环境中使用 Git 更容易。 repo 命令是一个可执行的 Python 脚本，您可以将其放在路径中的任何位置。

```java
mkdir ~/bin
cur https://storage.googleapis.com/git-repo-downloads/repo> ~/bin/repo
# 或者使用清华的镜像
# curl https://mirrors.tuna.tsinghua.edu.cn/git/git-repo > ~/bin/repo
# 或者使用科大的镜像
# curl -sSL  'https://gerrit-googlesource.proxy.ustclug.org/git-repo/+/master/repo?format=TEXT' |base64 -d >
# ~/bin/repo
# 使repo可执行    
chmod a+x ~/bin/repo
```

## 国内镜像

- [科大开源镜像站](https://mirrors.ustc.edu.cn/)

- [清华开源镜像站](https://mirrors.tuna.tsinghua.edu.cn/)
1. 不同地区（或不同运营商）的网络，从这两个镜像站下载代码的速度会有所差别；

2. 清华AOSP镜像只支持HTTPS协议下载，科大AOSP镜像同时支持git协议和HTTPS协议下载；（git协议下载更快一些，如果网络允许的话，优先选择科大镜像）；

3. 可以通过`curl -I`发送`HEAD`请求，简单测试一下哪个站点更优（使用`time`命令计时，时间短的更优）：

     - `time curl -I https://mirrors.ustc.edu.cn/`

     - `time curl -I https://mirrors.tuna.tsinghua.edu.cn/`  

## 初始化仓库

```java
repo init -u git://mirrors.ustc.edu.cn/aosp/platform/manifest
```

运行 `repo init` 获取最新版本的 Repo 及其最新的 bug 修复。清单文件指定了 Android 源代码中包含的各个代码库将放置到工作目录中的什么位置。

如需签出 master 分支，请运行以下命令：

```java
repo init -u https://android.googlesource.com/platform/manifest -b master
```

如需签出 master 之外的其他分支，请使用 `-b` 指定此分支。 如需查看分支列表，请参阅[源代码标记和 build](https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds)（或者见下面的表格）。

一般情况下我不会直接使用repo，我会这么用，直接指定使用python3运行脚本

```java
# 使用清华镜像
python3 ~/bin/repo init -u https://aosp.tuna.tsinghua.edu.cn/platform/manifest -b android-4.0.1_r1 --depth 1 --config
```

```java
# 使用科大镜像
python3 ~/bin/repo init -u git://mirrors.ustc.edu.cn/aosp/platform/manifest -b android-4.0.1_r1 --depth 1 --config
```

下载好的repo文件打开后有这么一段代码

```python
REPO_URL = os.environ.get('REPO_URL', None)
if not REPO_URL:
  REPO_URL = 'https://gerrit.googlesource.com/git-repo'
REPO_REV = os.environ.get('REPO_REV')
```

可以把REPO_URL添加到环境变量中，或者打开直接修改源码，把https://gerrit.googlesource.com/git-repo替换成国内镜像地址

```bash
# 科大
https://gerrit-googlesource.proxy.ustclug.org/git-repo
# 清华
https://mirrors.tuna.tsinghua.edu.cn/git/git-repo
```

## 开始同步

```java
python3 ~/bin/repo sync
```



|                    |                             |                    |                                                              |                  |
| :----------------- | :-------------------------- | :----------------- | :----------------------------------------------------------- | :--------------- |
| build ID           | 标记                        | 版本               | 支持的设备                                                   | 安全补丁程序级别 |
| RQ2A.210605.003    | android-11.0.0_r38          | Android11          | Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4 XL、Pixel 4a、Pixel 4a (5G)、Pixel 5 | 2021-06-05       |
| RQ2A.210505.003    | android-11.0.0_r37          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2021-05-05       |
| RQ2A.210505.002    | android-11.0.0_r36          | Android11          | Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4a、Pixel 4 XL | 2021-05-05       |
| RQ2A.210405.006    | android-11.0.0_r35          | Android11          | Pixel 3、Pixel 3 XL                                          | 2021-04-05       |
| RQ2A.210405.005    | android-11.0.0_r34          | Android11          | Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4a、Pixel 4a (5G)、Pixel 4 XL、Pixel 5 | 2021-04-05       |
| RQ2A.210305.007    | android-11.0.0_r33          | Android11          | Pixel 4a、Pixel 4a (5G)、Pixel 5                             | 2021-03-05       |
| RQ2A.210305.006    | android-11.0.0_r32          | Android11          | Pixel 3、Pixel 3 XL、Pixel 3a、Pixel 3a XL、Pixel 4、Pixel 4 XL、Pixel 4a、Pixel 4a (5G)、Pixel 5 | 2021-03-05       |
| RQ1D.210205.004    | android-11.0.0_r31          | Android11          | Pixel 3、Pixel 3 XL、Pixel 4a (5G)、Pixel 5                  | 2021-02-05       |
| RQ1C.210205.006    | android-11.0.0_r30          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2021-02-05       |
| RQ1A.210205.004    | android-11.0.0_r29          | Android11          | Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4a、Pixel 4a (5G)、Pixel 4 XL、Pixel 5 | 2021-02-05       |
| RQ1D.210105.003    | android-11.0.0_r28          | Android11          | Pixel 3、Pixel 3 XL、Pixel 4a (5G)、Pixel 5                  | 2021-01-05       |
| RQ1A.210105.003    | android-11.0.0_r27          | Android11          | Pixel 3、Pixel 3 XL、Pixel 4、Pixel 4a (5G)、Pixel 4 XL、Pixel 5 | 2021-01-05       |
| RQ1A.210105.002    | android-11.0.0_r26          | Android11          | Pixel 3a、Pixel 3a XL、Pixel 4a                              | 2021-01-05       |
| RP1A.201005.004.A1 | android-11.0.0_r25          | Android11          | Pixel 2、Pixel 2 XL                                          | 2020-10-05       |
| RQ1D.201205.012.A1 | android-11.0.0_r24          | Android11          | Pixel 5、Pixel 4a (5G)                                       | 2020-12-05       |
| RQ1A.201205.003.A1 | android-11.0.0_r23          | Android11          | Pixel 3、Pixel 3 XL                                          | 2020-12-05       |
| RQ1A.201205.011    | android-11.0.0_r22          | Android11          | Pixel 5、Pixel 4a (5G)                                       | 2020-12-05       |
| RQ1A.201205.008.A1 | android-11.0.0_r21          | Android11          | Pixel 4、Pixel 4 XL                                          | 2020-12-05       |
| RQ1A.201205.010    | android-11.0.0_r20          | Android11          | Pixel 5、Pixel 4a (5G)                                       | 2020-12-05       |
| RQ1A.201205.008    | android-11.0.0_r19          | Android11          | Pixel 4a、Pixel 4、Pixel 4 XL                                | 2020-12-05       |
| RQ1A.201205.003    | android-11.0.0_r18          | Android11          | Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 3                   | 2020-12-05       |
| RP1A.201105.002    | android-11.0.0_r17          | Android11          | Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4a、Pixel 4 XL | 2020-11-05       |
| RD1B.201105.010    | android-11.0.0_r16          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-11-05       |
| RD1A.201105.003.C1 | android-11.0.0_r15          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-11-05       |
| RD1A.201105.003.B1 | android-11.0.0_r14          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-11-05       |
| RD1A.201105.003.A1 | android-11.0.0_r13          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-11-05       |
| RD1A.201105.003    | android-11.0.0_r12          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-11-05       |
| RD1A.200810.022.A4 | android-11.0.0_r11          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-10-05       |
| RD1A.200810.021.B3 | android-11.0.0_r10          | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-10-05       |
| RD1A.200810.020.A1 | android-11.0.0_r9           | Android11          | Pixel 5                                                      | 2020-10-05       |
| RD1A.200810.021.A1 | android-11.0.0_r8           | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-10-05       |
| RD1A.200810.020    | android-11.0.0_r7           | Android11          | Pixel 4a (5G)、Pixel 5                                       | 2020-10-05       |
| RP1A.201005.006    | android-11.0.0_r5           | Android11          | Pixel 4a                                                     | 2020-10-05       |
| RP1A.201005.004    | android-11.0.0_r4           | Android11          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4 XL | 2020-10-05       |
| RP1A.200720.011    | android-11.0.0_r3           | Android11          | Pixel 4a                                                     | 2020-09-05       |
| RP1A.200720.010    | android-11.0.0_r2           | Android11          | Pixel 4a                                                     | 2020-09-05       |
| RP1A.200720.009    | android-11.0.0_r1           | Android11          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4 XL | 2020-09-05       |
| 7269719            | android-security-10.0.0_r55 | Android10          |                                                              | 2019-09-05       |
| 7250004            | android-security-10.0.0_r54 | Android10          |                                                              | 2019-09-05       |
| 7127522            | android-security-10.0.0_r53 | Android10          |                                                              | 2019-09-05       |
| 7070703            | android-security-10.0.0_r52 | Android10          |                                                              | 2019-09-05       |
| 7023426            | android-security-10.0.0_r51 | Android10          |                                                              | 2019-09-05       |
| 6969601            | android-security-10.0.0_r50 | Android10          |                                                              | 2019-09-05       |
| 6893682            | android-security-10.0.0_r49 | Android10          |                                                              | 2019-09-05       |
| 6878114            | android-security-10.0.0_r48 | Android10          |                                                              | 2019-09-05       |
| 6780337            | android-10.0.0_r47          | Android10          |                                                              | 2019-09-05       |
| 6777444            | android-10.0.0_r46          | Android10          |                                                              | 2019-09-05       |
| QD4A.200805.003    | android-10.0.0_r45          | Android10          | Pixel 4a                                                     | 2020-08-05       |
| QD4A.200805.001    | android-10.0.0_r44          | Android10          | Pixel 4a                                                     | 2020-08-05       |
| QD4A.200317.027    | android-10.0.0_r43          | Android10          | Pixel 4a                                                     | 2020-05-05       |
| QD4A.200317.024.A1 | android-10.0.0_r42          | Android10          | Pixel 4a                                                     | 2020-05-05       |
| QQ3A.200805.001    | android-10.0.0_r41          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4 XL | 2020-08-05       |
| QQ3A.200705.002    | android-10.0.0_r40          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3a、Pixel 3a XL、Pixel 3 XL、Pixel 4、Pixel 4 XL | 2020-07-05       |
| QQ3A.200605.002.A1 | android-10.0.0_r39          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3 XL、Pixel 3a、Pixel 3a XL、Pixel 4、Pixel 4 XL | 2020-06-05       |
| QQ3A.200605.002    | android-10.0.0_r38          | Android10          | Pixel 3a、Pixel 3a XL                                        | 2020-06-05       |
| QQ3A.200605.001    | android-10.0.0_r37          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3 XL、Pixel 4、Pixel 4 XL | 2020-06-05       |
| QQ2A.200501.001.B3 | android-10.0.0_r36          | Android10          | Pixel 2、Pixel 2 XL                                          | 2020-05-05       |
| QQ2A.200501.001.B2 | android-10.0.0_r35          | Android10          | Pixel 3、Pixel 3 XL、Pixel 3a、Pixel 3a XL、Pixel 4、Pixel 4 XL | 2020-05-05       |
| QQ2A.200501.001.A3 | android-10.0.0_r34          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3 XL、Pixel 3a、Pixel 3a XL、Pixel 4、Pixel 4 XL | 2020-05-05       |
| QQ2A.200405.005    | android-10.0.0_r33          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3 XL、Pixel 3a、Pixel 3a XL、Pixel 4、Pixel 4 XL | 2020-04-05       |
| QQ2A.200305.004.A1 | android-10.0.0_r32          | Android10          | Pixel 4、Pixel 4 XL                                          | 2020-03-05       |
| QQ2A.200305.003    | android-10.0.0_r31          | Android10          | Pixel 4、Pixel 4 XL                                          | 2020-03-05       |
| QQ2A.200305.002    | android-10.0.0_r30          | Android10          | Pixel 2、Pixel 2 XL、Pixel 3、Pixel 3 XL、Pixel 3a、Pixel 3a XL | 2020-03-05       |
| QQ1D.200205.002    | android-10.0.0_r29          | Android10          | Pixel 4 XL、Pixel 4                                          | 2020-02-05       |
| QQ1C.200205.002    | android-10.0.0_r28          | Android10          | Pixel 4 XL、Pixel 4                                          | 2020-02-05       |
| QQ1B.200205.002    | android-10.0.0_r27          | Android10          | Pixel 4 XL、Pixel 4                                          | 2020-02-05       |
| QQ1A.200205.002    | android-10.0.0_r26          | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2 | 2020-02-05       |
| QQ1D.200105.002    | android-10.0.0_r25          | Android10          | Pixel 4 XL、Pixel 4                                          | 2020-01-01       |
| QQ1C.200105.004    | android-10.0.0_r24          | Android10          | Pixel 4 XL、Pixel 4                                          | 2020-01-01       |
| QQ1B.200105.004    | android-10.0.0_r23          | Android10          | Pixel 4 XL、Pixel 4                                          | 2020-01-01       |
| QQ1A.200105.003    | android-10.0.0_r22          | Android10          | Pixel 3 XL、Pixel 3                                          | 2020-01-01       |
| QQ1A.200105.002    | android-10.0.0_r21          | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2 | 2020-01-01       |
| QQ1C.191205.016.A1 | android-10.0.0_r20          | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-12-05       |
| QQ1B.191205.012.A1 | android-10.0.0_r19          | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-12-05       |
| QQ1B.191205.011    | android-10.0.0_r18          | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-12-05       |
| QP1A.191005.007.A3 | android-10.0.0_r17          | Android10          | Pixel XL、Pixel                                              | 2019-10-06       |
| QQ1A.191205.011    | android-10.0.0_r16          | Android10          | Pixel 3a XL、Pixel 3a                                        | 2019-12-05       |
| QQ1A.191205.008    | android-10.0.0_r15          | Android10          | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2                     | 2019-12-05       |
| QD1A.190821.014.C2 | android-10.0.0_r14          | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-11-05       |
| QD1A.190821.014    | android-10.0.0_r13          | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-11-05       |
| QD1A.190821.007.A3 | android-10.0.0_r12          | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-11-05       |
| QP1A.191105.004    | android-10.0.0_r11          | Android10          | Pixel 2 XL、Pixel 2                                          | 2019-11-05       |
| QP1A.191105.003    | android-10.0.0_r10          | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3                   | 2019-11-05       |
| QD1A.190821.011.C4 | android-10.0.0_r9           | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-10-05       |
| QD1A.190821.011    | android-10.0.0_r8           | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-10-05       |
| QD1A.190821.007    | android-10.0.0_r7           | Android10          | Pixel 4 XL、Pixel 4                                          | 2019-10-05       |
| 5933585            | android-10.0.0_r6           | Android10          |                                                              | 2019-09-05       |
| QP1A.191005.007.A1 | android-10.0.0_r5           | Android10          | Pixel 2 XL、Pixel 2、Pixel XL、Pixel                         | 2019-10-06       |
| QP1A.191005.007    | android-10.0.0_r4           | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3                   | 2019-10-05       |
| QP1A.190711.020.C3 | android-10.0.0_r3           | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3                   | 2019-09-05       |
| QP1A.190711.020    | android-10.0.0_r2           | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel | 2019-09-05       |
| QP1A.190711.019    | android-10.0.0_r1           | Android10          | Pixel 3a XL、Pixel 3a、Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel | 2019-09-05       |
| 7269718            | android-security-9.0.0_r69  | Pie                |                                                              | 2018-08-05       |
| 7249336            | android-security-9.0.0_r68  | Pie                |                                                              | 2018-08-05       |
| 7127521            | android-security-9.0.0_r67  | Pie                |                                                              | 2018-08-05       |
| 7070702            | android-security-9.0.0_r66  | Pie                |                                                              | 2018-08-05       |
| 7023409            | android-security-9.0.0_r65  | Pie                |                                                              | 2018-08-05       |
| 6969600            | android-security-9.0.0_r64  | Pie                |                                                              | 2018-08-05       |
| 6893678            | android-security-9.0.0_r63  | Pie                |                                                              | 2018-08-05       |
| 6826377            | android-security-9.0.0_r62  | Pie                |                                                              | 2018-08-05       |
| 6780336            | android-9.0.0_r61           | Pie                |                                                              | 2018-08-05       |
| 6644287            | android-9.0.0_r60           | Pie                |                                                              | 2018-08-05       |
| 6559974            | android-9.0.0_r59           | Pie                |                                                              | 2018-08-05       |
| 6495666            | android-9.0.0_r58           | Pie                |                                                              | 2018-08-05       |
| 6454888            | android-9.0.0_r57           | Pie                |                                                              | 2018-08-05       |
| 6440158            | android-9.0.0_r56           | Pie                |                                                              | 2018-08-05       |
| 6197209            | android-9.0.0_r55           | Pie                |                                                              | 2018-08-05       |
| 6127072            | android-9.0.0_r54           | Pie                |                                                              | 2018-08-05       |
| 6107734            | android-9.0.0_r53           | Pie                |                                                              | 2018-08-05       |
| 6037698            | android-9.0.0_r52           | Pie                |                                                              | 2018-08-05       |
| 5948683            | android-9.0.0_r51           | Pie                |                                                              | 2018-08-05       |
| 5887210            | android-9.0.0_r50           | Pie                |                                                              | 2018-08-05       |
| 5794013            | android-9.0.0_r49           | Pie                |                                                              | 2018-08-05       |
| 5748468            | android-9.0.0_r48           | Pie                |                                                              | 2018-08-05       |
| PQ3B.190801.002    | android-9.0.0_r47           | Pie                | Pixel 3a XL、Pixel 3a                                        | 2019-08-01       |
| PQ3A.190801.002    | android-9.0.0_r46           | Pie                | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel    | 2019-08-01       |
| PQ3B.190705.003    | android-9.0.0_r45           | Pie                | Pixel 3a XL、Pixel 3a                                        | 2019-07-05       |
| PQ3A.190705.003    | android-9.0.0_r44           | Pie                | Pixel 3 XL、Pixel 3                                          | 2019-07-05       |
| PQ3A.190705.001    | android-9.0.0_r43           | Pie                | Pixel 2 XL、Pixel 2、Pixel XL、Pixel                         | 2019-07-05       |
| PQ3B.190605.006    | android-9.0.0_r42           | Pie                | Pixel 3a XL、Pixel 3a                                        | 2019-06-05       |
| PQ3A.190605.004.A1 | android-9.0.0_r41           | Pie                | Pixel 3 XL、Pixel 3                                          | 2019-06-05       |
| PQ3A.190605.003    | android-9.0.0_r40           | Pie                | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel    | 2019-06-05       |
| PD2A.190115.032    | android-9.0.0_r39           | Pie                | Pixel 3a XL、Pixel 3a                                        | 2019-03-05       |
| PD2A.190115.029    | android-9.0.0_r38           | Pie                | Pixel 3a XL、Pixel 3a                                        | 2019-03-05       |
| PQ3A.190505.002    | android-9.0.0_r37           | Pie                | Pixel 3 XL、Pixel 3                                          | 2019-05-05       |
| PQ3A.190505.001    | android-9.0.0_r36           | Pie                | Pixel 2 XL、Pixel 2、Pixel XL、Pixel                         | 2019-05-05       |
| PQ2A.190405.003    | android-9.0.0_r35           | Pie                | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel    | 2019-04-05       |
| PQ2A.190305.002    | android-9.0.0_r34           | Pie                | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel    | 2019-03-05       |
| PQ2A.190205.003    | android-9.0.0_r33           | Pie                | Pixel XL、Pixel                                              | 2019-02-05       |
| PQ2A.190205.002    | android-9.0.0_r32           | Pie                | Pixel 2 XL、Pixel 2                                          | 2019-02-05       |
| PQ2A.190205.001    | android-9.0.0_r31           | Pie                | Pixel 3 XL、Pixel 3                                          | 2019-02-05       |
| PQ1A.190105.004    | android-9.0.0_r30           | Pie                | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2、Pixel XL、Pixel    | 2019-01-05       |
| PQ1A.181205.006.A1 | android-9.0.0_r22           | Pie                | Pixel 3 XL、Pixel 3                                          | 2018-12-05       |
| PQ1A.181205.006    | android-9.0.0_r21           | Pie                | Pixel 3 XL、Pixel 3                                          | 2018-12-05       |
| PQ1A.181205.002.A1 | android-9.0.0_r20           | Pie                | Pixel XL、Pixel                                              | 2018-12-05       |
| PQ1A.181205.002    | android-9.0.0_r19           | Pie                | Pixel 2 XL、Pixel 2                                          | 2018-12-05       |
| PPR2.181005.003.A1 | android-9.0.0_r18           | Pie                | Pixel XL、Pixel                                              | 2018-11-01       |
| PPR1.181005.003.A1 | android-9.0.0_r17           | Pie                | Pixel XL、Pixel                                              | 2018-11-01       |
| PQ1A.181105.017.A1 | android-9.0.0_r16           | Pie                | Pixel 3 XL、Pixel 3、Pixel 2 XL、Pixel 2                     | 2018-11-05       |
| PD1A.180720.031    | android-9.0.0_r12           | Pie                | Pixel 3 XL、Pixel 3                                          | 2018-09-05       |
| PD1A.180720.030    | android-9.0.0_r11           | Pie                | Pixel 3 XL、Pixel 3                                          | 2018-09-05       |
| PPR2.181005.003    | android-9.0.0_r10           | Pie                | Pixel XL、Pixel、Pixel 2 XL、Pixel 2                         | 2018-10-05       |
| PPR1.181005.003    | android-9.0.0_r9            | Pie                | Pixel XL、Pixel                                              | 2018-10-05       |
| PPR2.180905.006.A1 | android-9.0.0_r8            | Pie                | Pixel XL、Pixel                                              | 2018-09-05       |
| PPR2.180905.006    | android-9.0.0_r7            | Pie                | Pixel XL、Pixel                                              | 2018-09-05       |
| PPR2.180905.005    | android-9.0.0_r6            | Pie                | Pixel 2 XL、Pixel 2                                          | 2018-09-05       |
| PPR1.180905.003    | android-9.0.0_r5            | Pie                | Pixel XL、Pixel                                              | 2018-09-05       |
| PPR1.180610.011    | android-9.0.0_r3            | Pie                | Pixel 2 XL、Pixel 2                                          | 2018-08-05       |
| PPR1.180610.010    | android-9.0.0_r2            | Pie                | Pixel XL、Pixel                                              | 2018-08-05       |
| PPR1.180610.009    | android-9.0.0_r1            | Pie                | Pixel 2 XL、Pixel 2、Pixel XL、Pixel                         | 2018-08-05       |
| 7269716            | android-security-8.1.0_r89  | Oreo               |                                                              | 2017-12-05       |
| 7249334            | android-security-8.1.0_r88  | Oreo               |                                                              | 2017-12-05       |
| 7127520            | android-security-8.1.0_r87  | Oreo               |                                                              | 2017-12-05       |
| 7070700            | android-security-8.1.0_r86  | Oreo               |                                                              | 2017-12-05       |
| 7023408            | android-security-8.1.0_r85  | Oreo               |                                                              | 2017-12-05       |
| 6969599            | android-security-8.1.0_r84  | Oreo               |                                                              | 2017-12-05       |
| 6893677            | android-security-8.1.0_r83  | Oreo               |                                                              | 2017-12-05       |
| 6826376            | android-security-8.1.0_r82  | Oreo               |                                                              | 2017-12-05       |
| 6780335            | android-8.1.0_r81           | Oreo               |                                                              | 2017-12-05       |
| 6644286            | android-8.1.0_r80           | Oreo               |                                                              | 2017-12-05       |
| 6560352            | android-8.1.0_r79           | Oreo               |                                                              | 2017-12-05       |
| 6495665            | android-8.1.0_r78           | Oreo               |                                                              | 2017-12-05       |
| 6454887            | android-8.1.0_r77           | Oreo               |                                                              | 2017-12-05       |
| 6440157            | android-8.1.0_r76           | Oreo               |                                                              | 2017-12-05       |
| 6197208            | android-8.1.0_r75           | Oreo               |                                                              | 2017-12-05       |
| 6127071            | android-8.1.0_r74           | Oreo               |                                                              | 2017-12-05       |
| 6107733            | android-8.1.0_r73           | Oreo               |                                                              | 2017-12-05       |
| 6037697            | android-8.1.0_r72           | Oreo               |                                                              | 2017-12-05       |
| 5948682            | android-8.1.0_r71           | Oreo               |                                                              | 2017-12-05       |
| 5887208            | android-8.1.0_r70           | Oreo               |                                                              | 2017-12-05       |
| 5794017            | android-8.1.0_r69           | Oreo               |                                                              | 2017-12-05       |
| 5725752            | android-8.1.0_r68           | Oreo               |                                                              | 2017-12-05       |
| OPM8.190605.005    | android-8.1.0_r67           | Oreo               | Pixel C                                                      | 2019-06-05       |
| 5650812            | android-8.1.0_r66           | Oreo               |                                                              | 2017-12-05       |
| OPM8.190605.003    | android-8.1.0_r65           | Oreo               | Pixel C                                                      | 2019-06-05       |
| OPM8.190505.001    | android-8.1.0_r64           | Oreo               | Pixel C                                                      | 2019-05-05       |
| OPM8.190405.001    | android-8.1.0_r63           | Oreo               | Pixel C                                                      | 2019-04-05       |
| OPM8.190305.001    | android-8.1.0_r62           | Oreo               | Pixel C                                                      | 2019-03-05       |
| OPM8.190205.001    | android-8.1.0_r61           | Oreo               | Pixel C                                                      | 2019-02-05       |
| OPM8.190105.002    | android-8.1.0_r60           | Oreo               | Pixel C                                                      | 2019-01-05       |
| OPM8.181205.001    | android-8.1.0_r53           | Oreo               | Pixel C                                                      | 2018-12-05       |
| OPM7.181205.001    | android-8.1.0_r52           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-12-05       |
| OPM8.181105.002    | android-8.1.0_r51           | Oreo               | Pixel C                                                      | 2018-11-05       |
| OPM7.181105.004    | android-8.1.0_r50           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-11-05       |
| OPM8.181005.003    | android-8.1.0_r48           | Oreo               | Pixel C                                                      | 2018-10-05       |
| OPM7.181005.003    | android-8.1.0_r47           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-10-05       |
| OPM6.171019.030.K1 | android-8.1.0_r46           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-09-05       |
| OPM4.171019.021.Z1 | android-8.1.0_r45           | Oreo               | Pixel C                                                      | 2018-09-05       |
| OPM6.171019.030.H1 | android-8.1.0_r43           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-08-05       |
| OPM4.171019.021.Y1 | android-8.1.0_r42           | Oreo               | Pixel C                                                      | 2018-08-05       |
| OPM6.171019.030.E1 | android-8.1.0_r41           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-07-05       |
| OPM4.171019.021.R1 | android-8.1.0_r40           | Oreo               | Pixel 2 XL                                                   | 2018-07-05       |
| OPM4.171019.021.Q1 | android-8.1.0_r39           | Oreo               | Pixel 2                                                      | 2018-07-05       |
| OPM4.171019.021.P1 | android-8.1.0_r38           | Oreo               | Pixel、Pixel XL                                              | 2018-07-05       |
| OPM4.171019.021.N1 | android-8.1.0_r37           | Oreo               | Pixel C                                                      | 2018-07-05       |
| OPM2.171026.006.H1 | android-8.1.0_r36           | Oreo               | Pixel 2 XL                                                   | 2018-07-05       |
| OPM2.171026.006.G1 | android-8.1.0_r35           | Oreo               | Pixel 2                                                      | 2018-07-05       |
| OPM6.171019.030.B1 | android-8.1.0_r33           | Oreo               | Nexus 6P、Nexus 5X                                           | 2018-06-05       |
| OPM4.171019.021.E1 | android-8.1.0_r32           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2018-06-05       |
| OPM4.171019.021.D1 | android-8.1.0_r31           | Oreo               | Pixel XL、Pixel                                              | 2018-06-05       |
| OPM2.171026.006.C1 | android-8.1.0_r30           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2018-06-05       |
| OPM4.171019.016.C1 | android-8.1.0_r29           | Oreo               | Pixel C                                                      | 2018-05-05       |
| OPM4.171019.016.B1 | android-8.1.0_r28           | Oreo               | Pixel XL、Pixel、Pixel 2 XL、Pixel 2                         | 2018-05-05       |
| OPM4.171019.016.A1 | android-8.1.0_r27           | Oreo               | Nexus 5X                                                     | 2018-05-05       |
| OPM2.171019.029.B1 | android-8.1.0_r26           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2018-05-05       |
| OPM2.171019.029.A1 | android-8.1.0_r25           | Oreo               | Nexus 6P                                                     | 2018-05-05       |
| OPM4.171019.015.A1 | android-8.1.0_r23           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2018-04-01       |
| OPM5.171019.019    | android-8.1.0_r22           | Oreo               | Nexus 6P                                                     | 2018-04-01       |
| OPM3.171019.019    | android-8.1.0_r21           | Oreo               | Nexus 6P                                                     | 2018-04-01       |
| OPM2.171019.029    | android-8.1.0_r20           | Oreo               | Pixel 2 XL、Pixel 2、Pixel XL、Pixel、Nexus 5X               | 2018-04-05       |
| OPM1.171019.026    | android-8.1.0_r19           | Oreo               | Pixel C                                                      | 2018-04-05       |
| OPM5.171019.017    | android-8.1.0_r18           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-03-05       |
| OPM3.171019.016    | android-8.1.0_r17           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-03-05       |
| OPM1.171019.022.A1 | android-8.1.0_r16           | Oreo               | Pixel C                                                      | 2018-03-05       |
| OPM1.171019.021    | android-8.1.0_r15           | Oreo               | Pixel 2 XL、Pixel 2、Pixel XL、Pixel                         | 2018-03-05       |
| OPM5.171019.015    | android-8.1.0_r14           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-02-05       |
| OPM3.171019.014    | android-8.1.0_r13           | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-02-05       |
| OPM1.171019.019    | android-8.1.0_r12           | Oreo               | Pixel 2                                                      | 2018-02-05       |
| OPM1.171019.018    | android-8.1.0_r11           | Oreo               | Pixel 2 XL                                                   | 2018-02-05       |
| OPM1.171019.016    | android-8.1.0_r10           | Oreo               | Pixel、Pixel XL、Pixel C                                     | 2018-02-05       |
| OPM5.171019.014    | android-8.1.0_r9            | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-01-05       |
| OPM2.171019.016    | android-8.1.0_r8            | Oreo               | Pixel 2                                                      | 2018-01-05       |
| OPM3.171019.013    | android-8.1.0_r7            | Oreo               | Nexus 5X、Nexus 6P                                           | 2018-01-05       |
| OPM1.171019.015    | android-8.1.0_r6            | Oreo               | Pixel C                                                      | 2018-01-05       |
| OPM1.171019.014    | android-8.1.0_r5            | Oreo               | Pixel 2 XL、Pixel 2、Pixel XL、Pixel                         | 2018-01-05       |
| OPM1.171019.013    | android-8.1.0_r4            | Oreo               | Pixel 2 XL、Pixel 2                                          | 2018-01-05       |
| OPM1.171019.012    | android-8.1.0_r3            | Oreo               | Pixel XL、Pixel                                              | 2018-01-05       |
| OPM2.171019.012    | android-8.1.0_r2            | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-12-05       |
| OPM1.171019.011    | android-8.1.0_r1            | Oreo               | Pixel 2 XL、Pixel 2、Pixel XL、Pixel、Pixel C、Nexus 6P、Nexus 5X | 2017-12-05       |
| 6969596            | android-security-8.0.0_r54  | Oreo               |                                                              | 2017-10-01       |
| 6893676            | android-security-8.0.0_r53  | Oreo               |                                                              | 2017-10-01       |
| 6826375            | android-security-8.0.0_r52  | Oreo               |                                                              | 2017-10-01       |
| 6780349            | android-8.0.0_r51           | Oreo               |                                                              | 2017-10-01       |
| 6644283            | android-8.0.0_r50           | Oreo               |                                                              | 2017-10-01       |
| 6560351            | android-8.0.0_r49           | Oreo               |                                                              | 2017-10-01       |
| 6495664            | android-8.0.0_r48           | Oreo               |                                                              | 2017-10-01       |
| 6454886            | android-8.0.0_r47           | Oreo               |                                                              | 2017-10-01       |
| 6349210            | android-8.0.0_r46           | Oreo               |                                                              | 2017-10-01       |
| 6197207            | android-8.0.0_r45           | Oreo               |                                                              | 2017-10-01       |
| 6127070            | android-8.0.0_r44           | Oreo               |                                                              | 2017-10-01       |
| 6107732            | android-8.0.0_r43           | Oreo               |                                                              | 2017-10-01       |
| 6037696            | android-8.0.0_r42           | Oreo               |                                                              | 2017-10-01       |
| 5948681            | android-8.0.0_r41           | Oreo               |                                                              | 2017-10-01       |
| 5887206            | android-8.0.0_r40           | Oreo               |                                                              | 2017-10-01       |
| 5796467            | android-8.0.0_r39           | Oreo               |                                                              | 2017-10-01       |
| 5729099            | android-8.0.0_r38           | Oreo               |                                                              | 2017-10-01       |
| 5650811            | android-8.0.0_r37           | Oreo               |                                                              | 2017-10-01       |
| OPR5.170623.014    | android-8.0.0_r36           | Oreo               | Nexus 6P                                                     | 2017-12-01       |
| OPR4.170623.020    | android-8.0.0_r35           | Oreo               | Nexus 5X                                                     | 2017-12-01       |
| OPD3.170816.023    | android-8.0.0_r34           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-11-05       |
| OPD1.170816.025    | android-8.0.0_r33           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-11-05       |
| OPR6.170623.023    | android-8.0.0_r32           | Oreo               | Nexus 5X                                                     | 2017-11-05       |
| OPR5.170623.011    | android-8.0.0_r31           | Oreo               | Nexus 6P                                                     | 2017-11-05       |
| OPR3.170623.013    | android-8.0.0_r30           | Oreo               | Pixel XL、Pixel                                              | 2017-11-05       |
| OPR2.170623.027    | android-8.0.0_r29           | Oreo               | Nexus Player                                                 | 2017-11-05       |
| OPR1.170623.032    | android-8.0.0_r28           | Oreo               | Pixel XL、Pixel、Pixel C                                     | 2017-11-05       |
| OPD3.170816.016    | android-8.0.0_r27           | Oreo               | Pixel 2                                                      | 2017-11-05       |
| OPD2.170816.015    | android-8.0.0_r26           | Oreo               | Pixel 2                                                      | 2017-11-05       |
| OPD1.170816.018    | android-8.0.0_r25           | Oreo               | Pixel 2                                                      | 2017-11-05       |
| OPD3.170816.012    | android-8.0.0_r24           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-09-05       |
| OPD1.170816.012    | android-8.0.0_r23           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-09-05       |
| OPD1.170816.011    | android-8.0.0_r22           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-09-05       |
| OPD1.170816.010    | android-8.0.0_r21           | Oreo               | Pixel 2 XL、Pixel 2                                          | 2017-09-05       |
| OPR5.170623.007    | android-8.0.0_r17           | Oreo               | Nexus 6P                                                     | 2017-10-05       |
| OPR4.170623.009    | android-8.0.0_r16           | Oreo               | Nexus 5X                                                     | 2017-10-05       |
| OPR3.170623.008    | android-8.0.0_r15           | Oreo               | Pixel XL、Pixel                                              | 2017-10-05       |
| OPR1.170623.027    | android-8.0.0_r13           | Oreo               | Pixel XL、Pixel、Pixel C                                     | 2017-10-05       |
| OPR6.170623.021    | android-8.0.0_r12           | Oreo               | Nexus Player                                                 | 2017-09-05       |
| OPR6.170623.019    | android-8.0.0_r11           | Oreo               | Nexus 6P                                                     | 2017-09-05       |
| OPR4.170623.006    | android-8.0.0_r10           | Oreo               | Nexus 5X                                                     | 2017-09-05       |
| OPR3.170623.007    | android-8.0.0_r9            | Oreo               | Pixel XL、Pixel                                              | 2017-09-05       |
| OPR1.170623.026    | android-8.0.0_r7            | Oreo               | Pixel XL、Pixel、Pixel C                                     | 2017-09-05       |
| OPR6.170623.013    | android-8.0.0_r4            | Oreo               | Nexus 5X、Nexus 6P                                           | 2017-08-05       |
| OPR6.170623.012    | android-8.0.0_r3            | Oreo               | Pixel XL、Pixel                                              | 2017-08-05       |
| OPR6.170623.011    | android-8.0.0_r2            | Oreo               | Pixel XL、Pixel                                              | 2017-08-05       |
| OPR6.170623.010    | android-8.0.0_r1            | Oreo               | Pixel C                                                      | 2017-08-05       |
| 5787804            | android-7.1.2_r39           | Nougat             |                                                              | 2017-10-01       |
| 5725750            | android-7.1.2_r38           | Nougat             |                                                              | 2017-10-01       |
| 5650810            | android-7.1.2_r37           | Nougat             |                                                              | 2017-10-01       |
| N2G48H             | android-7.1.2_r36           | Nougat             |                                                              | 2017-10-05       |
| NZH54D             | android-7.1.2_r33           | Nougat             | Pixel XL、Pixel                                              | 2017-08-05       |
| NKG47S             | android-7.1.2_r32           | Nougat             | Pixel XL、Pixel                                              | 2017-08-05       |
| NHG47Q             | android-7.1.2_r30           | Nougat             | Pixel XL、Pixel                                              | 2017-08-05       |
| NJH47F             | android-7.1.2_r29           | Nougat             | Pixel XL、Pixel                                              | 2017-08-05       |
| N2G48C             | android-7.1.2_r28           | Nougat             | Nexus 5X、Nexus 6P、Nexus Player、Pixel C                    | 2017-08-05       |
| NZH54B             | android-7.1.2_r27           | Nougat             | Pixel XL、Pixel                                              | 2017-07-05       |
| NKG47M             | android-7.1.2_r25           | Nougat             | Pixel XL、Pixel                                              | 2017-07-05       |
| NJH47D             | android-7.1.2_r24           | Nougat             | Pixel XL、Pixel                                              | 2017-07-05       |
| NHG47O             | android-7.1.2_r23           | Nougat             | Pixel XL、Pixel                                              | 2017-07-05       |
| N2G48B             | android-7.1.2_r19           | Nougat             | Nexus 6P、Nexus Player、Pixel C                              | 2017-07-05       |
| N2G47Z             | android-7.1.2_r18           | Nougat             | Nexus 5X                                                     | 2017-07-05       |
| NJH47B             | android-7.1.2_r17           | Nougat             | Pixel XL、Pixel                                              | 2017-06-05       |
| NJH34C             | android-7.1.2_r16           | Nougat             | Pixel XL、Pixel                                              | 2017-06-05       |
| NKG47L             | android-7.1.2_r15           | Nougat             | Pixel XL、Pixel                                              | 2017-06-05       |
| NHG47N             | android-7.1.2_r14           | Nougat             | Pixel XL、Pixel                                              | 2017-06-05       |
| N2G47X             | android-7.1.2_r13           | Nougat             | Nexus Player                                                 | 2017-06-05       |
| N2G47W             | android-7.1.2_r12           | Nougat             | Nexus 5X、Nexus 6P、Pixel C                                  | 2017-06-05       |
| NHG47L             | android-7.1.2_r11           | Nougat             | Pixel XL、Pixel                                              | 2017-05-05       |
| N2G47T             | android-7.1.2_r10           | Nougat             | Pixel XL、Pixel                                              | 2017-05-05       |
| N2G47R             | android-7.1.2_r9            | Nougat             | Nexus Player                                                 | 2017-05-05       |
| N2G47O             | android-7.1.2_r8            | Nougat             | Nexus 5X、Nexus 6P、Pixel XL、Pixel、Pixel C                 | 2017-05-05       |
| NHG47K             | android-7.1.2_r6            | Nougat             | Pixel XL、Pixel                                              | 2017-04-05       |
| N2G47J             | android-7.1.2_r5            | Nougat             | Pixel XL、Pixel                                              | 2017-04-05       |
| N2G47H             | android-7.1.2_r4            | Nougat             | Nexus 6P、Nexus Player                                       | 2017-04-05       |
| N2G47F             | android-7.1.2_r3            | Nougat             | Nexus 5X                                                     | 2017-04-05       |
| N2G47E             | android-7.1.2_r2            | Nougat             | Pixel XL、Pixel                                              | 2017-04-05       |
| N2G47D             | android-7.1.2_r1            | Nougat             | Pixel C                                                      | 2017-04-05       |
| 5787798            | android-7.1.1_r61           | Nougat             |                                                              | 2017-10-01       |
| 5725749            | android-7.1.1_r60           | Nougat             |                                                              | 2017-10-01       |
| 5650809            | android-7.1.1_r59           | Nougat             |                                                              | 2017-10-01       |
| N9F27M             | android-7.1.1_r58           | Nougat             | Nexus 9 (volantis)                                           | 2017-10-05       |
| NGI77B             | android-7.1.1_r57           | Nougat             | Nexus 6                                                      | 2017-10-05       |
| N8I11F             | android-7.1.1_r56           | Nougat             | Nexus 6                                                      | 2017-10-05       |
| N6F27M             | android-7.1.1_r55           | Nougat             | Nexus 6                                                      | 2017-10-05       |
| N4F27P             | android-7.1.1_r54           | Nougat             | Nexus 9 (volantisg)                                          | 2017-10-05       |
| N9F27L             | android-7.1.1_r53           | Nougat             | Nexus 9                                                      | 2017-09-05       |
| NGI55D             | android-7.1.1_r52           | Nougat             | Nexus 6                                                      | 2017-09-05       |
| N4F27O             | android-7.1.1_r51           | Nougat             | Nexus 9 (volantisg)                                          | 2017-09-05       |
| N8I11B             | android-7.1.1_r50           | Nougat             | Nexus 6                                                      | 2017-08-05       |
| N9F27H             | android-7.1.1_r49           | Nougat             | Nexus 9 (volantis)                                           | 2017-08-05       |
| N6F27I             | android-7.1.1_r48           | Nougat             | Nexus 6                                                      | 2017-08-05       |
| N4F27K             | android-7.1.1_r47           | Nougat             | Nexus 9 (volantisg)                                          | 2017-08-05       |
| N9F27F             | android-7.1.1_r46           | Nougat             | Nexus 9 (volantis)                                           | 2017-07-05       |
| N6F27H             | android-7.1.1_r45           | Nougat             | Nexus 6                                                      | 2017-07-05       |
| N4F27I             | android-7.1.1_r44           | Nougat             | Nexus 9 (volantisg)                                          | 2017-07-05       |
| N9F27C             | android-7.1.1_r43           | Nougat             | Nexus 9 (volantis)                                           | 2017-06-05       |
| N6F27E             | android-7.1.1_r42           | Nougat             | Nexus 6                                                      | 2017-06-05       |
| N4F27E             | android-7.1.1_r41           | Nougat             | Nexus 9 (volantisg)                                          | 2017-06-05       |
| N6F27C             | android-7.1.1_r40           | Nougat             | Nexus 6                                                      | 2017-05-05       |
| N4F27B             | android-7.1.1_r39           | Nougat             | Nexus 9 (volantis/volantisg)                                 | 2017-05-05       |
| N6F26Y             | android-7.1.1_r38           | Nougat             | Nexus 6                                                      | 2017-04-01       |
| NOF27D             | android-7.1.1_r35           | Nougat             | Pixel XL、Pixel                                              | 2017-04-01       |
| N4F26X             | android-7.1.1_r33           | Nougat             | Nexus 9 (volantis/volantisg)                                 | 2017-04-01       |
| N4F26U             | android-7.1.1_r31           | Nougat             | Nexus 5X、Nexus 6P                                           | 2017-04-01       |
| N6F26U             | android-7.1.1_r28           | Nougat             | Nexus 6                                                      | 2017-03-05       |
| NUF26N             | android-7.1.1_r27           | Nougat             | Nexus 6P                                                     | 2017-03-05       |
| NOF27C             | android-7.1.1_r26           | Nougat             | Pixel XL、Pixel                                              | 2017-03-05       |
| NOF27B             | android-7.1.1_r25           | Nougat             | Pixel XL、Pixel                                              | 2017-03-05       |
| N4F26T             | android-7.1.1_r24           | Nougat             | Nexus 5X、Nexus 6P、Nexus 9 (volantis/volantisg)、Pixel C    | 2017-03-05       |
| NMF27D             | android-7.1.1_r23           | Nougat             | Nexus Player                                                 | 2017-03-05       |
| NMF26X             | android-7.1.1_r22           | Nougat             | Nexus Player                                                 | 2017-02-05       |
| NOF26W             | android-7.1.1_r21           | Nougat             | Pixel XL、Pixel                                              | 2017-02-05       |
| NOF26V             | android-7.1.1_r20           | Nougat             | Pixel XL、Pixel                                              | 2017-02-05       |
| N6F26R             | android-7.1.1_r17           | Nougat             | Nexus 6                                                      | 2017-02-05       |
| NUF26K             | android-7.1.1_r16           | Nougat             | Nexus 6P                                                     | 2017-02-05       |
| N4F26Q             | android-7.1.1_r15           | Nougat             | Nexus 9 (volantis/volantisg)                                 | 2017-02-05       |
| N4F26O             | android-7.1.1_r14           | Nougat             | Nexus 5X、Nexus 6P、Pixel C                                  | 2017-02-05       |
| N6F26Q             | android-7.1.1_r13           | Nougat             | Nexus 6                                                      | 2017-01-05       |
| N4F26M             | android-7.1.1_r12           | Nougat             | Nexus 9 (volantis)                                           | 2017-01-01       |
| N4F26J             | android-7.1.1_r11           | Nougat             | Nexus 5X、Nexus 6P                                           | 2017-01-05       |
| N4F26I             | android-7.1.1_r10           | Nougat             | Nexus 5X、Nexus 6P、Pixel C                                  | 2017-01-05       |
| NMF26V             | android-7.1.1_r9            | Nougat             | Pixel XL、Pixel                                              | 2017-01-05       |
| NMF26U             | android-7.1.1_r8            | Nougat             | Pixel XL、Pixel                                              | 2017-01-05       |
| NMF26R             | android-7.1.1_r7            | Nougat             | Nexus Player                                                 | 2017-01-05       |
| NMF26Q             | android-7.1.1_r6            | Nougat             | Pixel XL、Pixel                                              | 2016-12-05       |
| NMF26O             | android-7.1.1_r4            | Nougat             | Pixel XL、Pixel                                              | 2016-12-05       |
| NMF26J             | android-7.1.1_r3            | Nougat             | Nexus Player                                                 | 2016-12-05       |
| NMF26H             | android-7.1.1_r2            | Nougat             | Pixel C                                                      | 2016-12-05       |
| NMF26F             | android-7.1.1_r1            | Nougat             | Nexus 5X、Nexus 6P、Nexus 9 (volantis/volantisg)             | 2016-12-05       |
| NDE63X             | android-7.1.0_r7            | Nougat             | Pixel XL、Pixel                                              | 2016-11-05       |
| NDE63V             | android-7.1.0_r6            | Nougat             | Pixel XL、Pixel                                              | 2016-11-05       |
| NDE63U             | android-7.1.0_r5            | Nougat             | Pixel XL、Pixel                                              | 2016-11-05       |
| NDE63P             | android-7.1.0_r4            | Nougat             | Pixel XL、Pixel                                              | 2016-10-05       |
| NDE63L             | android-7.1.0_r2            | Nougat             | Pixel XL、Pixel                                              | 2016-10-05       |
| NDE63H             | android-7.1.0_r1            | Nougat             | Pixel XL、Pixel                                              | 2016-10-05       |
| NBD92Y             | android-7.0.0_r36           | Nougat             |                                                              | 2019-03-01       |
| NBD92Q             | android-7.0.0_r35           | Nougat             |                                                              | 2017-11-01       |
| NBD92N             | android-7.0.0_r34           | Nougat             |                                                              | 2017-10-01       |
| NBD92G             | android-7.0.0_r33           | Nougat             | Nexus 6                                                      | 2017-04-01       |
| NBD92F             | android-7.0.0_r32           | Nougat             | Nexus 6                                                      | 2017-04-01       |
| NBD92E             | android-7.0.0_r31           | Nougat             | Nexus 6                                                      | 2017-03-05       |
| NBD92D             | android-7.0.0_r30           | Nougat             | Nexus 6                                                      | 2017-03-05       |
| NBD91Z             | android-7.0.0_r29           | Nougat             | Nexus 6                                                      | 2017-02-05       |
| NBD91Y             | android-7.0.0_r28           | Nougat             | Nexus 6                                                      | 2017-02-05       |
| NBD91X             | android-7.0.0_r27           | Nougat             | Nexus 6                                                      | 2017-01-05       |
| NBD91U             | android-7.0.0_r24           | Nougat             | Nexus 6                                                      | 2016-12-05       |
| N5D91L             | android-7.0.0_r21           | Nougat             | Nexus 5X                                                     | 2016-11-05       |
| NBD91P             | android-7.0.0_r19           | Nougat             | Nexus 6                                                      | 2016-11-05       |
| NRD91K             | android-7.0.0_r17           | Nougat             | Nexus 6P                                                     | 2016-11-05       |
| NRD91N             | android-7.0.0_r15           | Nougat             | Nexus 5X、Pixel C、Nexus Player、Nexus 9 (volantis/volantisg) | 2016-11-05       |
| NBD90Z             | android-7.0.0_r14           | Nougat             | Nexus 6                                                      | 2016-10-05       |
| NBD90X             | android-7.0.0_r13           | Nougat             | Nexus 6P                                                     | 2016-10-05       |
| NBD90W             | android-7.0.0_r12           | Nougat             | Nexus 5X                                                     | 2016-10-05       |
| NRD91D             | android-7.0.0_r7            | Nougat             | Pixel C、Nexus Player、Nexus 9 (WLAN)                        | 2016-10-05       |
| NRD90U             | android-7.0.0_r6            | Nougat             | Nexus 6P                                                     | 2016-09-06       |
| NRD90T             | android-7.0.0_r5            | Nougat             | Nexus 6P                                                     | 2016-09-06       |
| NRD90S             | android-7.0.0_r4            | Nougat             | Nexus 5X                                                     | 2016-09-06       |
| NRD90R             | android-7.0.0_r3            | Nougat             | Nexus 5X、Nexus 9 (volantis)、Nexus Player、Pixel C          | 2016-09-06       |
| NRD90M             | android-7.0.0_r1            | Nougat             | Nexus 5X、Nexus 9 (volantis)、Nexus Player、Pixel C          | 2016-08-05       |
| MOI10E             | android-6.0.1_r81           | Marshmallow        |                                                              | 2017-10-01       |
| MOB31Z             | android-6.0.1_r80           | Marshmallow        |                                                              | 2017-07-01       |
| MOB31T             | android-6.0.1_r79           | Marshmallow        | Nexus 6                                                      | 2017-02-01       |
| MOB31S             | android-6.0.1_r78           | Marshmallow        | Nexus 6                                                      | 2017-01-05       |
| M4B30Z             | android-6.0.1_r77           | Marshmallow        | Nexus 5                                                      | 2016-10-05       |
| MOB31K             | android-6.0.1_r74           | Marshmallow        | Nexus 6                                                      | 2016-11-05       |
| MMB31C             | android-6.0.1_r73           | Marshmallow        | Nexus 6                                                      | 2016-11-05       |
| M4B30X             | android-6.0.1_r72           | Marshmallow        | Nexus 5                                                      | 2016-10-05       |
| MOB31H             | android-6.0.1_r70           | Marshmallow        | Nexus 6                                                      | 2016-10-05       |
| MMB30Y             | android-6.0.1_r69           | Marshmallow        | Nexus 6                                                      | 2016-10-05       |
| MTC20K             | android-6.0.1_r67           | Marshmallow        | Nexus 5X                                                     | 2016-09-06       |
| MOB31E             | android-6.0.1_r66           | Marshmallow        | Nexus 5、Nexus 6、Nexus 9 (volantis)                         | 2016-09-06       |
| MMB30W             | android-6.0.1_r65           | Marshmallow        | Nexus 6                                                      | 2016-09-06       |
| MXC89L             | android-6.0.1_r63           | Marshmallow        | Pixel C                                                      | 2016-08-05       |
| MTC20F             | android-6.0.1_r62           | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2016-08-05       |
| MOB30Y             | android-6.0.1_r60           | Marshmallow        | Nexus 5                                                      | 2016-08-05       |
| MOB30X             | android-6.0.1_r59           | Marshmallow        | Nexus 7 (flo/deb)                                            | 2016-08-05       |
| MOB30W             | android-6.0.1_r58           | Marshmallow        | Nexus 6、Nexus 9 (volantis/volantisg)、Nexus Player          | 2016-08-05       |
| MMB30S             | android-6.0.1_r57           | Marshmallow        | Nexus 7 (deb)                                                | 2016-08-05       |
| MMB30R             | android-6.0.1_r56           | Marshmallow        | Nexus 6                                                      | 2016-08-05       |
| MXC89K             | android-6.0.1_r55           | Marshmallow        | Pixel C                                                      | 2016-07-05       |
| MTC19Z             | android-6.0.1_r54           | Marshmallow        | Nexus 5X                                                     | 2016-07-05       |
| MTC19X             | android-6.0.1_r53           | Marshmallow        | Nexus 6P                                                     | 2016-07-05       |
| MOB30P             | android-6.0.1_r50           | Marshmallow        | Nexus 5、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg)、Nexus Player | 2016-07-05       |
| MOB30O             | android-6.0.1_r49           | Marshmallow        | Nexus 6                                                      | 2016-07-05       |
| MMB30M             | android-6.0.1_r48           | Marshmallow        | Nexus 7 (deb)                                                | 2016-07-05       |
| MMB30K             | android-6.0.1_r47           | Marshmallow        | Nexus 6                                                      | 2016-07-05       |
| MOB30M             | android-6.0.1_r46           | Marshmallow        | Nexus 5、Nexus 6、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg)、Nexus Player | 2016-06-01       |
| MTC19V             | android-6.0.1_r45           | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2016-06-01       |
| MOB30J             | android-6.0.1_r43           | Marshmallow        | Nexus 7 (flo/deb)                                            | 2016-05-01       |
| MOB30I             | android-6.0.1_r42           | Marshmallow        | Nexus 6                                                      | 2016-05-01       |
| MOB30H             | android-6.0.1_r41           | Marshmallow        | Nexus 5                                                      | 2016-05-01       |
| MOB30G             | android-6.0.1_r40           | Marshmallow        | Nexus 9 (volantis/volantisg)、Nexus Player                   | 2016-05-01       |
| MXC89H             | android-6.0.1_r33           | Marshmallow        | Pixel C                                                      | 2016-06-01       |
| MXC89F             | android-6.0.1_r32           | Marshmallow        | Pixel C                                                      | 2016-05-01       |
| MMB30J             | android-6.0.1_r28           | Marshmallow        | Nexus 6、Nexus 7 (deb)                                       | 2016-06-01       |
| MTC19T             | android-6.0.1_r25           | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2016-05-01       |
| M5C14J             | android-6.0.1_r31           | Marshmallow        | Pixel C                                                      | 2016-04-01       |
| MOB30D             | android-6.0.1_r30           | Marshmallow        | Nexus 5、Nexus 6、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg)、Nexus Player | 2016-04-02       |
| MHC19Q             | android-6.0.1_r24           | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2016-04-02       |
| MHC19J             | android-6.0.1_r22           | Marshmallow        | Nexus 5X                                                     | 2016-03-01       |
| MHC19I             | android-6.0.1_r21           | Marshmallow        | Nexus 6P                                                     | 2016-03-01       |
| MMB29X             | android-6.0.1_r20           | Marshmallow        | Nexus 5、Nexus 6、Nexus 7 (deb)、Nexus 9 (volantisg)         | 2016-04-02       |
| MXC14G             | android-6.0.1_r18           | Marshmallow        | Pixel C                                                      | 2016-03-01       |
| MMB29V             | android-6.0.1_r17           | Marshmallow        | Nexus 5、Nexus 5X、Nexus 6、Nexus 6P、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg) | 2016-03-01       |
| MXB48T             | android-6.0.1_r16           | Marshmallow        | Pixel C                                                      | 2016-02-01       |
| MMB29U             | android-6.0.1_r13           | Marshmallow        | Nexus Player                                                 | 2016-02-01       |
| MMB29R             | android-6.0.1_r12           | Marshmallow        | Nexus 9 (volantis/volantisg)                                 | 2016-02-01       |
| MMB29Q             | android-6.0.1_r11           | Marshmallow        | Nexus 5、Nexus 5X、Nexus 6、Nexus 6P、Nexus 7 (flo/deb)      | 2016-02-01       |
| MMB29T             | android-6.0.1_r10           | Marshmallow        | Nexus Player                                                 | 2016-01-01       |
| MMB29S             | android-6.0.1_r9            | Marshmallow        | Nexus 5、Nexus 6、Nexus 9 (volantis/volantisg)               | 2016-01-01       |
| MMB29P             | android-6.0.1_r8            | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2016-01-01       |
| MMB29O             | android-6.0.1_r7            | Marshmallow        | Nexus 7 (flo/deb)                                            | 2016-01-01       |
| MXB48K             | android-6.0.1_r5            | Marshmallow        | Pixel C                                                      | 2015-12-01       |
| MXB48J             | android-6.0.1_r4            | Marshmallow        | Pixel C                                                      | 2015-12-01       |
| MMB29M             | android-6.0.1_r3            | Marshmallow        | Nexus 6P、Nexus Player                                       | 2015-12-01       |
| MMB29K             | android-6.0.1_r1            | Marshmallow        | Nexus 5、Nexus 5X、Nexus 6、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg) | 2015-12-01       |
| MMB29N             | android-6.0.0_r41           | Marshmallow        | Nexus 6P                                                     | 2015-11-01       |
| MDB08M             | android-6.0.0_r26           | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2015-11-01       |
| MDB08L             | android-6.0.0_r25           | Marshmallow        | Nexus 5X、Nexus 6P                                           | 2015-11-01       |
| MDB08K             | android-6.0.0_r24           | Marshmallow        | Nexus 6P                                                     | 2015-10-01       |
| MDB08I             | android-6.0.0_r23           | Marshmallow        | Nexus 5X                                                     | 2015-10-01       |
| MDA89E             | android-6.0.0_r12           | Marshmallow        | Nexus 5X                                                     | 2015-10-01       |
| MDA89D             | android-6.0.0_r11           | Marshmallow        | Nexus 6P                                                     | 2015-10-01       |
| MRA59B             | android-6.0.0_r7            | Marshmallow        | Nexus 7 (deb)                                                | 2015-12-01       |
| MRA58X             | android-6.0.0_r6            | Marshmallow        | Nexus 6                                                      | 2015-11-01       |
| MRA58V             | android-6.0.0_r5            | Marshmallow        | Nexus 7 (flo/deb)                                            | 2015-11-01       |
| MRA58U             | android-6.0.0_r4            | Marshmallow        | Nexus 7 (flo)                                                | 2015-10-01       |
| MRA58N             | android-6.0.0_r2            | Marshmallow        | Nexus 5、Nexus 6、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg)、Nexus Player | 2015-11-01       |
| MRA58K             | android-6.0.0_r1            | Marshmallow        | Nexus 5、Nexus 6、Nexus 7 (flo/deb)、Nexus 9 (volantis/volantisg)、Nexus Player | 2015-10-01       |
| LMY49M             | android-5.1.1_r38           | Lollipop           | Nexus 10                                                     | 2016-07-05       |
| LMY49J             | android-5.1.1_r37           | Lollipop           | Nexus 10                                                     | 2016-04-01       |
| LMY49I             | android-5.1.1_r36           | Lollipop           | Nexus 10                                                     | 2016-03-01       |
| LMY49H             | android-5.1.1_r35           | Lollipop           | Nexus 10                                                     | 2016-03-01       |
| LMY49G             | android-5.1.1_r34           | Lollipop           | Nexus 10                                                     | 2016-02-01       |
| LMY49F             | android-5.1.1_r33           | Lollipop           | Nexus 9 (volantisg)、Nexus 10                                | 2016-01-01       |
| LMY48Z             | android-5.1.1_r30           | Lollipop           | Nexus 6、Nexus 7 (deb)、Nexus 9 (volantisg)、Nexus 10        | 2015-12-01       |
| LYZ28N             | android-5.1.1_r28           | Lollipop           | Nexus 6（仅面向 T-Mobile）                                   | 2015-11-01       |
| LMY48Y             | android-5.1.1_r26           | Lollipop           | Nexus 6                                                      | 2015-11-01       |
| LMY48X             | android-5.1.1_r25           | Lollipop           | Nexus 6、Nexus 7 (deb)、Nexus 9 (volantisg)、Nexus 10        | 2015-11-01       |
| LMY48W             | android-5.1.1_r24           | Lollipop           | Nexus 6                                                      |                  |
| LVY48H             | android-5.1.1_r23           | Lollipop           | Nexus 6（仅面向 Google Fi）                                  |                  |
| LYZ28M             | android-5.1.1_r22           | Lollipop           | Nexus 6（仅面向 T-Mobile）                                   |                  |
| LMY48U             | android-5.1.1_r20           | Lollipop           | Nexus 7 (deb)                                                |                  |
| LMY48T             | android-5.1.1_r19           | Lollipop           | Nexus 4、Nexus 6、Nexus 9 (volantis/volantisg)、Nexus 10     |                  |
| LVY48F             | android-5.1.1_r18           | Lollipop           | Nexus 6（仅面向 Google Fi）                                  |                  |
| LYZ28K             | android-5.1.1_r17           | Lollipop           | Nexus 6（仅面向 T-Mobile）                                   |                  |
| LMY48P             | android-5.1.1_r16           | Lollipop           | Nexus 7 (deb)                                                |                  |
| LMY48N             | android-5.1.1_r15           | Lollipop           | Nexus Player                                                 |                  |
| LMY48M             | android-5.1.1_r14           | Lollipop           | Nexus 4、Nexus 5、Nexus 6、Nexus 7 (flo)、Nexus 9 (volantis/volantisg)、Nexus 10 |                  |
| LVY48E             | android-5.1.1_r13           | Lollipop           | Nexus 6（仅面向 Google Fi）                                  |                  |
| LYZ28J             | android-5.1.1_r12           | Lollipop           | Nexus 6（仅面向 T-Mobile）                                   |                  |
| LMY48J             | android-5.1.1_r10           | Lollipop           | Nexus Player                                                 |                  |
| LMY48I             | android-5.1.1_r9            | Lollipop           | Nexus 4、Nexus 5、Nexus 6、Nexus 7 (flo)、Nexus 9 (volantis/volantisg)、Nexus 10 |                  |
| LVY48C             | android-5.1.1_r8            | Lollipop           | Nexus 6（仅面向 Google Fi）                                  |                  |
| LMY48G             | android-5.1.1_r6            | Lollipop           | Nexus 7 (flo)                                                |                  |
| LYZ28E             | android-5.1.1_r5            | Lollipop           | Nexus 6（仅面向 T-Mobile）                                   |                  |
| LMY47Z             | android-5.1.1_r4            | Lollipop           | Nexus 6（面向除 T-Mobile [美国] 之外的所有运营商）           |                  |
| LMY48B             | android-5.1.1_r3            | Lollipop           | Nexus 5                                                      |                  |
| LMY47X             | android-5.1.1_r2            | Lollipop           | Nexus 9 (volantis)                                           |                  |
| LMY47V             | android-5.1.1_r1            | Lollipop           | Nexus 7 (flo/grouper)、Nexus 10、Nexus Player                |                  |
| LMY47O             | android-5.1.0_r5            | Lollipop           | Nexus 4、Nexus 7 (flo/deb)                                   |                  |
| LMY47M             | android-5.1.0_r4            | Lollipop           | Nexus 6（仅面向 T-Mobile）                                   |                  |
| LMY47I             | android-5.1.0_r3            | Lollipop           | Nexus 5、Nexus 6                                             |                  |
| LMY47E             | android-5.1.0_r2            | Lollipop           | Nexus 6                                                      |                  |
| LMY47D             | android-5.1.0_r1            | Lollipop           | Nexus 5、Nexus 6、Nexus 7 (grouper/tilapia)、Nexus 10、Nexus Player |                  |
| LRX22L             | android-5.0.2_r3            | Lollipop           | Nexus 9 (volantis/volantisg)                                 |                  |
| LRX22G             | android-5.0.2_r1            | Lollipop           | Nexus 7 (flo/deb/grouper/tilapia)、Nexus 10                  |                  |
| LRX22C             | android-5.0.1_r1            | Lollipop           | Nexus 4、Nexus 5、Nexus 6 (shamu)、Nexus 7 (flo)、Nexus 9 (volantis/volantisg)、Nexus 10 |                  |
| LRX21V             | android-5.0.0_r7.0.1        | Lollipop           | Nexus Player (fugu)                                          |                  |
| LRX21T             | android-5.0.0_r6.0.1        | Lollipop           | Nexus 4                                                      |                  |
| LRX21R             | android-5.0.0_r5.1.0.1      | Lollipop           | Nexus 9 (volantis)                                           |                  |
| LRX21Q             | android-5.0.0_r5.0.1        | Lollipop           | Nexus 9 (volantis)                                           |                  |
| LRX21P             | android-5.0.0_r4.0.1        | Lollipop           | Nexus 7 (flo/grouper)、Nexus 10                              |                  |
| LRX21O             | android-5.0.0_r3.0.1        | Lollipop           | Nexus 5 (hammerhead)、Nexus 6 (shamu)                        |                  |
| LRX21M             | android-5.0.0_r2.0.1        | Lollipop           | Nexus Player (fugu)                                          |                  |
| LRX21L             | android-5.0.0_r1.0.1        | Lollipop           | Nexus 9 (volantis)                                           |                  |
| KTU84Q             | android-4.4.4_r2            | KitKat             | Nexus 5 (hammerhead)（仅面向新西兰的 2Degrees、澳大利亚的 Telstra 和印度） |                  |
| KTU84P             | android-4.4.4_r1            | KitKat             | Nexus 5、Nexus 7 (flo/deb/grouper/tilapia)、Nexus 4、Nexus 10 |                  |
| KTU84M             | android-4.4.3_r1.1          | KitKat             | Nexus 5 (hammerhead)                                         |                  |
| KTU84L             | android-4.4.3_r1            | KitKat             | Nexus 7 (flo/deb/grouper/tilapia)、Nexus 4、Nexus 10         |                  |
| KVT49L             | android-4.4.2_r2            | KitKat             | Nexus 7 (deb Verizon)                                        |                  |
| KOT49H             | android-4.4.2_r1            | KitKat             | Nexus 5、Nexus 7 (flo/deb/grouper/tilapia)、Nexus 4、Nexus 10 |                  |
| KOT49E             | android-4.4.1_r1            | KitKat             | Nexus 5、Nexus 7 (flo/deb/grouper/tilapia)、Nexus 4、Nexus 10 |                  |
| KRT16S             | android-4.4_r1.2            | KitKat             | Nexus 7 (flo/deb/grouper/tilapia)、Nexus 4、Nexus 10         |                  |
| KRT16M             | android-4.4_r1              | KitKat             | Nexus 5 (hammerhead)                                         |                  |
| JLS36I             | android-4.3.1_r1            | Jelly Bean         | Nexus 7 (deb)                                                |                  |
| JLS36C             | android-4.3_r3              | Jelly Bean         | Nexus 7 (deb)                                                |                  |
| JSS15R             | android-4.3_r2.3            | Jelly Bean         | Nexus 7 (flo)                                                |                  |
| JSS15Q             | android-4.3_r2.2            | Jelly Bean         | Nexus 7 (flo)                                                |                  |
| JSS15J             | android-4.3_r2.1            | Jelly Bean         | Nexus 7 (flo/deb)                                            |                  |
| JSR78D             | android-4.3_r2              | Jelly Bean         | Nexus 7 (deb)                                                |                  |
| JWR66Y             | android-4.3_r1.1            | Jelly Bean         | Galaxy Nexus、Nexus 7 (grouper/tilapia)、Nexus 4、Nexus 10   |                  |
| JWR66V             | android-4.3_r1              | Jelly Bean         | Galaxy Nexus、Nexus 7 (grouper/tilapia)、Nexus 4、Nexus 10   |                  |
| JWR66N             | android-4.3_r0.9.1          | Jelly Bean         | Galaxy Nexus、Nexus 7 (grouper/tilapia/flo)、Nexus 4、Nexus 10 |                  |
| JWR66L             | android-4.3_r0.9            | Jelly Bean         | Nexus 7                                                      |                  |
| JDQ39E             | android-4.2.2_r1.2          | Jelly Bean         | Nexus 4                                                      |                  |
| JDQ39B             | android-4.2.2_r1.1          | Jelly Bean         | Nexus 7                                                      |                  |
| JDQ39              | android-4.2.2_r1            | Jelly Bean         | Galaxy Nexus、Nexus 7、Nexus 4、Nexus 10                     |                  |
| JOP40G             | android-4.2.1_r1.2          | Jelly Bean         | Nexus 4                                                      |                  |
| JOP40F             | android-4.2.1_r1.1          | Jelly Bean         | Nexus 10                                                     |                  |
| JOP40D             | android-4.2.1_r1            | Jelly Bean         | Galaxy Nexus、Nexus 7、Nexus 4、Nexus 10                     |                  |
| JOP40C             | android-4.2_r1              | Jelly Bean         | Galaxy Nexus、Nexus 7、Nexus 4、Nexus 10                     |                  |
| JZO54M             | android-4.1.2_r2.1          | Jelly Bean         |                                                              |                  |
| JZO54L             | android-4.1.2_r2            | Jelly Bean         |                                                              |                  |
| JZO54K             | android-4.1.2_r1            | Jelly Bean         | Nexus S、Galaxy Nexus、Nexus 7                               |                  |
| JRO03S             | android-4.1.1_r6.1          | Jelly Bean         | Nexus 7                                                      |                  |
| JRO03R             | android-4.1.1_r6            | Jelly Bean         | Nexus S 4G                                                   |                  |
| JRO03O             | android-4.1.1_r5            | Jelly Bean         | Galaxy Nexus                                                 |                  |
| JRO03L             | android-4.1.1_r4            | Jelly Bean         | Nexus S                                                      |                  |
| JRO03H             | android-4.1.1_r3            | Jelly Bean         |                                                              |                  |
| JRO03E             | android-4.1.1_r2            | Jelly Bean         | Nexus S                                                      |                  |
| JRO03D             | android-4.1.1_r1.1          | Jelly Bean         | Nexus 7                                                      |                  |
| JRO03C             | android-4.1.1_r1            | Jelly Bean         | Galaxy Nexus                                                 |                  |
| IMM76L             | android-4.0.4_r2.1          | Ice Cream Sandwich |                                                              |                  |
| IMM76K             | android-4.0.4_r2            | Ice Cream Sandwich | Galaxy Nexus                                                 |                  |
| IMM76I             | android-4.0.4_r1.2          | Ice Cream Sandwich | Galaxy Nexus                                                 |                  |
| IMM76D             | android-4.0.4_r1.1          | Ice Cream Sandwich | Nexus S、Nexus S 4G、Galaxy Nexus                            |                  |
| IMM76              | android-4.0.4_r1            | Ice Cream Sandwich |                                                              |                  |
| IML77              | android-4.0.3_r1.1          | Ice Cream Sandwich |                                                              |                  |
| IML74K             | android-4.0.3_r1            | Ice Cream Sandwich | Nexus S                                                      |                  |
| ICL53F             | android-4.0.2_r1            | Ice Cream Sandwich | Galaxy Nexus                                                 |                  |
| ITL41F             | android-4.0.1_r1.2          | Ice Cream Sandwich | Galaxy Nexus                                                 |                  |
| ITL41D             | android-4.0.1_r1.1          | Ice Cream Sandwich | Galaxy Nexus                                                 |                  |
| ITL41D             | android-4.0.1_r1            | Ice Cream Sandwich | Galaxy Nexus                                                 |                  |
| GWK74              | android-2.3.7_r1            | Gingerbread        | Nexus S 4G                                                   |                  |
| GRK39F             | android-2.3.6_r1            | Gingerbread        | Nexus One、Nexus S                                           |                  |
| GRK39C             | android-2.3.6_r0.9          | Gingerbread        | Nexus S                                                      |                  |
| GRJ90              | android-2.3.5_r1            | Gingerbread        | Nexus S 4G                                                   |                  |
| GRJ22              | android-2.3.4_r1            | Gingerbread        | Nexus One、Nexus S、Nexus S 4G                               |                  |
| GRJ06D             | android-2.3.4_r0.9          | Gingerbread        | Nexus S 4G                                                   |                  |
| GRI54              | android-2.3.3_r1.1          | Gingerbread        | Nexus S                                                      |                  |
| GRI40              | android-2.3.3_r1            | Gingerbread        | Nexus One、Nexus S                                           |                  |
| GRH78C             | android-2.3.2_r1            | Gingerbread        | Nexus S                                                      |                  |
| GRH78              | android-2.3.1_r1            | Gingerbread        | Nexus S                                                      |                  |
| GRH55              | android-2.3_r1              | Gingerbread        | 使用 Gingerbread 最早期版本的设备、Nexus S                   |                  |
| FRK76C             | android-2.2.3_r2            | Froyo              |                                                              |                  |
| FRK76              | android-2.2.3_r1            | Froyo              |                                                              |                  |
| FRG83G             | android-2.2.2_r1            | Froyo              | Nexus One                                                    |                  |
| FRG83D             | android-2.2.1_r2            | Froyo              | Nexus One                                                    |                  |
| FRG83              | android-2.2.1_r1            | Froyo              | Nexus One                                                    |                  |
| FRG22D             | android-2.2_r1.3            | Froyo              |                                                              |                  |
| FRG01B             | android-2.2_r1.2            | Froyo              |                                                              |                  |
| FRF91              | android-2.2_r1.1            | Froyo              | Nexus One                                                    |                  |
| FRF85B             | android-2.2_r1              | Froyo              | Nexus One                                                    |                  |
| EPF21B             | android-2.1_r2.1p2          | Eclair             |                                                              |                  |
| ESE81              | android-2.1_r2.1s           | Eclair             |                                                              |                  |
| EPE54B             | android-2.1_r2.1p           | Eclair             | Nexus One                                                    |                  |
| ERE27              | android-2.1_r2              | Eclair             | Nexus One                                                    |                  |
| ERD79              | android-2.1_r1              | Eclair             | Nexus One                                                    |                  |
| ESD56              | android-2.0.1_r1            | Eclair             |                                                              |                  |
| ESD20              | android-2.0_r1              | Eclair             |                                                              |                  |
| DMD64              | android-1.6_r1.5            | Donut              |                                                              |                  |
| DRD20              | android-1.6_r1.4            |                    |                                                              |                  |
| DRD08              | android-1.6_r1.3            |                    |                                                              |                  |
| DRC92              | android-1.6_r1.2            |                    |                                                              |                  |

https://mirror.tuna.tsinghua.edu.cn/help/git-repo/

https://mirrors.ustc.edu.cn/help/aosp.html

