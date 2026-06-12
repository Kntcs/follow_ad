## 7. [2501.15830] SpatialVLA: Exploring Spatial Representations for Visual-Language-Action Model

### 1. Motivation（研究动机）

**问题背景**：
当前的 Vision-Language-Action (VLA) 模型在构建通用机器人策略方面展现了巨大潜力，但这些模型主要局限于 2D 观察输入，缺乏对 3D 物理世界的精确感知和理解。现有 VLA 模型如 RT-2、OpenVLA 等主要通过微调预训练的 Vision-Language Models (VLMs) 实现，但它们在跨机器人体现 (cross-embodiment) 的控制中面临两个根本性挑战：首先，不同机器人的观察空间无法在 3D 空间中对齐，因为相机传感器的安装位置和参数各不相同（如手腕相机 vs 第三人称相机）；其次，由于自由度、运动控制器、工作空间配置和任务复杂度的差异，不同机器人具有不同的动作运动特征，导致学习通用空间动作表示极其困难。

**为什么重要**：
人类在操作物体时能够本能地构建丰富的结构化空间心智表征，轻松地在规范、直观、甚至个性化的工作空间中对齐物体进行操作。对于通用机器人策略而言，缺乏这种 3D 空间智能严重限制了模型在需要精确空间理解的任务上的表现，尤其是在涉及复杂空间布局变化、未见对象和新机器人环境的场景中。这直接影响了 VLA 模型从预训练到下游任务迁移的泛化能力和适应效率。

**现有方法的不足**：
尽管一些工作（如 Octo、HPT、RDT）尝试在异构机器人数据集上进行预训练以支持跨体现控制，但它们在 3D 空间理解能力的提升上明显滞后。3D-LLM、LLaVA-3D、LEO 等方法虽然将 3D 特征引入 VLMs，但主要关注 3D 场景理解和预测，忽略了机器人动作空间中的 3D 空间特性。现有方法的核心 gap 在于：(1) 缺乏机器人无关 (robot-agnostic) 的 3D 观察对齐机制；(2) 缺乏统一的空间动作表示来捕捉跨机器人的运动模式；(3) 预训练模型难以高效适配到新机器人设置。

### 2. Contribution（核心贡献）

本文的主要贡献包括：

1. **提出 SpatialVLA 架构**：首个系统性探索 VLA 模型空间表示的通用机器人策略，通过 Ego3D Position Encoding 和 Adaptive Action Grids 将 3D 空间感知注入观察和动作表示，实现了机器人无关的空间对齐。

2. **Ego3D Position Encoding 设计**：基于自中心相机坐标系的 3D 位置编码，将深度信息与 2D 语义特征融合，无需特定的机器人-相机标定，具有跨体现的普适性。该方法使用 ZoeDepth 估计深度图并反投影到自中心 3D 坐标系，通过 MLP 将 3D 位置编码与 SigLIP 视觉特征相加。

3. **Adaptive Action Grids 机制**：创新性地提出自适应空间动作网格，通过对整个数据集的动作分布进行高斯拟合，将连续的 7D 动作（平移、旋转、夹爪）离散化为自适应的 3D 空间网格。关键创新在于：(a) 基于概率密度函数的等概率网格分割，使模型聚焦于高概率的精细动作空间；(b) 每个动作仅需 3 个 token（相比 RT-2/OpenVLA 的 7 个），推理速度提升至 20Hz；(c) 预训练后的空间网格可通过重新离散化高效迁移到新机器人设置（Spatial Embedding Adaption）。

4. **全面的实验验证**：在 1.1M 真实机器人演示数据上预训练，在 24 个真实机器人任务和 3 个仿真环境中进行评估。SimplerEnv 上达到 71.9% Visual Matching（超越 RT-2-X 的 60.7%）和 68.8% Variant Aggregation；LIBERO 上平均成功率 78.1%（最高）；真实 WidowX 机器人零样本评估平均成功率最高；在需要精确空间理解的任务上显著优于所有基线方法。

### 3. Method（技术方法）

**3.1 整体框架**

