## 3. [2501.09747] Fast: Efficient action tokenization for vision-language-action models

**一句话总结**: 用频域压缩解决VLA高频动作预测难题，训练速度提升5倍

**背景与动机**:
当前VLA (Vision-Language-Action，视觉-语言-动作模型) 普遍使用简单的"分桶"方法将连续动作离散化（每个时间步、每个维度独立分成256个桶）。这种方法在高频机器人控制中表现糟糕：相邻动作之间高度相关，导致"下一个token预测"的学习信号极弱——模型可以简单复制上一个token就能获得低loss，陷入局部最优。OpenVLA在低频BridgeV2数据集上表现良好，但在高频DROID数据集上完全失败。

**核心创新**:

1. **用DCT (Discrete Cosine Transform，离散余弦变换) 压缩动作序列**
   - 核心思想：高频机器人数据相邻时间步高度冗余，需要先压缩再tokenize，降低token间相关性
   - 具体做法：把时域的动作序列转到频域，低频分量捕捉整体轨迹形状，高频分量捕捉细节跳变。大部分信息集中在少数低频系数上，可以通过缩放+取整丢弃不重要的高频成分

2. **用BPE (Byte Pair Encoding，字节对编码) 进一步压缩稀疏矩阵**
   - 做了什么：DCT后的系数矩阵很稀疏（大部分为0），flatten成1维向量后用BPE无损压缩
   - 为什么这样设计：BPE能"压缩"连续的零值token，并合并频繁出现的系数组合，将稀疏表示转为密集token序列

3. **低频优先的flatten顺序**
   - 做了什么：flatten DCT矩阵时，先concatenate所有维度的最低频分量，再连接次低频，以此类推
   - 为什么：让模型先预测整体轨迹形状（低频），再预测细节（高频），rollout更稳定

4. **训练通用tokenizer FAST+**
   - 做了什么：在100万条真实机器人轨迹上训练BPE词典，覆盖单臂/双臂/移动机器人、关节/末端执行器控制、不同频率
   - 为什么：BPE是唯一需要训练的组件（DCT是解析方法），训练通用tokenizer后可直接应用到任意新机器人，无需重新训练

5. **与现有VLA架构无缝集成**
   - 做了什么：直接替换π0和OpenVLA中的action tokenizer，不修改Transformer backbone
   - 为什么：避免重新训练大模型，可复用现有预训练权重

**技术方案**:

**整体架构**
- Pipeline: 原始动作chunk → 归一化 → DCT → 量化 → Flatten → BPE → 离散tokens
- 可逆性：所有操作都可逆，推理时快速解码（inverse BPE → reshape → inverse DCT → 反归一化）
- 超参数极少：仅2个（DCT缩放系数γ=10，BPE词汇量=1024），在所有实验中固定

**关键技术点**

1. **归一化 (Normalization)**
   - 用分位数归一化：将训练集每个动作维度的1st和99th分位数映射到[-1, 1]
   - 作用：统一数据范围，抵抗离群值，让cross-embodied训练更容易

2. **DCT压缩 (Discrete Cosine Transform)**
   - 对每个动作维度独立应用DCT，得到|A|×H的频域系数矩阵（A是动作维度，H是chunk长度）
   - 量化：Ĉ_ij = round(γ · C_ij)，γ控制压缩率vs重建精度tradeoff
   - 为什么用DCT而不是VQ-VAE：DCT是解析方法，无需训练，参数少，在高频精细控制上优于学习型压缩

3. **BPE压缩 (Byte Pair Encoding)**
   - Flatten顺序：[Ĉ₁₁, Ĉ₂₁, ..., Ĉ₁₂, ..., Ĉₙₕ]（列优先，低频分量先）
   - 训练BPE词典Φ：在flatten后的整数序列上训练，学习高频系数组合和零值压缩模式
   - 输出：密集token序列，长度可变（取决于信号复杂度）

4. **训练方式**
   - 与标准VLA训练完全相同：fine-tune预训练vision-language model，覆盖词汇表中最不常用的tokens
   - 损失函数：标准的next-token prediction cross-entropy
   - 模型架构：测试了π0 (PaliGemma-3B) 和 OpenVLA (Prismatic 7B)

