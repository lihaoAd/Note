## 防火墙

```
// 查看防火墙状态
systemctl status firewalld.service 
// 关闭防火墙
systemctl stop firewalld.service    
// 禁用防火墙
systemctl disable firewalld.service

```

## 配置本地ssh 免密登录 



```
yum install openssh-server

//  生成秘钥文件
ssh-keygen -t rsa

// 公钥导入授权文件就可以 
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

```



## python配置



```
wget https://www.python.org/ftp/python/3.7.8/Python-3.7.8.tar.xz
tar -xvJf  Python-3.7.8.tar.xz

mkdir /usr/local/python3 #创建编译安装目录

cd Python-3.8.0

./configure --enable-optimizations --prefix=/opt/python3  --with-ssl
./configure  --prefix=/opt/python3  --with-ssl

make && make install

ln -s /usr/local/python3/bin/python3 /usr/local/bin/python3
ln -s /usr/local/python3/bin/pip3 /usr/local/bin/pip3

```

```py
 yum install  bzip2-devel
 
 yum install libffi-devel
 
 yum install -y xz-devel
```







## hadoop配置

- core-site.xml 

  ```
  <property>
    <name>fs.default.name</name>
    <value>hdfs://hadoop000:8020</value>
  </property>
  ```

- yarn-site.xml

  ```
  <property>
      <name>yarn.nodemanager.aux-services</name>
      <value>mapreduce_shuffle</value>
  </property>
  ```

  

- mapred-site.xml

  ```
  <property>
      <name>mapreduce.framework.name</name>
      <value>yarn</value>
  </property>
  ```

- hdfs-site.xml

  ```
  <property>
      <name>dfs.namenode.name.dir</name>
      <value>/opt/hadoop2/app/tmp/dfs/name</value>
  </property>
  <property>
      <name>dfs.datanode.data.dir</name>
      <value>/opt/hadoop2/app/tmp/dfs/data</value>
  </property>
  <property>
      <name>dfs.replication</name>
      <value>1</value>
  </property>
  ```

- slaves

​        里面内容修改为master

- hdfs namenode -format

  ```
  hdfs namenode -format
  ```

  ### QA

  - The authenticity of host '0.0.0.0 (0.0.0.0)' can't be established.

  ```
  ssh  -o StrictHostKeyChecking=no  0.0.0.0
  ```

启动后可以通过 http://192.168.117.139:50070/ 访问， ip改成自己的ip



## 环境配置


```

export JAVA_HOME=/opt/jdk8
export JRE_HOME=${JAVA_HOME}/lib
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib:$CLASSPATH

export PYTHON_HOME=/opt/python3

export SPARK_HOME=/opt/spark2

export HADOOP_HOME=/opt/hadoop2

alias python=python3
export PYSPARK_PYTHON=python3

export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native

export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PYTHON_HOME/bin:$JAVA_HOME/bin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH

```