SpatialVLA 基于 PaliGemma2 视觉语言模型构建，输入为图像观察 $o_t = \{I_1^t, ..., I_n^t\}$ 和自然语言任务指令 $L$，输出为动作序列 $A_t = [a_t, a_{t+1}, ..., a_{t+H-1}]$。模型通过自回归方式预测空间动作 token，然后解码为连续动作信号用于机器人控制。训练目标为交叉熵损失：$\mathcal{L}(\theta) = \mathbb{E}_{p(A_t|o_t)} \mathcal{L}(a_t, \tilde{a}_t)$。

**3.2 核心技术**

**(1) Ego3D Position Encoding（自中心 3D 位置编码）**

- **作用**：将 3D 空间上下文与 2D 语义特征融合，构建自中心 3D 空间表示，无需机器人-相机外参标定
- **设计**：
  1. 使用 ZoeDepth 估计深度图 $D$
  2. 通过反投影 $\pi^{-1}$ 和相机内参将像素 3D 位置 $p = \{x, y, z\}$ 映射到自中心 3D 坐标系
  3. SigLIP 视觉编码器提取 2D 语义特征 $X \in \mathbb{R}^{d \times h \times w}$
  4. 计算对应的 3D 位置 $P \in \mathbb{R}^{3 \times h \times w}$
  5. 通过正弦函数 $\gamma(\cdot)$ 和可学习 MLP 编码为 3D 位置嵌入：$P' = \text{MLP}(\gamma(P))$
  6. 最终的自中心 3D 空间表示：$O_{3d} = X + P'$
- **为什么这样设计**：自中心坐标系消除了对特定机器人配置的依赖，使得同一套编码方案可应用于不同的相机安装位置和机器人体现。ZoeDepth 虽然引入额外计算（8.6% 参数，0.06s/动作），但提供比传感器深度更平滑的输入，且能捕捉相对空间布局（精确尺度不必要）。

**(2) Adaptive Action Grids（自适应动作网格）**

- **作用**：将异构机器人的连续动作空间统一为离散的空间网格 token，实现跨机器人的动作对齐和高效的动作生成
- **设计**：
  1. **动作分解**：7D 动作分为三部分：$a = \{a_{trans}, a_{rot}, a_{grip}\}$
     - 平移：$a_{trans} = \{x, y, z\}$ 转换为极坐标 $(\phi, \theta, r)$（方向 + 距离）
     - 旋转：$a_{rot} = \{roll, pitch, yaw\}$
     - 夹爪：$a_{grip} = \{grip\}$（2 个离散 token：开/关）
  2. **高斯分布拟合**：对整个数据集的每个动作变量归一化到 $[-1, 1]$，拟合高斯分布 $\mathcal{N}(\mu_a, \Sigma_a)$
  3. **等概率网格分割**：基于概率密度函数将连续动作分割为 $M$ 个区间 $G_{i=1,..,M}$，每个区间概率为 $1/M$：
     $$a_2, ..., a_M = \arg\min_{a_2,...,a_M} \left| \int_{a_i}^{a_{i+1}} f(x)dx - 1/M \right|, i=1,...,M$$
     其中 $f(x)$ 为高斯概率密度函数
  4. **网格配置**：方向 $(\phi, \theta)$ 使用更多网格（16×32）捕捉精细运动方向，距离 $r$ 使用较少网格（8）。最终：
     - 平移空间：$M_{trans} = M_\phi \cdot M_\theta \cdot M_r$ 个 3D 网格
     - 旋转空间：$M_{rot} = M_{roll} \cdot M_{pitch} \cdot M_{yaw}$ 个 3D 网格
     - 总 token 数：$V = M_{trans} + M_{rot} + 2 = 8194$
  5. **token 嵌入**：定义可学习的空间动作 token 嵌入：$E_a = \{E_{trans}, E_{rot}, E_{grip}\}$
- **为什么这样设计**：(a) 基于概率密度的自适应分割使网格集中在高概率动作区域，相比均匀分割（U8196）在一半分辨率下即可获得更好性能；(b) 极坐标分解解耦了运动方向和距离，使模型能更好地泛化到不同幅度的运动；(c) 3 token 表示（相比 7 token）大幅提升推理速度（20Hz vs OpenVLA 的 5.2Hz）；(d) 学习到的空间 token 嵌入捕获了通用的机器人动作知识。

