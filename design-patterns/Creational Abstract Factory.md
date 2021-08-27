

## Abstract Factory





![image-20210209171340719](.\img\image-20210209171340719.png)





```java
    //抽象产品类-- CPU
    public abstract class CPU {
        public abstract void showCPU();
    }
    //抽象产品类-- 内存
    public abstract class Memory {
        public abstract void showMemory();
    }
    //抽象产品类-- 硬盘
    public abstract class HD {
        public abstract void showHD();
    }
```

```java
    //具体产品类-- Intet CPU
    public class IntelCPU extends CPU {

        @Override
        public void showCPU() {
            System.out.println("Intet CPU");
        }
    }
    
    //具体产品类-- AMD CPU
    public class AmdCPU extends CPU {

        @Override
        public void showCPU() {
            System.out.println("AMD CPU");
        }
    }

    //具体产品类-- 三星 内存
    public class SamsungMemory extends Memory {

        @Override
        public void showMemory() {
            System.out.println("三星 内存");
        }
    }
    
    //具体产品类-- 金士顿 内存
    public class KingstonMemory extends Memory {

        @Override
        public void showMemory() {
            System.out.println("金士顿 内存");
        }
    }

    //具体产品类-- 希捷 硬盘
    public class SeagateHD extends HD {

        @Override
        public void showHD() {
            System.out.println("希捷 硬盘");
        }
    }

    //具体产品类-- 西部数据 硬盘
    public class WdHD extends HD {

        @Override
        public void showHD() {
            System.out.println("西部数据 硬盘");
        }
    }
```





```java
    //抽象工厂类，电脑工厂类
    public abstract class ComputerFactory {
        public abstract CPU createCPU();

        public abstract Memory createMemory();

        public abstract HD createHD();
    }
```



```java
//具体工厂类--联想电脑
    public class LenovoComputerFactory extends ComputerFactory {

        @Override
        public CPU createCPU() {
            return new IntelCPU();
        }

        @Override
        public Memory createMemory() {
            return new SamsungMemory();
        }

        @Override
        public HD createHD() {
            return new SeagateHD();
        }
    }
    
    //具体工厂类--华硕电脑
    public class AsusComputerFactory extends ComputerFactory {

        @Override
        public CPU createCPU() {
            return new AmdCPU();
        }

        @Override
        public Memory createMemory() {
            return new KingstonMemory();
        }

        @Override
        public HD createHD() {
            return new WdHD();
        }
    }
    
    //具体工厂类--惠普电脑
    public class HpComputerFactory extends ComputerFactory {

        @Override
        public CPU createCPU() {
            return new IntelCPU();
        }

        @Override
        public Memory createMemory() {
            return new KingstonMemory();
        }

        @Override
        public HD createHD() {
            return new WdHD();
        }
    }
```

```java
		System.out.println("--------------------生产联想电脑-----------------------");
        ComputerFactory lenovoComputerFactory = new LenovoComputerFactory();
        lenovoComputerFactory.createCPU().showCPU();
        lenovoComputerFactory.createMemory().showMemory();
        lenovoComputerFactory.createHD().showHD();

        System.out.println("--------------------生产华硕电脑-----------------------");
        ComputerFactory asusComputerFactory = new AsusComputerFactory();
        asusComputerFactory.createCPU().showCPU();
        asusComputerFactory.createMemory().showMemory();
        asusComputerFactory.createHD().showHD();
        
        System.out.println("--------------------生产惠普电脑-----------------------");
        ComputerFactory hpComputerFactory = new HpComputerFactory();
        hpComputerFactory.createCPU().showCPU();
        hpComputerFactory.createMemory().showMemory();
        hpComputerFactory.createHD().showHD();
```