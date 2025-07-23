---
aliases: []
date: 2025-07-21 19:07:00+08:00
description: null
draft: false
modified: 2025-07-23 19:48:10+08:00
tags: []
title: 做个具身智能的Review
---

# EAI Review

[宇树具身智能社群](https://www.unifolm.com/#/post/822)

---

# VLA

[知乎VLA综述](https://zhuanlan.zhihu.com/p/30971354645)

[具身智能中 VLA 主流方案全解析：技术总结与未来展望-CSDN博客](https://blog.csdn.net/CV_Autobot/article/details/145603274)

VLA 任务依靠视觉 - 语言 - 动作模型，输入是视觉 - 语言，生成动作序列。本质上是一个生成式多模态任务，跟咱们实验室的研究方向比较搭。但是与其他多模态任务不同的是硬件要求比较大。

硬件需求：机械臂，GPU 算力要求非常大。

经典方案如下。从下面的技术方案就可以看出 VLA 也是个搭网络、训练/微调大模型的活。

- **基于经典 Transformer 结构的方案**，如 ALOHA(ACT) 系列、RT-1、HPT 等，利用 Transformer 的序列建模能力，将强化学习轨迹建模为状态 - 动作 - 奖励序列，提升复杂环境下的决策能力；
- **基于预训练 LLM/VLM 的方案**，如 RT-2、OpenVLA 等，将 VLA 任务视为序列生成问题，借助预训练模型处理多模态信息并生成动作，增强泛化性和指令理解能力；
- **基于扩散模型的方案**，如 Diffusion Policy、RDT-1B 等，通过去噪扩散概率模型生成动作，适用于高维动作空间和复杂动作分布；
- **LLM+ 扩散模型方案**，如 Octoπ0 等，结合 LLM 的多模态表征压缩与扩散模型的动作生成能力，提高复杂任务中的性能；
- **视频生成 + 逆运动学方案**，如 UniPiRo、BoDreamer 等，先生成运动视频再通过逆运动学推导动作，提升可解释性和准确性；
- **显式端到端方案**直接将视觉语言信息映射到动作空间，减少信息损失；
- **隐式端到端方案**，如 SWIM 等，利用视频扩散模型预测未来状态并生成动作，注重知识迁移；
- **分层端到端方案，**结合高层任务规划与低层控制，提升长时域任务的执行效率。

个人觉得 VLA 里能做的非常多，探索空间也很大，难度也很高。目前完成度很好的是下面提到的 $\pi_0$ 模型，被博客作者认为是机器人的大模型时代。

## Paper List

- [π0——用于通用机器人控制的VLA模型：一套框架控制7种机械臂(基于PaliGemma和流匹配的3B模型)-CSDN博客](https://blog.csdn.net/v_JULY_v/article/details/143472442)
- [π系列知乎解读](https://zhuanlan.zhihu.com/p/1899001822892524151)

## 数据集 #dataset

- [Open X-Embodiment dataset (OEX 数据集)](<https://robotics-transformer-x.github.io/>
- [Open X-Embodiment（OXE）dataset](Open%20X-Embodiment（OXE）dataset.md)

---

# VLN

VLN 任务（是任务而不是模型，因为通常包含很多模型的协同）将视觉信息和语言指令作为输入，输出包括导航动作和目标识别。

个人感觉 VLN 要比后文提到的 VLA 更简单一点，任务也更固定和明确。但是简单不代表好做，难点在于大模型和小模型的协同（这就导致 VLN 任务像一个工程化的任务）。就目前的方法论而言，零样本、零训练的模型在近几年出现得比较多，思想基本是 LLM 和视觉模型割裂开进行协作。我觉得创新的角度也比较多。

硬件要求：需要一个能跑、头上摄像头能转的小机器人。GPU 算力要求取决于方法，如果方法要训练 LLM 或者 VLM 那就很吃算力，如果方法是零样本的、只需要部署 LLM 模型，那算力要求就很小。比如 UniGoal 只需要两个 3090 就能运行。

## Paper List

- [Vision-and-Language Navigation Today and Tomorrow: A Survey in the Era of Foundation Models](https://zhuanlan.zhihu.com/p/28599085823)
- [【机器人】具身导航 VLN 最新论文汇总 | Vision-and-Language Navigation-CSDN博客](https://blog.csdn.net/qq_41204464/article/details/148337859)
- [CVPR2025 | UniGoal：通用零样本目标导航，Navigate to Any Goal!](https://zhuanlan.zhihu.com/p/30973430092) 这个有点强，因为给 llm 的是**纯文本描述**，所以不用预训练。
- [WMNav：融合VLM和世界模型的室内目标导航](https://zhuanlan.zhihu.com/p/1892681939544171017)
- [NeurIPS-2024 | 具备人类感知能力的具身导航智能体！HA-VLN：通过人类动态交互连接仿真与现实世界](https://zhuanlan.zhihu.com/p/19150161385)

---

# Real-to-Sim, Sim-to-Real, Real-to-Sim-to-Real

这个很有意思，我感觉属于传统机器人控制的方向，具身智能综述里关于这方面的内容比较少。但是我看最近的 paper 也一直在接受，而且还不少。这些方面和强化学习的结合比较多。

Real-to-Sim 主要是三维重建，Sim-to-Real 主要是使得在仿真环境中训练的机器人，能在现实中运行起来。这一块儿理论方法很多，数学推导也很多。

Rea-to-Sim-to-Real 的任务比较杂，落脚点（模型输出）是机器人的动作，让机器人完成姿态控制和导航等任务，比如让人形机器人/四足狗爬楼梯等等。出发点（或者说模型的输入）就很多样，比如用视频训练机器人。

硬件：人形机器人、机器狗等，根据不同的任务而定。GPU 算力需求也是强化学习的需求，根据任务有大有小。

## Paper List

- [VR-Robo: A Real-to-Sim-to-Real Framework for Visual Robot Navigation and Locomotion](https://vr-robo.github.io/)
- [VideoMimic](https://www.videomimic.net/)