**(3) Spatial Embedding Adaption（空间嵌入适配）**

- **作用**：在后训练阶段快速适配预训练模型到新机器人设置
- **设计**：
  1. 在新数据集上重新拟合高斯分布 $\mathcal{N}(\mu_{new}, \Sigma_{new})$
  2. 创建新的自适应动作网格 $G_{new}$
  3. 使用三线性插值从预训练网格初始化新 token 嵌入：
     $$e_i^{a_{new}} = \sum_{j=1}^{K} w_j e_j^a$$
     其中 $w_j$ 是基于质心距离的归一化权重
  4. 微调新 token 嵌入和模型参数
- **为什么这样设计**：新动作 tokenizer 通过插值继承了预训练的空间动作知识，避免从随机初始化开始。实验表明在小规模数据集（LIBERO）上带来 +4.6% 到 +5.4% 的性能提升。

**3.3 算法流程**

训练阶段：
1. 输入 RGB 图像分别送入 SigLIP（提取语义特征）和 ZoeDepth（估计深度）
2. 反投影深度到自中心 3D 坐标系，与视觉特征融合得到 $O_{3d}$
3. 连续动作通过查询 Adaptive Action Grids 编码为 3 个空间 token
4. PaliGemma2 backbone 自回归预测 token，使用交叉熵损失优化

推理阶段：
1. 同样构建 $O_{3d}$ 表示
2. 自回归生成 3 个动作 token（平移、旋转、夹爪各 1 个）
3. 通过网格解码为连续动作：找到 token 对应的网格质心，反归一化为原始动作空间
4. 执行动作，预测下一个 chunk（$T=4$ 步）

**3.4 与现有方法的区别**

| 维度 | RT-2/OpenVLA | Octo/HPT | SpatialVLA (本文) |
|------|--------------|----------|-------------------|
| 观察表示 | 2D 视觉特征 | 2D 视觉特征 | 自中心 3D 空间表示（Ego3D PE） |
| 动作表示 | 均匀离散化（256 bins × 7 维） | 连续动作 | 自适应空间网格（3D 结构化） |
| Token 数/动作 | 7 tokens | N/A | 3 tokens |
| 跨体现对齐 | 隐式（通过数据） | 模块化 stem | 显式空间对齐（网格 + 自中心坐标） |
| 后训练适配 | 全参数/LoRA 微调 | 全参数/LoRA 微调 | Spatial Embedding Adaption（网格重离散化） |
| 推理速度 | 5-7Hz | 3-5Hz | 20Hz |

核心区别：
1. **空间对齐**：现有方法依赖大规模数据隐式学习跨体现对齐，SpatialVLA 通过自中心 3D 表示和自适应网格显式对齐观察和动作空间
2. **动作效率**：Adaptive Action Grids 利用动作分布先验，用更少 token 表示动作（3 vs 7），推理速度提升 2-4 倍
3. **迁移机制**：Spatial Embedding Adaption 提供了新的后训练范式，通过网格重离散化而非仅靠微调，在小数据场景下显著改进（+4-5%）
4. **3D 感知**：与 LEO/3D-VLA 关注 3D 场景理解不同，SpatialVLA 将 3D 意识同时注入观察和动作，端到端优化机器人控制

### 4. Experiment（实验验证）

**4.1 实验设置**

- **数据集**：
  - 预训练：1.1M 真实机器人演示，包含 OXE 子集（27 个数据集）+ RH20T，覆盖多种机器人体现、场景和任务
  - 主要数据集权重：Bridge (15.34%)、Fractal (14.71%)、DROID (11.66%)、BC-Z (8.64%)、Kuka (7.06%)、RH20T (5.67%)
  - 训练策略：前 160k 步在完整数据集上训练，后 40k 步移除 DROID（提升质量）
