每一个class文件都对应着唯一一个类或接口的定义信息，但是相对的，类或接口并不一定都必须定义在文件里（比如类或接口也可以通过类加载器直接生成）。

## ClassFile孔结构

```apl
ClassFile {
	u4 magic;
	u2 minor_version;
	u2 major_version;
	u2 constant_pool_count;
	cp_info constant_pool[constant_pool_count-1];
	u2 access_flags;
	u2 this_class;
	u2 super_class;
	u2 interfaces_count;
	u2 interfaces[interfaces_count];
	u2 fields_count;
	field_info fields[fields_count];
	u2 methods_count;
	method_info methods[methods_count];
	u2 attributes_count;
	attribute_info attributes[attributes_count];
}
```

### magic(魔数)

固定值0xCAFEBABE，作用就是被虚拟机识别为这是一个class文件

### minor_version、major_version

副版本号与主版本号

### constant_pool_count

常量池数数量，注意它的值等于常量池表中的成员数 + 1

### constant_pool[]

常量池，常量池以 1 ~ constant_pool_count-1为索引

虽然值为0的constant_pool索引是无效的，但其他用到常量池的数据结构可以使用索引0标识“不引用任何一个常量池项”

### access_flags

类或接口的访问标志

| 标志名         | 值     | 含义                                                   |
| -------------- | ------ | ------------------------------------------------------ |
| ACC_PUBLIC     | 0x0001 | 声明为public                                           |
| ACC_FINAL      | 0x0010 | 声明为final，不允许有子类                              |
| ACC_SUPER      | 0x0020 | 当用到 invokespecial 指令时，需要对父类方法做特殊处理  |
| ACC_INTERFACE  | 0x0200 | 定义为接口，没有该标识就表示这个一个类                 |
| ACC_ABSTRACT   | 0x0400 | 声明为abstract                                         |
| ACC_SYNTHETIC  | 0x1000 | 声明为synthetic，表示该class文件并非由java源代码所生成 |
| ACC_ANNOTATION | 0x2000 | 标识注解类型                                           |
| ACC_ENUM       | 0x4000 | 标识枚举类型                                           |

“特殊处理”是相对JDK1.0.2之前的class文件而言的，invokespecial 的语义、处理方式在JDK1.0.2时发生了改变，在JDK1.0.2之后编译出的class文件都带有ACC_SUPER标志用以区分



### this_class

The value of the `this_class` item must be a valid index into the `constant_pool table`. The constant_pool entry at that index must be a
`CONSTANT_Class_info` structure.

### super_class

对于类来说，