

## 简介

Systrace 是 Android4.1 中新增的性能数据采样和分析工具。它可帮助开发者收集 Android 关键子系统（如 SurfaceFlinger/SystemServer/Kernel/Input/Display 等 Framework 部分关键模块、服务，View系统等）的运行信息，从而帮助开发者更直观的分析系统瓶颈，改进性能。

## 语法

```scss
python systrace.py [options] [categories]
```

例如：

```scss
python systrace.py -t 10 -o mynewtrace.html sched freq idle am wm gfx view binder_driver hal dalvik input res
```

可能需要安装

 ```python
 python -m pip install pywin32
 python -m pip install six
 ```

如需查看已连接设备支持的类别列表，请运行以下命令：

```scss
python systrace.py --list-categories
```

| 命令和选项                                | 说明                                                         |
| :---------------------------------------- | :----------------------------------------------------------- |
| `-o file`                                 | 将 HTML 跟踪报告写入指定的文件。如果您未指定此选项，`systrace` 会将报告保存到 `systrace.py` 所在的目录中，并将其命名为 `trace.html`。 |
| `-t N | --time=N`                         | 跟踪设备活动 N 秒。如果您未指定此选项，`systrace` 会提示您在命令行中按 Enter 键结束跟踪。 |
| `-b N | --buf-size=N`                     | 使用 N KB 的跟踪缓冲区大小。使用此选项，您可以限制跟踪期间收集到的数据的总大小。 |
| `-k functions|--ktrace=functions`         | 跟踪逗号分隔列表中指定的特定内核函数的活动。                 |
| `-a app-name|--app=app-name`              | 启用对应用的跟踪，指定为包含[进程名称](https://developer.android.com/guide/topics/manifest/application-element?hl=zh-cn#proc)的逗号分隔列表。这些应用必须包含 `Trace` 类中的跟踪检测调用。您应在分析应用时指定此选项。很多库（例如 `RecyclerView`）都包括跟踪检测调用，这些调用可在您启用应用级跟踪时提供有用的信息。如需了解详情，请参阅[定义自定义事件](https://developer.android.com/topic/performance/tracing/custom-events?hl=zh-cn)。如需跟踪搭载 Android 9（API 级别 28）或更高版本的设备上的所有应用，请传递用添加引号的通配符字符 `"*"`。 |
| `--from-file=file-path`                   | 根据文件（例如包含原始跟踪数据的 TXT 文件）创建交互式 HTML 报告，而不是运行实时跟踪。 |
| `-e device-serial|--serial=device-serial` | 在已连接的特定设备（由对应的[设备序列号](https://developer.android.com/studio/command-line/adb?hl=zh-cn#devicestatus)标识）上进行跟踪。 |
| `categories`                              | 包含您指定的系统进程的跟踪信息，如 `gfx` 表示用于渲染图形的系统进程。您可以使用 `-l` 命令运行 `systrace`，以查看已连接设备可用的服务列表。 |

category可取值：

| category      | 解释                                                         |
| ------------- | ------------------------------------------------------------ |
| gfx           | Graphic系统的相关信息，包括SerfaceFlinger，VSYNC消息，Texture，RenderThread等；分析卡顿非常依赖这个。 |
| input         | Input                                                        |
| view          | View绘制系统的相关信息，比如onMeasure，onLayout等。。        |
| webview       | WebView                                                      |
| wm            | Window Manager                                               |
| am            | ActivityManager调用的相关信息；用来分析Activity的启动过程比较有效。 |
| sm            | Sync Manager                                                 |
| audio         | Audio                                                        |
| video         | Video                                                        |
| camera        | Camera                                                       |
| hal           | Hardware Modules                                             |
| app           | Application                                                  |
| res           | Resource Loading                                             |
| dalvik        | 虚拟机相关信息，比如GC停顿等。                               |
| rs            | RenderScript                                                 |
| bionic        | Bionic C Library                                             |
| power         | Power Management                                             |
| sched         | CPU调度的信息，非常重要；你能看到CPU在每个时间段在运行什么线程；线程调度情况，比如锁信息。 |
| binder_driver | Binder驱动的相关信息，如果你怀疑是Binder IPC的问题，不妨打开这个。 |
| core_services | SystemServer中系统核心Service的相关信息，分析特定问题用。    |
| irq           | IRQ Events                                                   |
| freq          | CPU Frequency                                                |
| idle          | CPU Idle                                                     |
| disk          | Disk I/O                                                     |
| mmc           | eMMC commands                                                |
| load          | CPU Load                                                     |
| sync          | Synchronization                                              |
| workq         | Kernel Workqueues                                            |
| memreclaim    | Kernel Memory Reclaim                                        |
| regulators    | Voltage and Current Regulators                               |

Wall Duration：函数执行时间（包含等待时间）

Self Time:函数执行时间（不包含等待时间）





参考：

https://perfetto.dev/docs/

https://www.androidperformance.com/2019/05/28/Android-Systrace-About/