- **基线方法**：
  - 零样本：RT-1-X、RT-2-X、Octo-Base、OpenVLA、HPT、TraceVLA、RoboVLM、π₀
  - 微调：Diffusion Policy（从头训练）、Octo、OpenVLA、TraceVLA
- **评估指标**：
  - SimplerEnv：Visual Matching（视觉匹配成功率）、Variant Aggregation（变体聚合成功率）
  - LIBERO：Success Rate（成功率）、Rank（排名）
  - 真实机器人：Task Success Rate、Grasp Success Rate、Partial Success Rate
- **环境**：
  - 仿真：SimplerEnv（Google Robot + WidowX）、LIBERO（4 个任务套件）
  - 真实机器人：BridgeV2 WidowX（7 个零样本任务）、Franka Emika Panda（13 个任务）
- **训练配置**：
  - 64 × A100 GPU，10 天
  - Batch size 2048，AdamW 优化器，学习率 2e-5
  - 基于 HuggingFace Transformers + DeepSpeed（ZeRO Stage 1）

**4.2 主要结果**

**SimplerEnv Benchmark（仿真零样本）**

| 模型 | Visual Matching | Variant Aggregation | 参数量 |
|------|-----------------|---------------------|--------|
| RT-2-X | 60.7% | 64.3% | 55B |
| RoboVLM | 56.3% | 46.3% | - |
| OpenVLA | 27.7% | 39.8% | 7B |
| π₀ | 70.1% | - | - |
| **SpatialVLA** | **71.9%** | **68.8%** | 3.5B |

Google Robot 任务细分：
- Pick Coke Can：81.0% (VM) / 89.5% (VA)
- Move Near：69.6% (VM) / 71.7% (VA)
- Open/Close Drawer：59.3% (VM) / 36.2% (VA)

WidowX 任务：
- Put Eggplant in Basket：**70.8%**（零样本）/ **100%**（微调）
- Stack Green Block：25.0%（零样本）/ 29.2%（微调）

**关键发现**：
- SpatialVLA 在使用 **16 倍少的参数**（3.5B vs 55B）情况下超越 RT-2-X（+11.2% VM，+4.5% VA）
- Visual Matching 和 Variant Aggregation 同时达到最高，表明对视觉外观变化和场景变化的双重鲁棒性
- 在 Open/Close Drawer（需要精确空间理解的铰接物体操作）上比 RoboVLM 高 +32.5%（VM）

**真实机器人零样本评估（WidowX）**

7 个任务平均成功率对比：

| 模型 | 平均成功率 | 最高单任务 |
|------|-----------|-----------|
| RT-1-X | 1.1% | 4.2% |
| Octo-Base | 16.0% | 43.1% |
| OpenVLA | 1.0% | 4.1% |
| RoboVLM | 13.5% | 25.0% |
| **SpatialVLA** | **34.4%** | **70.8%** |

典型任务表现：
- Put Eggplant in Basket（多物体场景）：**70.8%** vs OpenVLA 4.1%
- Put Carrot on Plate（运动干扰）：**20.8%** vs OpenVLA 0%
- Instruction Following（颜色描述）：SpatialVLA 能准确区分 "green cup on pink cloth" vs "purple cup on white plate"，OpenVLA 失败

**LIBERO 仿真适配（微调）**

| 模型 | LIBERO-Spatial | LIBERO-Object | LIBERO-Goal | LIBERO-Long | 平均 | 排名 |
|------|----------------|---------------|-------------|-------------|------|------|
| Diffusion Policy | 78.3% | 92.5% | 68.3% | 50.5% | 72.4% | 5 |
| Octo | 78.9% | 85.7% | 84.6% | 51.1% | 75.1% | 3 |
| OpenVLA | 84.7% | 88.4% | 79.2% | 53.7% | 76.5% | 2 |
| TraceVLA | 84.6% | 85.2% | 75.1% | 54.1% | 74.8% | 4 |
| **SpatialVLA** | **88.2%** | **89.9%** | **78.6%** | **55.5%** | **78.1%** | **1** |

