---
aliases:
- 得分匹配
date: 2025-07-21 13:07:00+08:00
description: null
draft: false
modified: 2025-07-23 20:49:00+08:00
source: https://andrewcharlesjones.github.io/journal/21-score-matching.html
tags:
- cornerstone
title: Score matching详解！
---

我觉得 [Score matching by Andy Jones](https://andrewcharlesjones.github.io/journal/21-score-matching.html) 说得挺清楚了，所以这一篇笔记主要是回忆性质，记下几个 key point 和 key idea。

- [ ] Score-matching 要解决的问题是？
- [ ] 如何理解 Score 函数？Score 函数是如何解决 normalizing constant 的问题的？
- [ ] 如何衡量两个分布的梯度的差距？为什么用 Fisher 散度？
- [ ] 为什么涉及到真实分布 $p_d(x)$ 的就不好求？

# 🙋什么是 Score Matching？

> [!ABSTRACT] Score Matching
> Score Matching 是一种用于拟合统计模型的方法，特别适用于处理不可计算归一化常数（intractable normalizing constants）的模型。在机器学习中，当模型的似然函数复杂且难以归一化时（例如在能量基模型（EBMs）、生成对抗网络（GANs）或变分自编码器（VAEs 中），Score Matching 提供了一种绕过归一化常数的方法来优化模型参数。

假设我们有一组观测数据 $x_1, \dots, x_n$，这些数据服从未知的真实分布 $p_d(x)$。我们希望用一个参数化的模型 model 分布 $p_m(x; \theta)$ 来近似 distribution $p_d(x)$，其中 $\theta$ 是模型参数。目标是找到合适的 $\theta$，使 $p_m(x; \theta)$ 尽可能接近 $p_d(x)$。
在最大似然估计（MLE）中，我们通常通过最大化数据的对数似然来优化 $\theta$：

$$
\widehat{\theta}_{MLE} = argmax_{\theta} \log p_m(x; \theta).
$$

模型的概率密度函数通常可以写成未归一化的密度 $\widetilde{p}(x; \theta)$ 和归一化常数 $Z_\theta$ 的形式：

$$
p_m(x; \theta) = \frac{\widetilde{p}(x; \theta)}{Z_\theta}, \quad Z_\theta = \int_{\mathcal{X}} \widetilde{p}(x; \theta) , dx.
$$

这里的 $Z_\theta$ 是一个 normalizing constant，通常在复杂模型中难以计算（即不可解，intractable）。Score Matching 的核心思想是通过避免直接计算 $Z_\theta$，来解决这一问题。

> [!QUESTION]- 我觉得这里完全有必要说一下：难在哪儿？为什么不能求出 $p_d(x)$？
>
> > [!NOTE]
> > 因为**真实分布只有样本，没有分布**，我们可以假设模型分布 $p_m$ 为高斯啦学生分布啦等等，但是真实分布通常有可能是高斯混合模型，很难搞。所以我们得想办法消除 $p_d(x)$ 这一项。在后文中还会出现一次 $p_{m}$ 项，留意之。

## 💡Score Matching 的核心思想

其实我们如果注意到，对上面的 model 分布 p 对 x 求梯度，那么 Z 这一项就会消失（因为参数里没有 x）。
在 Score Matching 中，==score 函数==是指对数似然函数关于数据 $x$ 的梯度：

$$
\nabla_x \log p_m(x; \theta).  
$$

将其展开，我们可以看到归一化常数的优势：

$$
\nabla_x \log p_m(x; \theta) = \nabla_x \log \widetilde{p}_m(x; \theta) - \nabla_x \log Z_\theta.
$$

由于 $Z_\theta$ 不依赖于 $x$，其梯度 $\nabla_x \log Z_\theta = 0$，因此：

$$
\nabla_x \log p_m(x; \theta) = \nabla_x \log \widetilde{p}_m(x; \theta).
$$

Normalizing constant Z 消失了！那么 Score matching 的核心思想变呼之欲出：**如果建模分布 $p_m$ 与原始分布 $p_d$ 相似，那么他们的梯度也应该相似**。最后顶多差一个偏移而已。

## 🎯Score Matching 的目标

Score Matching 的目标是最小化模型分布的 score 函数与真实数据分布的 score 函数之间的 Fisher 散度（Fisher Divergence）：

$$
\widehat{\theta}_{SM} = argmin_{\theta} D_F(p_d, p_m) = argmin_{\theta} \frac{1}{2} \mathbb{E}_{p_d} \left[ | \nabla_x \log p_d(x) - \nabla_x \log p_m(x; \theta) |_2^2 \right].
$$

> [!NOTE] 这是因为只有 fisher 散度可以跟梯度联系起来，而 KL 散度是做不到的。

但到了这里还是有 $p_d(x)$ 项，还是不好求。所以自然地想到下一步要怎么做。

## ↻绕过归一化常数和数据分布

1. 展开 Fisher 散度：

$$
\frac{1}{2} | \nabla_x \log p_d(x) - \nabla_x \log p_m(x; \theta) |_2^2 = \frac{1}{2} (\nabla_x \log p_d(x))^2 - \nabla_x \log p_m(x; \theta) \nabla_x \log p_d(x) + \frac{1}{2} (\nabla_x \log p_m(x; \theta))^2.
$$

- 第一项 $\frac{1}{2} (\nabla_x \log p_d(x))^2$ 是常数项，不依赖 $\theta$，不影响优化 $\theta$，可以忽略。
- 第三项 $\frac{1}{2} (\nabla_x \log p_m(x; \theta))^2$ 可以通过数据样本直接估计，因为它不依赖 $p_d(x)$。

2. 处理交叉项：

$$
\mathbb{E}_{p_d} \left[ -\nabla_x \log p_m(x; \theta) \nabla_x \log p_d(x) \right] = -\int_{-\infty}^{\infty} \nabla_x \log p_m(x; \theta) \nabla_x \log p_d(x) p_d(x) , dx.
$$

通过**分部积分法（integration by parts）**~~（这里很巧妙但是我不细写了）~~，假设边界项在无穷远处消失（即 $p_d(x) \nabla_x \log p_m(x; \theta) \to 0$ 当 $|x|_2 \to \infty$），我们可以将交叉项转化为：

$$
\int_{-\infty}^{\infty} \nabla_x^2 \log p_m(x; \theta) p_d(x) dx.
$$

那么问题来了：==为什么会假设边界项消失？==

> [!NOTE] 边界项消失
> 边界项 $p_d(x) \nabla_x \log p_m(x; \theta) \to 0$ 当 $|x|_2 \to \infty$ 是一个正则化条件，确保分部积分成立。直观上：
>
> - 数据分布 $p_d(x)$ 通常在无穷远处迅速衰减到零，因为实际数据集中在有限区域，尾部概率很小。例如高斯分布 $p_d(x) \propto \exp(-x^2 / (2\sigma_d^2))$ 的尾部以指数速度衰减。
> - 模型 score 函数 $\nabla_x \log p_m(x; \theta)$ 通常增长较慢（例如高斯模型中为线性增长）。因此，乘积 $p_d(x) \nabla_x \log p_m(x; \theta)$ 在无穷远处趋于零，因为数据分布的尾部衰减比 score 函数的增长快。
> - 这就像在积分中，尾部贡献变得微不足道，因为数据分布在无穷远处几乎没有概率质量。

在高斯分布的例子中：

$$
p_d(x)\nabla_x \log p_m(x;\mu,\sigma^2)
\sim
\exp\!\left(-\frac{x^{2}}{2\sigma_d^{2}}\right)\cdot\frac{\mu-x}{\sigma^{2}}
\to 0
$$

因为指数衰减比线性增长快得多。

3. 因为 $\nabla_x^2 \log p_m(x; \theta) p_d(x)  dx$ 在大于等于 2 阶情况下的其实是个 Hessian 矩阵，对角线的元素才是对 x 求二阶导，所以写成 tr 的形式

$$
\int_{-\infty}^{\infty} \nabla_x^2 \log p_m(x; \theta) p_d(x) dx = \mathbb{E}_{p_d} \left[ \text{tr} \left( \nabla_x^2 \log p_m(x; \theta) \right) \right]
$$

所以损失函数：

$$
D_F(p_d, p_m) \propto L(\theta) = \mathbb{E}_{p_d} \left[ \text{tr} \left( \nabla_x^2 \log p_m(x; \theta) \right) + \frac{1}{2} ||\nabla_x \log p_m(x; \theta)||_2^2 \right].
$$

使用数据样本 $x_1, \dots, x_n$，目标函数可近似为：

$$
L(\theta) \approx \frac{1}{n} \sum_{i=1}^n \left[ \text{tr} \left( \nabla_x^2 \log p_m(x_i; \theta) \right) + \frac{1}{2} |\nabla_x \log p_m(x_i; \theta)|_2^2 \right].
$$

这个目标函数完全不依赖归一化常数 $Z_\theta$ 和真实分布 $p_d(x)$，只需要模型的未归一化密度 $\widetilde{p}_m(x; \theta)$ 和数据样本即可。
Hyvärinen 证明，如果真实分布 $p_d(x) = p_m(x; \theta^\star)$ 属于模型族，则优化 $L(\theta)$ 可找到最优参数 $\theta^\star$。

> 只要真实分布 **恰好能被模型族中的某个参数** $\theta^\star$ 表示出来，那么**最小化得分匹配目标 $L(θ)$** 就一定能把这个 $\theta^\star$ 找出来。

## 🤔目标函数的直观理解

目标函数由两部分组成：

1. Norm 项：$\frac{1}{2} |\nabla_x \log p_m(x_i; \theta)|_2^2$
    - 表示模型 score 函数的大小。
    - 当数据点 $x_i$ 被模型很好地解释时（即位于似然的高概率区域），score 函数的值较小（似然变化平缓）。
    - 直观上，这个项希望模型的似然函数在数据点附近平滑。
2. Hessian 项：$\text{tr} \left( \nabla_x^2 \log p_m(x_i; \theta) \right)$
    - 表示对数似然的二阶导数（Hessian 矩阵的迹）。
    - 如果数据点位于“尖锐”的局部极小值处（Hessian 迹为负且绝对值较大），说明模型对数据的解释更“独特”。
    - 直观上，这个项倾向于选择更“尖锐”的似然函数，避免过于平坦的似然（平坦的似然意味着多种参数值都能解释数据）。

这两个项相互平衡：Norm 项倾向于平滑的似然，Hessian 项倾向于尖锐的似然，优化 $L(\theta)$ 找到既能解释数据又具有适当曲率的模型。

# 📖方法论

所以总结一下，最后其实很简单——甚至损失函数只和 $p_m$ 有关。假设了 $p_m$ 的分布之后：
1. 先求其关于训练数据的一阶导数的平方（Norm 项）
2. 再在 Norm 项算式的基础上求其二阶导（Hessian 项）
3. 相加，求 $argmin_{\theta}$，就完事儿了。[Score matching by Andy Jones](https://andrewcharlesjones.github.io/journal/21-score-matching.html) 的最后举了一个高斯的例子，很不错。

# 📚 延伸阅读

- Hyvärinen (2005): 原始论文，提出得分匹配。
- Song & Ermon (2019): 使用得分匹配进行生成建模。
- Sliced Score Matching (2020): 可扩展版本，适用于高维数据。