**与现有方法的区别**

| 维度 | Naive Tokenization | FSQ (学习型压缩) | FAST |
|------|-------------------|-----------------|------|
| **压缩率** | 1× (基准) | ~2-3× | 5-13× (高频场景) |
| **需要训练** | 否 | 是（VQ网络） | 仅BPE (分钟级) |
| **超参数敏感度** | 低 | 高（重建质量敏感） | 极低（2个参数） |
| **高频性能** | 失败（复制第一个动作） | 中等 | 优秀 |
| **可解释性** | 高 | 低（黑盒神经网络） | 高（频域分解） |

**为什么FAST更好**：
- **信息论角度**：压缩后每个token的边际信息量更高（given前面所有token的条件下），学习信号强
- **频域特性**：机器人轨迹平滑，信息集中在低频，DCT天然适配（JPEG压缩同理）
- **工程友好**：无需调参，训练快，通用性强

**实验效果**:

**主要结果**：

1. **Token压缩率对比** (表I)
   - BridgeV2 (7维, 5Hz): 35 → 20 tokens (1.75×)
   - DROID (7维, 15Hz): 105 → 29 tokens (3.6×)
   - Table Bussing (7维, 20Hz): 140 → 28 tokens (5.0×)
   - T-Shirt Folding (14维, 50Hz): 700 → 53 tokens (13.2×)
   - **规律**：FAST在所有场景生成~30 tokens/arm/chunk，与控制频率无关

2. **单任务训练性能** (图6)
   - **Libero仿真** (低频): Naive 85% → FAST 100%
   - **Table Bussing** (20Hz): Naive 0% → FAST 80% task progress
   - **T-Shirt Folding** (50Hz): Naive 0% → FAST 60% success
   - **DROID zero-shot** (15Hz): Naive失败 → FAST 40%成功（首个在unseen环境的DROID策略）

3. **FAST vs FSQ** (图6)
   - 低频任务：FAST ≈ FSQ
   - 高频灵巧任务：FAST显著优于FSQ（T-Shirt: 60% vs 40%）
   - 训练复杂度：FAST无需训练VQ网络

4. **通用tokenizer FAST+泛化性** (图8)
   - 在13个unseen机器人数据集测试（单臂/双臂/移动/人形/灵巧手）
   - 压缩率：2-15×，中位数5×
   - 策略性能：FAST+ ≈ FAST（数据集特定tokenizer）

5. **FAST vs Diffusion π0** (图9, 11)
   - **小数据集**（<50h）：FAST ≈ Diffusion π0
   - **大数据集**（Table Bussing）：FAST收敛速度3×更快
   - **Generalist策略**（903M timesteps训练）：
     - 性能：FAST匹配Diffusion π0（包括最难的Laundry Folding任务）
     - 训练效率：5×更快（同等GPU时数下达到相同性能）
   - **语言理解**：FAST在DROID zero-shot上更好地遵循语言指令

6. **消融实验**
   - **去掉BPE**: 性能下降（T-Shirt: 60% → 45%），推理速度慢（需预测数百个0-token）
   - **在OpenVLA上测试**: OpenVLA原版在T-Shirt Folding完全失败 → +FAST后达到55%
   - **Flatten顺序**: 列优先（低频先）显著优于行优先

**定量对比基准**：
- π0-FAST vs π0-Diffusion (同模型backbone):
  - Grocery Bagging: 95% vs 92%
  - Toast out of Toaster: 88% vs 85%
  - Laundry Folding: 78% vs 80% (单个衣物)
- 推理速度：π0-Diffusion 100ms/chunk, π0-FAST 750ms/chunk (4090 GPU)

**个人点评**: 
这项工作用经典信号处理方法（DCT）解决了深度学习问题（VLA训练），设计简洁优雅且工程实用性强。核心洞察——"压缩即tokenization"——为处理连续信号提供了新范式。局限是推理速度慢7×（可用LLM加速技术优化如speculative decoding），未来可探索DCT与Diffusion的结合。FAST+的开源将加速社区在高频灵巧操作上的研究。