- 在所有 4 个任务套件中排名第一
- **LIBERO-Spatial**（不同物体布局）：88.2%，比 OpenVLA 高 +3.5%，直接验证空间理解优势
- LIBERO-Object（物体类型泛化）：89.9%，最高
- 训练设置：LoRA (r=32, α=32) + Spatial Embedding Adaption，200 epochs

**Franka 真实机器人适配**

| 场景 | SpatialVLA | OpenVLA | Octo | Diffusion Policy |
|------|-----------|---------|------|------------------|
| Single Task | 82% | 77% | 77% | 81% |
| Instruction Following | **80%** | 68% | 59% | 26% |
| Multi-Task | **57%** | 41% | 37% | 23% |

- Instruction Following：比 OpenVLA 高 +12%，比 Diffusion Policy 高 +54%
- Multi-Task：比 OpenVLA 高 +16%，展现强大的多任务泛化能力
- 细粒度操作任务（超越 pick-and-place）：72.7% vs OpenVLA 54.5%

**空间理解能力专项评估**

| 任务 | SpatialVLA | OpenVLA | RoboVLM | Octo |
|------|-----------|---------|---------|------|
| Place Toy Closest to Robot | **100%** | 72.7% | - | - |
| Cup Height Change (Stove) | **100%** | 36.4% | 54.5% | 45.5% |
| Carrot Plate Height Change | **81.8%** | 9.1% | 18.2% | 18.2% |

- 在所有需要精确空间推理的任务上显著领先
- "Closest to Robot"（距离理解）：100% vs OpenVLA 72.7%
- Height Change（垂直空间理解）：平均提升 +60% 以上

**推理速度**

| 模型 | 推理速度 (Hz) | Token/动作 | GPU 内存 |
|------|--------------|-----------|----------|
| RT-2-X | 6.5 | 7 | - |
| OpenVLA | 5.2 | 7 | 13GB |
| TraceVLA | 5.0 | 7 | - |
| **SpatialVLA** | **20.1** | **3** | **8.5GB** |

- 相比 OpenVLA 快 **3.9 倍**
- 内存占用减少 35%
- 关键因素：3 token/动作 vs 7 token/动作

**4.3 消融实验**

**实验 A - Ego3D Position Encoding 的有效性**

在 SimplerEnv 和 Franka 上测试不同深度输入：

| 配置 | SimplerEnv Pick Coke | Franka Fine-Tuning Avg |
|------|---------------------|------------------------|
| 无深度 (w/o D) | 67.3% | 45.4% |
| 传感器深度 (sensor D) | 68.0% | 70.5% |
| **ZoeDepth (Zoe D)** | **70.7%** | **72.7%** |

- 相比无深度：+3.4%（仿真）、+27.3%（真实）
- ZoeDepth 优于传感器深度：提供更平滑、噪声更少的输入
- 深度 L1 误差平均 ≤0.2（ZoeDepth vs 传感器）
- 计算开销可接受：8.6% 参数，0.06s/动作

**实验 B - Adaptive Action Grids 的有效性**

SimplerEnv 上测试不同网格分辨率：

| 配置 | 分辨率 | Pick Coke (VM) | Move Near (VM) | Put Carrot (PA) | Put Eggplant (PA) |
|------|--------|----------------|----------------|-----------------|-------------------|
| U₈₁₉₆（均匀） | 8196 | 77.9% | 64.2% | 45.8% | 79.2% |
| reso₁₀₂₆ | 1026 | 67.3% | 59.1% | 45.8% | 66.7% |
| reso₄₆₁₀ | 4610 | 68.0% | 69.8% | 41.7% | 83.3% |
| reso₆₁₆₆ | 6166 | 74.0% | 74.0% | 41.7% | 95.8% |
| **reso₈₁₉₄** | **8194** | **70.7%** | **79.2%** | **41.7%** | **91.7%** |

- **reso₄₆₁₀**（4610 token）优于 **U₈₁₉₆**（8196 token 均匀分割），验证自适应分割的优越性
- 分辨率从 1026 增加到 8194，性能持续提升（+3.4% 到 +25%）
- 8194 后性能趋于饱和，表明该分辨率已足够

