清华：https://pypi.tuna.tsinghua.edu.cn/simple

阿里云：http://mirrors.aliyun.com/pypi/simple/

中国科技大学 https://pypi.mirrors.ustc.edu.cn/simple/

华中理工大学：http://pypi.hustunique.com/

山东理工大学：http://pypi.sdutlinux.org/

豆瓣：http://pypi.douban.com/simple/

## Linux

修改 ~/.pip/pip.conf (没有就创建一个文件夹及文件。文件夹要加“.”，表示是隐藏文件夹)

内容如下：

````pascal
 [global]
 index-url = https://pypi.tuna.tsinghua.edu.cn/simple
 [install]
 trusted-host=mirrors.aliyun.com
````

## windows

windows下，找到c盘–>用户–>admin(自己电脑名称) ，创建一个pip目录，如：C:\Users\xx\pip，新建文件 pip.ini。内容同上。





python -m pip install --upgrade pip