

##  数字

```python
print(1/2)     # 0.5
print(1/2.0)   # 0.5
print(1//2)    # 0
print(5//2.0)  # 2.0
print(5%2.2)   # 0.5999999999999996
print(2**3)    # 8
```

## 变量

```python
x = 1   # 使用变量前先要赋值
print(x)

x = input("x:") # 获取用户输入
print(x)

x,y,z = 1,2,3 # 序列解包

x=y=10   # 链式赋值

```



## 序列

Python包含6中内建的序列：列表、元组、字符串、Unicode字符串、buffer对象、xrange对象

### 列表

列表可以修改，元组则不能。

```python
edward = ['Edward Gumby',43,[10,11],12,13,14,15] # 列表
print(edward[1])         # 索引
print(edward[2])
print(edward[-1])        # 索引可以为负数
print(edward[0:2])       # 分片
print(edward[:])         # 复制整个序列
print(edward[0:8:2])     # 步长
print(edward[8:0:-2])    # 步长可以为负数
print([1,2,3] + [4,5,6]) # 序列相加
print([1,2,3] *3)        # 相乘
print([None] *10)        # 初始化长度为10的列表
print('w' in 'hello world')  # true
print(5 in [1,2,3,4])    # false
print(len([1,2,3,4,5,5,6,6,67]))
print(min([1,2,3,4,5,5,6,6,67]))
print(max([1,2,3,4,5,5,6,6,67]))

x = [1,2,3,4]
x[0] = 2        # 修改
print(x)

del x[2]        # 删除
print(x)        # [2,2,4]

x.append(5)
print(x)

y = [7,8,9]
x.extend(y)     # extend方法修改了被扩展的序列，而原始的连接则不然，会返回一个全新的列表
print(x)
print(x.index(5))  # 第一个匹配项的索引位置
print(x)
x.insert(2,10)
print(x)
print(x.pop())      # 移除列表中最后一个元素，并且返回该元素的值
print(x)
print(x.remove(7))  # 移除列表中某个值的第一个匹配项，并不返回，所以这里是None
print(x)

x.reverse()
print(x)

x.sort()  # 默认升序
print(x)
```

### 元组

```python
x = 1,2,3
print(x)

y = (1,2,3)
print(y)

print(())   # 一个空元组
print((1,))   # 只有一个值的元组，需要有逗号

print(tuple([1,2,3,3,4,5]))   # (1, 2, 3, 3, 4, 5)
print(tuple("abcdefg"))       # ('a', 'b', 'c', 'd', 'e', 'f', 'g')
```

### 字符串

```python
print("hello world")   # 双引号
print('hello world')   # 单引号
print('hello world and "China"')
print('hello world '        'and "China"')  # 字符串拼接
print(str("hello world"))
print(str(10000))
print(repr("hello world"))  # repr会创建一个字符串，'hello world'

x = '''      # 三引号
#######
print("hello world")
print('hello world')
print('hello world and "China"')
print('hello world '        'and "China"')
#######
'''
print(x)
print(r'c:\User\Desktop')  # 原始字符串
print(u'hello world')  # unicode字符串，3.0中所有的字符串都是unicode字符串


## 格式化字符串
format = "Hello,%s,%s enough for ya?"
print(format % ("world","Hot"))

format = "Pi with three decimal : %.3f"
from math import pi
print(format % pi)
print('%10f' % pi)
print('%10.2f' % pi)
print('%010.2f' % pi)   # 0000003.14
print('%-10.2f' % pi)   # 左对齐
print('%+0.2f' % pi)    # +3.14

```

## 字典

```python
phonebook={"Alice":"2341","Beth":"9103"}
print(phonebook)

items = [("name","Gumby"),("age",32)]
d = dict(items)
print(d)        # {'name': 'Gumby', 'age': 32}
```

## 函数

```python
def print_params_1(*params):
    print(params)

print_params_1(1,2,3,4)    # (1, 2, 3, 4)

def print_params_2(title,*params):
    print(title)
    print(params)

print_params_2("hello",1,2,3,4)


def print_params_3(**params):
    print(params)

print_params_3(x=1,y=2,z=3)  # {'x': 1, 'y': 2, 'z': 3}
```



```python
date = "2020"

def print_date():
    date = "2021"
    print(date)

print_date()   # 2021
print(date)    # 2020
```

```python
date = "2020"

def print_date():
    global date
    date = "2021"
    print(date)

print_date()   # 2021
print(date)    # 2021
```

```python
name = "lisi"
def print_name_out():
    name = "zs"
    def print_name():     # 嵌套函数
        global name
        print(name)    # lisi
    print_name()

print_name_out()
print(name)    # lisi
```

##  对象





### 多态



### 封装



### 继承



## 异常

```python
raise Exception
```

```python
try:
    5/0
except:
    print("Error...")
```

```python
try:
    5/0
except ZeroDivisionError:
    print("ZeroDivisionError...")
```



```python
try:
    5/0
except ZeroDivisionError:
    print("ZeroDivisionError...")
    raise
```

```python
try:
    5/""
except ZeroDivisionError:
    print("ZeroDivisionError...")
except TypeError:
    print("TypeError...")
```

```python
try:
    5/""
except (ZeroDivisionError,TypeError,NameError):
    print("Error...")
```

```python
try:
    5/0
except Exception as err:
    print("Error..." + str(err))
```

```python
try:
    5/0
except Exception as err:
    print("Error..." + str(err))
finally:
    print("finally...")
```

```python
try:
    5/1
except ZeroDivisionError as err:
    print("Error..." + str(err))
else:                           # 在使用时必须放在所有的 except 子句后面,没有异常时执行
    print("OK，no error...")
finally:
    print("finally...")
```

## 模块

模块是包含 Python 定义和语句的文件。其文件名是模块名加后缀名 `.py` 。在模块内部，通过全局变量 `__name__` 可以获取模块名（即字符串）

注意，一般情况下，不建议从模块或包内导入 `*`

```
from fibo import *
```

这种方式会导入所有不以下划线（`_`）开头的名称。大多数情况下，不要用这个功能，这种方式向解释器导入了一批未知的名称，可能会覆盖已经定义的名称。