**实验 C - Spatial Embedding Adaption 的有效性**

| 数据集类型 | 任务 | w/o Adaption | w/ Adaption | 提升 |
|-----------|------|-------------|-------------|------|
| 大规模 | Fractal Move Near | 76.9% | 79.8% | +2.9% |
| 小规模 | LIBERO-Spatial | 83.6% | 88.2% | +4.6% |
| 小规模 | LIBERO-Object | 84.8% | 89.9% | +5.1% |
| 小规模 | LIBERO-Goal | 76.4% | 78.6% | +2.2% |
| 小规模 | LIBERO-Long | 50.1% | 55.5% | +5.4% |

- 在小规模数据集上效果显著（+2.2% 到 +5.4%）
- 大规模数据集提升较小（+2.9%），因为分布接近预训练
- 机制：从新分布初始化空间网格，对齐预训练特征与目标任务

**实验 D - LoRA vs 全参数微调**

在 LIBERO 小数据集任务上：
- **LoRA 微调（#4）** 优于 **全参数微调（#3）**
- 原因：小数据集下，LoRA 避免过拟合，同时保留预训练知识
- 推荐策略：小数据集用 LoRA，大数据集用全参数

**4.4 分析与讨论**

**核心发现**：

1. **空间表示的关键作用**：Ego3D PE 和 Adaptive Action Grids 的结合使 SpatialVLA 在需要精确空间理解的任务上大幅领先（如 carrot height change +72.7%）。这验证了将 3D 空间感知显式注入 VLA 模型的有效性。

2. **泛化能力的飞跃**：SimplerEnv Visual Matching（71.9%）和真实机器人零样本（34.4%）的优异表现表明，基于空间对齐的预训练比仅靠大规模数据的隐式学习更高效。模型能够：
   - 处理视觉外观变化（光照、纹理、背景）
   - 适应空间布局变化（物体位置、高度、距离）
   - 理解语言指令中的空间关系（颜色、相对位置）

3. **高效性的三重优势**：
   - **推理速度**：20Hz vs 5Hz（4× 提升）
   - **内存占用**：8.5GB vs 13GB（35% 减少）
   - **数据效率**：小数据集微调（+4-5% 提升）

4. **Surprising 发现**：
   - ZoeDepth 估计的深度虽不精确但优于传感器深度，因为它提供了平滑的相对空间布局，这对操作任务而言比绝对尺度更重要
   - 自适应网格分割在一半分辨率下即可超越均匀分割，说明动作分布先验的重要性被严重低估
   - Spatial Embedding Adaption 在小数据集上的巨大增益（+5.4%）表明，预训练空间 token 嵌入捕获了可迁移的结构化动作知识

5. **局限性**：
   - **长时序任务**：LIBERO-Long（55.5%）相对较低，因为模型仅依赖当前帧和历史 token，缺乏显式的长序列建模
   - **动作分布假设**：高斯拟合在极端情况（如单轴运动）下可能导致网格在特定坐标轴聚集，丢失其他轴的运动能力
   - **高自由度扩展**：8194 token 词汇表对人形机器人（更高 DoF）可能引入参数开销，需要跨体现的网格共享策略
   - **推理速度 vs 精度权衡**：虽然快，但仍慢于扩散解码方法（如 π₀）；未来需探索动态 token 数的动作映射

**与假设的对应**：
- **假设 1**（空间对齐的必要性）：SimplerEnv +11.2% 和 LIBERO-Spatial +3.5% 强烈支持
- **假设 2**（自适应网格的优越性）：reso₄₆₁₀ > U₈₁₉₆ 和 20Hz 推理速度验证
- **假设 3**（迁移效率）：Spatial Embedding Adaption 在小数据集上的 +5% 增益证实

**未解问题**：
- 为什么 Open/Close Drawer 的 Variant Aggregation（36.2%）相对 Visual Matching（59.3%）下降明显？可能是铰接物体的动力学在变体间差异较大，需要更强的物理理解。
- Instruction Following 在 Franka 上的成功（80%）是否依赖于预训练的语言对齐？冻结文本 token 嵌入的设计是关键因素。

