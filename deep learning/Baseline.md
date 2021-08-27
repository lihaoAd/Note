## 概述

之前用用户向量与物品向量计算相似度，但是如果是一个稀疏数组，组数中有大量的None值，可能导致有的相似度无法计算。一般在生产环境中也不用这种方式。



## Baseline

是一种基于回归模型的协同过滤。如果我们将评分看作是一个连续的值而不是离散的值，那么就可以借助线性回归思想来预测目标用户对某物品的评分。其中一种实现策略被称为Baseline（基准预测）。



### Baseline设计思想

- 有些用户的评分普遍高于其他用户，有些用户的评分普遍低于其他用户。比如有些用户天生愿意给别人好评，心慈手软，比较好说话，而有的人就比较苛刻，总是评分不超过3分（5分满分）

- 一些物品的评分普遍高于其他物品，一些物品的评分普遍低于其他物品。比如一些物品一被生产便决定了它的地位，有的比较受人们欢迎，有的则被人嫌弃。

  

  这个用户或物品普遍高于或低于平均值的差值，我们称为偏置(bias)



### Baseline目标

- 找出每个用户普遍高于或低于他人的偏置值 b<sub>u</sub>

- 找出每件物品普遍高于或低于其他物品的偏置值 b<sub>i</sub>
- 我们的目标也就转化为寻找最优的b<sub>u</sub> 和 b<sub>i</sub>

$$
平方差就是，r_{ui}表示的是用户u对物品i的评分，\widehat r_{ui}表示的是预测值\\预测值\widehat r_{ui} = 所有的评分平均数+ b{u} + b_{i}\\
即 \widehat r_{ui} = u + b{u} + b_{i}\\
Cost= \sum_{u,i∈R}(r_{ui} - \widehat r_{ui})^{2} = \sum_{u,i∈R}(r_{ui} - u - b{u} - b_{i})^{2}\\
$$

为了防止过度拟合，正则化
$$
Cost= \sum_{u,i∈R}(r_{ui} - u - b{u} - b_{i})^{2} + \lambda*(\sum_{u}b_{u}^{2} +\sum_{i}b_{i}^{2} )
$$

### 梯度下降

上式中已经是 b<sub>u</sub> 与 b<sub>i</sub> 的二元函数
$$
J(\theta) = f(b_u,b_i)\\
J(\theta) := J(\theta) - \alpha \nabla{J(\theta)}
$$

$$
\frac{\partial}{\partial{b_u}}J(\theta) = \frac{\partial}{\partial{b_u}}f(b_u,b_i)  = 2\sum_{u,i∈R}(r_{ui} -u-b_u-b_i) \cdot(-1)+2\lambda\sum_{u}b_u\\

\frac{\partial}{\partial{b_i}}J(\theta) = \frac{\partial}{\partial{b_i}}f(b_u,b_i)  = 2\sum_{u,i∈R}(r_{ui} -u-b_u-b_i) \cdot(-1)+2\lambda\sum_{i}b_i\\
$$

带入梯度公式
$$
b_u:= b_u - \alpha \frac{\partial}{\partial{b_u}}J(\theta)=
b_u -\alpha (2\sum_{u,i∈R}(r_{ui} -u-b_u-b_i) \cdot(-1)+2\lambda\sum_{u}b_u)\\
因为\alpha 是人为控制的，公式可以简化为\\
b_u:= b_u - \alpha \frac{\partial}{\partial{b_u}}J(\theta)=
b_u +\alpha (\sum_{u,i∈R}(r_{ui} -u-b_u-b_i)-\lambda\sum_{u}b_u)\\
b_i:= b_i - \alpha \frac{\partial}{\partial{b_i}}J(\theta)=
bi +\alpha (\sum_{u,i∈R}(r_{ui} -u-b_u-b_i)-\lambda\sum_{i}b_i)
$$
上式中需要计算每个用户对物品的评分与预测评分的和，可以使用**随机梯度下降**

由于**随机梯度下降法**本质上利用**每个样本的损失**来更新参数，而不用每次求出全部的损失和
$$
error = r_{ui} - \widehat r_{ui} = r_{ui} - u - b{u} - b_{i}\\

b_u:= 
b_u +\alpha [(r_{ui} -u-b_u-b_i)-\lambda b_u]\\
b_i:= 
bi +\alpha [(r_{ui} -u-b_u-b_i)-\lambda b_i]

$$


## 算法实现

```python
降最高迭代次数
        self.number_epochs = number_epochs
        # 学习率或者跨步
        self.alpha = alpha
        # 正则参数
        self.reg = reg
        # 数据集中user-item-rating字段的名称
        self.columns = columns

    def fit(self, dataset):
        '''
        :param dataset: uid, iid, rating
        :return:
        '''
        self.dataset = dataset
        # 用户评分数据
        print(self.dataset.itertuples(index=False))
        self.users_ratings = dataset.groupby(self.columns[0]).agg([list])[[self.columns[1], self.columns[2]]]
        # 物品评分数据
        self.items_ratings = dataset.groupby(self.columns[1]).agg([list])[[self.columns[0], self.columns[2]]]
        # 计算全局平均分
        self.global_mean = self.dataset[self.columns[2]].mean()
        # 调用sgd方法训练模型参数
        self.bu, self.bi = self.sgd()

        self.showChart()
    def sgd(self):
        '''
        利用随机梯度下降，优化bu，bi的值
        :return: bu, bi
        '''
        # 初始化bu、bi的值，全部设为0
        bu = dict(zip(self.users_ratings.index, np.zeros(len(self.users_ratings))))
        bi = dict(zip(self.items_ratings.index, np.zeros(len(self.items_ratings))))

        for i in range(self.number_epochs):
            print("iter %d" % i)
            for uid, iid, real_rating in self.dataset.itertuples(index=False):
                error = real_rating - (self.global_mean + bu[uid] + bi[iid])

                bu[uid] += self.alpha * (error - self.reg * bu[uid])
                bi[iid] += self.alpha * (error - self.reg * bi[iid])


        return bu, bi

    def predict(self, uid, iid):
        '''预测'''
        predict_rating = self.global_mean + self.bu[uid] + self.bi[iid]
        return predict_rating

    def showChart(self):
        import matplotlib.pyplot as plt

        plt.rcParams['font.sans-serif'] = ['SimHei']  # 用来正常显示中文标签
        plt.rcParams['axes.unicode_minus'] = False  # 用来正常显示负号
        plt.title("匹配结果")
        userId = self.users_ratings.index.values[10]
        # 查看指定用户的预测曲线

        # 找到该用户评分的电影

        movie_ids = []
        real_ratings = []
        for uid, iid, real_rating in self.dataset.itertuples(index=False):
            if uid == userId:
                movie_ids.append(iid)
                real_ratings.append(real_rating)
        model = make_interp_spline(movie_ids, real_ratings)
        xs = np.linspace(min(movie_ids), max(movie_ids), 1000)
        ys = model(xs)

        plt.plot(xs, ys, color='green', label='training accuracy')
        predict_ratings = []
        for iid in movie_ids:
            predict_ratings.append(self.predict(userId, iid))
        model = make_interp_spline(movie_ids, predict_ratings)
        xs = np.linspace(min(movie_ids), max(movie_ids), 1000)
        ys = model(xs)
        plt.plot(xs, ys, color='red', label='training accuracy')
        plt.xticks([])
        plt.yticks([])
        plt.show()


if __name__ == '__main__':
    dtype = [("userId", np.int32), ("movieId", np.int32), ("rating", np.float32)]
    dataset = pd.read_csv("datasets/ml-latest-small/ratings.csv", usecols=range(3), dtype=dict(dtype))
    bcf = BaselineCFBySGD(10, 0.1, 0.1, ["userId", "movieId", "rating"])
    bcf.fit(dataset)

    # while True:
    #     uid = int(input("uid: "))
    #     iid = int(input("iid: "))
    #     print(bcf.predict(uid, iid))
```

![image-20210306181256503](img\image-20210306181256503.png)

## 交替最小二乘法
最小二乘法和梯度下降法一样，可以用于求极值，最小二乘法思想：对损失函数求偏导，然后再使偏导为0


