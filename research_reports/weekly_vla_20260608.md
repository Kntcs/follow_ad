)

language_model = Pythia(
    model_size="1.4B",
    hidden_size=2048,
    num_layers=24
)

adapter = ProjectionMLP(
    input_dim=1024,
    output_dim=2048,
    hidden_dim=2048
)

# LoRA配置
lora_config = {
    'rank': 8,
    'alpha': 16,
    'target_modules': ['q_proj', 'k_proj', 'v_proj'],
    'trainable_ratio': 0.05
}

# Diffusion Policy Head
diffusion_head = DiffusionPolicy(
    action_dim=7,
    horizon=10,
    n_diffusion_steps=10,
    condition_dim=2048 + 7,
    hidden_dim=512,
    num_layers=3
)
```

**总参数量**: 1.3B（其中65M可训练）

#### 3. **训练配置**

**硬件需求**:
- GPU: 1× NVIDIA A6000 (48GB)
- 最低: 1× RTX 3090 (24GB) + gradient checkpointing
- CPU: 16核+
- 内存: 64GB+

**超参数**:
```python
# VLM预训练（可跳过）
vlm_training = {
    'batch_size': 128,
    'learning_rate': 1e-4,
    'optimizer': 'AdamW',
    'weight_decay': 0.01,
    'epochs': 3,
    'lr_schedule': 'cosine',
    'warmup_ratio': 0.03
}

# 机器人Fine-tune
robot_finetuning = {
    'batch_size': 64,
    'learning_rate': 1e-4,
    'diffusion_lr': 1e-3,
    'optimizer': 'AdamW',
    'weight_decay': 0.01,
    'epochs': 50,
    'gradient_clip': 1.0,
    'ema_decay': 0.999
}
```

**训练时间**: VLM预训练72h / Fine-tune 6h

#### 4. **复现难度**: ★★★☆☆ (3.5/5)

**挑战**: 真实机器人数据采集、VLM预训练成本
**缓解**: 使用开源VLM、仿真环境验证
**简化路径**: MetaWorld仿真 → MobileVLM backbone → 1周验证

#### 5. **开源资源**

- 官方: https://tiny-vla.github.io/
- 依赖: Diffusion Policy (GitHub), Pythia (HuggingFace)
- 预训练VLM: Pythia-1.4B, LLaVA-Phi

---

## 7. [2501.15830] SpatialVLA: Exploring spatial representations for visual-language-action model 🔥高引

### 核心内容

**一句话总结**: 通过Ego3D位置编码和自适应动作网格赋予VLA模型3D空间理解能力，在110万真实机器人样本上预训练，实现跨机器人零样本泛化。

**研究问题**: 现有VLA模型局限于2D观测，缺乏对3D物理世界的精确感知，难以跨不同机器人具身的空间对齐控制。

**主要贡献**:
- **Ego3D Position Encoding**: 将深度信息与2D语义特征融合，构建以相机为中心的3D坐标系，无需机器人-相机外参标定
- **Adaptive Action Grids**: 通过高斯分布拟合将连续7维动作离散化为自适应空间网格，学习可迁移的空间动作tokens
- 在PaliGemma2基础上用110万真实机器人样本预训练，实现零样本多任务泛化和高效新环境适配
- SimplerEnv、LIBERO、真实WidowX和Franka机器人上刷新SOTA性能
- 推理速度20Hz，相比OpenVLA仅需3个tokens表示单步动作（vs 7个），速度提升3倍

### 创新点

**核心创新**:

1. **Ego3D Position Encoding**: 
   - 使用ZoeDepth估计深度图，通过相机内参反投影获得像素3D位置
   - 用正弦位置编码+MLP将3D坐标编码为位置嵌入
   - 与SigLIP视觉特征相加: `O_3d = X + MLP(γ(P))`
   - 以自我中心坐标系构建，跨机器人通用，无需外参标定

2. **Adaptive Action Grids**:
   - 将7维动作分解为平移(ΔT)、旋转(ΔR)、抓取(G)
   - 平移空间转为极坐标(φ, θ, r)，分离方向和距离
   - 在全数据集上拟合高斯分布N(μ_a, Σ_a)，按等概率1/M划分网格
   - 学习空间动作token嵌入E_a = {E_trans, E_rot, E_grip}

3. **Spatial Embedding Adaption**:
   - 后训练时对新机器人重新拟合高斯分布N(μ_new, Σ_new)
   - 通过三线性插值初始化新动作token嵌入: `e_i^{a_new} = Σ w_j e_j^a`
   - 保留预训练空间知识的同时适配新机器人特性

**突破点**: 
- 将机器人动作空间的统计分布显式建模为可学习的空间tokens，首次实现动作空间的跨机器人对齐
- 自我中心3D表征消除了相机配置差异，为异构机器人提供统一观测空间

### 技术细节

**1. 问题形式化**

- **输入**: 图像观测o_t = {I_1^t, ..., I_n^t} + 语言指令L
- **输出**: 动作序列A_t = [a_t, ..., a_{t+H-1}], H=4
- **单步动作**: a = {x, y, z, roll, pitch, yaw, grip}

**2. 模型架构**

```
输入: 多视角图像(320×240×3) + 语言指令
VLM骨干: Qwen2-VL 2B
├─ 视觉编码器: 生成视觉token
├─ 语言编码器: 生成推理token + 动作token
└─ 投影模块: 2层Linear+LayerNorm

扩散专家(1B参数):
├─ DiT (32层, hidden=1280, heads=16)
├─ FiLM层: 推理token调制Attention和FFN
├─ 多头输出: 每个具身对应一个MLP头
└─ 输出: 去噪后的动作序列
```

**3. Ego3D编码实现**

```python
def ego3d_position_encoding(image, camera_K):
    # 深度估计
    depth = zoe_depth_model(image)  # [H, W]
    
    # 反投影到3D
    u, v = meshgrid(arange(w), arange(h))
    z = depth
    x = (u - camera_K[0,2]) * z / camera_K[0,0]
    y = (v - camera_K[1,2]) * z / camera_K[1,1]
    P = stack([x, y, z], axis=0)  # [3, H, W]
    
    # 正弦编码 + MLP
    P_freq = sinusoidal_encode(P, num_freqs=10)
    P_embed = mlp(P_freq)  # [d, H, W]
    
    # 融合视觉特征
    X = siglip_encoder(image)
    O_3d = X + interpolate(P_embed, size=X.shape)
    return O_3d
```

**4. 自适应网格划分**

```python
def fit_action_grids(actions, M_trans, M_rot):
    # 归一化 + 极坐标转换
    actions_norm = normalize(actions, [-1,1])
    x, y, z = actions_norm[:,:3].T
    r = sqrt(x**2 + y**2 + z**2)
    φ = arctan2(y, x)
    θ = arccos(z / (r + 1e-8))
    
    # 拟合高斯并等概率划分
    grids = {}
    for var, M in zip([φ,θ,r], [M_φ,M_θ,M_r]):
        μ, σ = fit_gaussian(var)
        pdf = norm(μ, σ)
        grids[var] = [pdf.ppf(i/M) for i in range(M+1)]
    
    # 构建3D网格索引
    trans_grids = create_3d_grid(grids[φ], grids[θ], grids[r])
    rot_grids = create_3d_grid(grids['roll'], grids['pitch'], grids['yaw'])
    
    return trans_grids, rot_grids
```

**5. 训练配置**

| 阶段 | 学习率 | Epoch | 数据 | GPU×天 |
|------|--------|-------|------|--------|
| 预训练 | 2e-5 | 5 | 110万样本/91任务 | 64×A100×10 |
| 后训练 | 2e-5 | 5 | 具身特定 | 未明确 |

### 复现指南

**数据集**: 110万样本(OXE子集+RH20T), 评估基准SimplerEnv/LIBERO/Bridge-V2/Franka

**难度**: ⭐⭐⭐⭐ (4/5星)
- 障碍: 预训练数据配置未公开、64×A100×10天计算成本、多个关键超参数缺失
- 简化: 单具身复现、缩小模型至410M、使用开源OXE子集

**开源资源**: 
- 项目页: https://spatialvla.github.io (承诺开源，暂未发布)
- ZoeDepth权重: https://github.com/isl-org/ZoeDepth

**关键实现**:
```python
# 最小验证实验
configs = [
    {"grid": "uniform", "bins": 256},
    {"grid": "gaussian", "bins": 256},
]
for config in configs:
    model = SpatialVLA(grid_config=config)
    success_rate = evaluate(model, widowx_tasks)
    print(f"{config['grid']}: {success_rate:.1%}")
# 预期: Adaptive比Uniform高5-10%
```

---

## 8. [2506.01844] Smolvla: A vision-language-action model for affordable and efficient robotics 🔥高引

### 核心内容

**一句话总结**: 450M参数模型，可单GPU训练、CPU部署，性能媲美10倍参数量大模型。

**研究问题**: 现有VLA模型巨大(数十亿参数)→训练成本高、部署困难、推理延迟高

**主要贡献**:
- **轻量架构**: 450M参数(action expert仅100M)，通过VLM层跳过、视觉token压缩、交替self/cross-attention实现高效
- **社区数据预训练**: 481个开源数据集(2.29万episodes、1060万frames，比现有方法少一个数量级)
- **异步推理栈**: 解耦观察处理、动作预测与执行，消除idle gap，支持远程GPU推理
- **开源完整方案**: 代码、模型权重、训练数据、训练recipe全部开源

**实验结果**:
- LIBERO: 平均成功率~80% (π0持平)
- 真实SO-100: Pick-Place 0.90 vs π0 0.85
- 真实SO-101: Pick-Lego 0.70 vs π0 0.55 (跨embodiment泛化)
- 推理吞吐: GPU ~10Hz, CPU ~3Hz

### 创新点

#### 1. **架构轻量化四大策略**

**层跳过**: 只使用VLM前N=L/2层特征
**视觉token压缩**: 去除image tiling，每帧仅64个token
**交替attention**: 奇数层Cross-Attention，偶数层Self-Attention
**小型VLM**: SmolVLM-2 (450M) 而非7B+模型

#### 2. **社区数据集挑战与解决**

**挑战**: 任务标注噪声、相机命名混乱、数据质量参差
**解决**:
- VLM自动标注: Qwen2.5-VL-3B生成规范任务描述
- 相机视角标准化: 手动映射到OBS_IMAGE_1/2/3
- 筛选机制: 按embodiment类型、episode数量、帧覆盖度过滤

**数据规模对比**:
| 模型 | Episodes | Frames |
|------|----------|--------|
| SmolVLA | 22.9K | 10.6M |
| RT-2-X | >100K | >100M |
| OpenVLA | >100K | >100M |

#### 3. **Flow Matching Action Expert**

**核心公式**:
```
L_τ(θ) = E[||v_θ(A^τ_t, o_t) - u(A^τ_t | A_t)||²]
其中: A^τ_t = τ·A_t + (1-τ)·ε, τ ~ Beta分布
```

**优势**: 连续动作、比diffusion快(10步 vs 50+步)、平滑action chunks

**架构**: Hidden size = 0.75×d_VLM，交替CA/SA layers，Chunk size n=50

#### 4. **异步推理栈**

**同步问题**:
```
执行50步 → [IDLE等待推理] → 执行下一个50步
```

**异步方案**:
```python
while True:
    a_t = PopFront(ActionQueue)
    Execute(a_t)
    
    if len(ActionQueue)/n < g:  # 队列阈值
        o_new = CaptureObservation()
        if NotSimilar(o_new, o_prev):
            AsyncInfer(o_new)  # 非阻塞推理
```

**关键参数g**:
- g=0: 完全同步，存在idle gap
- g=0.7: 最优平衡(推荐)
- g=1: 每步推理，计算开销大

### 技术细节

#### 模型架构

```python
class SmolVLA(nn.Module):
    def __init__(self):
        self.vlm = SmolVLM2.from_pretrained("SmolVLM2-450M")
        self.num_layers = len(self.vlm.layers) // 2  # 跳过后半层
        
        self.state_proj = nn.Linear(d_state, d_vlm)
        self.feat_proj = nn.Linear(d_vlm, d_expert)
        self.action_proj = nn.Linear(d_action, d_expert)
        
        self.expert = FlowMatchingTransformer(
            dim=int(0.75 * d_vlm),
            n_layers=12,
            interleaved_ca_sa=True
        )
    
    def forward(self, images, state, task, actions=None, tau=None):
        with torch.no_grad():
            feats = self.vlm.encode(images, state, task, layers=self.num_layers)
        
        feats = self.feat_proj(feats)
        if actions is not None:
            noisy_actions = tau * actions + (1-tau) * torch.randn_like(actions)
            pred_field = self.expert(noisy_actions, feats)
            loss = F.mse_loss(pred_field, torch.randn_like(actions) - actions)
            return loss
        else:
            return self.ode_sample(feats, steps=10)
```

#### 训练配置

**预训练**:
```bash
python train.py \
  --model smolvla \
  --datasets community_datasets/*.parquet \
  --batch-size 64 \
  --steps 200000 \
  --lr 1e-4 \
  --precision bf16 \
  --compile
```

**Fine-tuning**:
```bash
python train.py \
  --checkpoint pretrained/smolvla.pth \
  --dataset libero \
  --steps 100000 \
  --batch-size 64
```

**硬件需求**:
- 预训练: 4× GPU (A100/H100), 30K GPU hours
- Fine-tuning: 1× RTX 4090
- 推理: RTX 3060+ (GPU ~10Hz) 或 CPU (~3Hz)

### 复现指南

**难度**: ⭐⭐⭐☆☆ (3/5)

**障碍**: 社区数据集标准化需手工(相机映射)、30K GPU hours预训练成本

**预计时间**:
- 快速复现(用预训练权重): 1周
- 完整复现(含预训练): 4-6周

**复现建议**:
1. 优先: 使用官方预训练权重，仅复现fine-tuning
2. 降低难度: 仿真环境(LIBERO)比真实机器人易复现
3. 关键检查点: Table 2(LIBERO成功率≥85%)、Table 3(真实Pick-Place≥0.85)

**开源资源**:
- 代码: https://github.com/huggingface/lerobot (集成中)
- 预训练权重: HuggingFace Model Hub
- 数据集: lerobot/* (LIBERO/Meta-World/Real-world)

---

## 9. [2502.05855] Dexvla: Vision-language model with plug-in diffusion expert for general robot control 🔥高引

### 核心内容

**研究问题**: 现有VLA模型存在(1)数据稀缺性——需数千小时演示;(2)架构失衡——VLM 7B参数 vs 动作专家百万参数级，动作表征成瓶颈。

**解决方案**: DexVLA提出"插件式十亿参数扩散专家+具身课程学习":
- **十亿参数扩散专家**: 基于ScaleDP的Transformer扩散模型，参数从93M扩展至1B，多头架构支持跨具身学习
- **三阶段具身课程学习**:
  - Stage 1(跨具身预训练): 仅训练扩散专家，用ResNet-50+DistilBERT处理多具身数据，学习底层运动技能
  - Stage 2(具身对齐): 冻结VLM视觉编码器，联合训练VLM、投影层和扩散专家
  - Stage 3(任务适配): 引入子步推理进行后训练，模型自主分解长时程任务

**实验验证**:
- Stage 2后即可完成叠衣服(0.92分)、整理桌面(0.72分)
- 仅100个演示在新具身上学会灵巧技能(倒水0.85分、打包0.95分)
- 长时程任务(洗衣折叠2分钟+)直接提示下超越π0(0.4 vs 0.2)

**数据效率**: 仅用100小时演示数据(vs OpenVLA 4000h/π0 10000h)，单张A6000 GPU推理60Hz

### 创新点

1. **十亿参数扩散专家架构**
   - 规模突破: 将动作专家从93M扩展至1B参数
   - 多头跨具身设计: 每个头对应一个具身形态，支持91任务4种机器人统一预训练
   - 模块化解耦: 扩散专家可独立预训练，训练速度提升2.78倍

2. **具身课程学习范式**
   - 三阶段渐进式: 通用运动技能→适应身体特性→掌握复杂任务
   - Stage 1创新: 解耦VLM与扩散专家，用ResNet-50+DistilBERT预训练，避免冷启动失败
   - 消融验证: 无Stage 1训练导致完全失败(0分)

3. **隐式子步推理机制**
   - 端到端规划: 将高层规划能力内化到VLM，无需外部SayCan模块
   - 自适应状态分割: 每5秒标注子步推理，通过FiLM层注入策略指导
   - 解耦动作空间: 使参数空间分段，避免长时程任务参数冲突(无子步时0.92→0.07)

4. **零样本跨具身迁移**
   - 用夹爪训练的模型直接迁移到灵巧手，在30个未见物体上达60%成功率

### 技术细节

**模型架构**:
```
输入: 多视角图像(320×240×3) + 语言指令
VLM骨干: Qwen2-VL 2B
└─ 投影模块: 2层Linear+LayerNorm

扩散专家(1B参数):
├─ DiT (32层, hidden=1280, heads=16)
├─ FiLM层: 推理token调制Attention和FFN
├─ 多头输出: 每个具身对应一个MLP头
└─ 输出: 去噪后的动作序列

训练损失: L = L_diff + α·L_ntp (α=1)
```

**三阶段训练**:

| 阶段 | 学习率 | Epoch | 数据 | 关键操作 |
|------|--------|-------|------|----------|
| Stage 1 | 1e-4 | 5 | 跨具身100h/91任务 | 冻结VLM,训练扩散专家+ResNet-50+DistilBERT |
| Stage 2 | 2e-5 | 5 | 具身特定 | 冻结VLM视觉编码器,训练VLM文本+投影层+扩散专家 |
| Stage 3 | 2e-5 | 5 | 任务特定(子步标注) | 全模型微调,启用子步推理生成 |

**扩散专家核心设计**:
- 基础架构: ScaleDP, Transformer替代UNet
- 跨具身适配: 多头输出层，每个具身独立MLP头
- 去噪过程: ε_θ(a_t, t, c), c=[观测编码, VLM动作token, FiLM推理调制]

**子步推理数据标注**:
- 对象级任务: Grounding-Dino+DINOv2，IoU阈值判定抓取成功
- 长时程任务: 预定义子步库(每步≥5秒)，Google Gemini 2.0自动视频分割

### 复现指南

**数据集准备**:
- Stage 1跨具身: 100h, 91任务, 分布Agilex 42.7% + Franka 34.7% + UR5e 18.2%
- Stage 2具身特定: 从Stage 1筛选单一具身样本
- Stage 3任务特定: 带子步标注的长时程任务(如laundry folding 2分钟+/episode)

**环境配置**:
```bash
Python: 3.9+
PyTorch: 2.0+
pip install qwen-vl-utils diffusers einops timm transformers[sentencepiece]
```

**Stage 1实现**:
```python
class DiffusionExpert(nn.Module):
    def __init__(self, hidden_dim=1280, num_layers=32):
        super().__init__()
        self.blocks = nn.ModuleList([DiTBlock(hidden_dim, 16) for _ in range(num_layers)])
        self.embodiment_heads = nn.ModuleDict({
            'franka': nn.Linear(hidden_dim, 7),
            'agilex': nn.Linear(hidden_dim, 14),
            'ur5e': nn.Linear(hidden_dim, 14),
            'franka_hand': nn.Linear(hidden_dim, 12),
        })
    
    def forward(self, noisy_action, timestep, obs_embed, reasoning_embed, embodiment):
        t_emb = self.time_mlp(timestep)
        x = self.input_proj(noisy_action) + t_emb
        
        for block in self.blocks:
            x = block(x, obs_embed, reasoning_embed)  # FiLM调制
        
        eps_pred = self.embodiment_heads[embodiment](x)
        return eps_pred
```

**推理部署**:
```python
@torch.inference_mode()
def infer(images, instruction, embodiment='franka'):
    vl_outputs = qwen2vl(images, instruction)
    reasoning_tokens = vl_outputs.reasoning_tokens
    substeps = vl_outputs.generated_substeps
    
    # 扩散采样(50步DDPM)
    actions = torch.randn(1, T, action_dim)
    for t in reversed(range(50)):
        obs_embed = qwen2vl.vision_encoder(images)
        pred_noise = diffusion_expert(actions, t, obs_embed, reasoning_tokens, embodiment)
        actions = scheduler.step(pred_noise, t, actions).prev_sample
    
    return actions, substeps
```

**部署性能**: 推理60Hz, 延迟16.7ms, GPU内存28GB

**评估指标**:
- 叠衣服(3分制): 1分垂直对折 + 1分水平对折 + 1分推至空白区
- 洗衣折叠(4分制): 1分取出 + 1分抚平 + 1分折叠 + 1分堆放

**复现难度**: ⭐⭐⭐⭐ (4/5星)
- 障碍: 100h多具身数据采集、子步标注需Gemini 2.0、A6000级GPU、超参缺失
- 简化: 单具身复现(仅Franka)、缩小模型至410M、等待Open X-Embodiment子集

**开源资源**: 代码https://dex-vla.github.io/ (提交时未开源)，数据暂无公开

---

## 10. [2502.19417] Hi robot: Open-ended instruction following with hierarchical vision-language-action models 🔥高引

### 核心内容

**研究问题**: 现有VLA模型仅能执行简单原子指令("拿起杯子")，无法处理复杂、开放式自然语言交互("能给我做个素食三明治吗?我对泡菜过敏")和实时反馈("那不是垃圾")。

**核心方法**: **Hi Robot**(Hierarchical Interactive Robot)系统，采用双层VLM架构模拟Kahneman的System 1/System 2认知模型:
- **High-level VLM**(System 2): 解析复杂prompt和用户反馈，生成简单原子指令
- **Low-level VLA**(System 1): π0 VLA将原子指令转换为连续动作

**关键技术**:
1. **合成数据生成**: 用大型VLM反向生成训练数据——给定机器人观察和目标原子指令，生成可能导致该指令的用户prompt和交互
2. **情境化反馈**: High-level模型观察视觉+语言，可理解"那个不是垃圾"等指代性反馈
3. **双频推理**: Low-level高频输出动作(~10Hz)，High-level低频更新指令(每1秒或收到新反馈时)

**评估结果**: 在清理桌子、制作三明治、杂货购物三任务上，指令准确率比GPT-4o高40%+，比Flat VLA显著提升。

### 创新点

1. **首个双VLM分层架构**: 同时用VLM做高层推理和低层控制，通过语言接口连接两层

2. **反向合成数据生成范式**: 
   - 传统: 人类标注"prompt → 动作"
   - Hi Robot: VLM生成"观察+动作 → 合理的prompt"，利用VLM世界知识

3. **情境化实时交互**: 
   - GPT-4o等LLM系统失去物理基础(出现"拿起百慕大三角"等无意义指令)
   - Hi Robot通过视觉观察理解指代("那个"、"剩下的")

4. **消融实验验证**: 
   - 合成数据必不可少(无合成数据版本忽略约束)
   - 分层结构优于Flat策略

### 技术细节

#### 问题形式化

**Low-level VLA**: $p_{lo}(A_t | I^1_t, ..., I^n_t, \hat{\ell}_t, q_t)$
- 输入: 多相机图像、机器人状态$q_t$、原子指令$\hat{\ell}_t$
- 输出: 动作块$A_t = [a_t, ..., a_{t+H-1}]$

**High-level VLM**: $p_{hi}(\hat{\ell}_t | I^1_t, ..., I^n_t, \ell_t)$
- 输入: 图像、开放式prompt $\ell_t$
- 输出: 原子指令$\hat{\ell}_t$ + 可选语音回复$u_t$

#### 合成数据生成流程

```
1. 收集遥操作演示D_demo(粗粒度标注,如"做三明治")
2. 分割成短技能片段D_labeled(1-3秒,如"拿起生菜")
3. 用VLM p_gen反向生成:
   输入: 图像I_t + 技能标签ℓ̂_t + 历史技能ℓ̂_0...ℓ̂_{t-1}
   输出: 合理的用户prompt ℓ_t + 机器人语音u_t
4. 场景分类确保多样性:
   - 否定任务("不要做X")
   - 情境修正("那个不是垃圾")
   - 特定约束("我对泡菜过敏")
```

#### 训练目标

- High-level: 交叉熵损失，在$D_{syn} \cup D_{labeled}$上next-token prediction
- Low-level: Flow-matching目标(π0方法)，在$D_{labeled} \cup D_{demo}$上训练

#### 模型架构

- 基座: PaliGemma-3B VLM
- Low-level: π0 VLA = PaliGemma + flow-matching action expert
- High-level: PaliGemma微调(仅预测文本token)
- 训练: 全模型解冻, AdamW(β1=0.9, β2=0.95), lr=1e-5, batch=512

#### 实时性能(RTX 4090)

- Low-level推理: 73ms (10Hz控制率)
- High-level推理: 47ms(prefill) + 13.2ms(decode)

### 复现指南

#### 数据集

**机器人平台**:
1. **UR5e**: 6-DoF单臂+平行夹爪(2相机,7维)
2. **Bimanual ARX**: 双6-DoF臂(3相机,14维)
3. **Mobile ARX**: Mobile ALOHA平台(16维)

**任务数据**:
- **Table Bussing**: 清理餐桌(碗碟→收纳盒,垃圾→垃圾桶)
- **Sandwich Making**: 制作三明治(6种食材+面包)
- **Grocery Shopping**: 杂货拣货(移动平台导航+双臂抓取)

每任务收集遥操作轨迹，粗标注任务目标，分割为1-3秒技能片段并细标注。

#### 实现步骤

**1. 环境搭建**:
```bash
pip install paligemma flow-matching whisper
# Cartetia API用于TTS
```

**2. 数据准备**:
```python
# 遥操作演示
D_demo = collect_teleoperation_data()  # 粗标注

# 技能分割
D_labeled = segment_to_skills(D_demo, duration=(1,3))

# 合成数据生成
D_syn = []
for (skill, images, history) in D_labeled:
    prompt = f"给定观察{images}和历史{history},生成可能导致{skill}的用户指令"
    synthetic_interaction = p_gen.generate(prompt)
    D_syn.append((images, synthetic_interaction, skill))
```

**3. 训练High-level策略**:
```python
model = PaliGemma.from_pretrained("paligemma-3b")
optimizer = AdamW(lr=1e-5, betas=(0.9, 0.95))

for (images, user_prompt, skill_label) in (D_syn + D_labeled):
    loss = cross_entropy_loss(model(images, user_prompt), skill_label)
    loss.backward()
    clip_grad_norm_(model.parameters(), 1.0)
    optimizer.step()
```

**4. 训练Low-level策略**:
```python
low_level = Pi0VLA(backbone=PaliGemma("paligemma-3b"))

for (images, skill_label, robot_state, actions) in (D_labeled + D_demo):
    flow_loss = flow_matching_loss(
        low_level(images, skill_label, robot_state),
        actions  # 动作块A_t
    )
    flow_loss.backward()
```

**5. 部署推理**:
```python
high_level_hz = 1  # 每秒更新一次
low_level_hz = 10  # 10Hz控制

while task_running:
    # High-level更新(每1秒或收到新反馈)
    if time_elapsed > 1 or new_user_feedback:
        atomic_cmd, verbal = high_level(images, user_prompt)
        if verbal:
            text_to_speech(verbal)
    
    # Low-level执行(高频)
    actions = low_level(images, atomic_cmd, robot_state)
    robot.execute(actions)
```

#### 计算资源

- **训练**: 8×H100 (High-level 2h, Low-level视数据规模)
- **推理**: 1-2×RTX 4090 (消费级GPU实时运行)

#### 复现难度: ★★★★☆

**难点**:
1. 合成数据质量: 需精心设计VLM prompt确保生成多样且合理的交互场景
2. 技能分割标注: 1-3秒原子技能的边界划分需人工判断
3. 多机器人适配: 三种不同平台的数据收集和标定
4. 实时性调优: 双层推理频率的平衡

**可用资源**:
- 代码: 论文未明确开源，需自行实现
- 预训练模型: PaliGemma-3B公开，π0 VLA方法参考Black et al. 2024
- 数据: 需自行收集遥操作演示

---

## Trend Analysis

### 1. 方法论趋势

**从大模型走向高效化**:
- **规模缩减**: TinyVLA 1.3B、SmolVLA 450M达到7B模型90%性能
- **训练加速**: FAST 5倍训练提速、SmolVLA异步推理消除idle gap
- **数据效率**: 预训练需求从970K(OpenVLA)降至2.3万episodes(SmolVLA)，甚至零机器人数据(TinyVLA)

**架构创新方向**:
- **分层VLA**: Hi robot双VLM架构、π₀.₅高低层分层推理、CoT-VLA视觉思维链
- **模块化设计**: DexVLA插件式扩散专家、TinyVLA LoRA冻结VLM
- **混合表示**: 离散+连续(π₀.₅ FAST+flow matching)、自适应网格(SpatialVLA)

**空间感知突破**:
- SpatialVLA Ego3D编码首次系统引入3D位置信息
- 自适应动作网格实现跨机器人动作空间对齐

### 2. 应用趋势

**能力跃迁**:
- **简单→复杂**: 从原子指令("拿杯子")到开放式交互("做素食三明治，我对泡菜过敏")
- **短时→长时**: DexVLA 2分钟洗衣折叠、Hi robot多步骤任务规划
- **单具身→跨具身**: SpatialVLA零样本泛化、DexVLA 60%跨灵巧手成功率

**数据来源多样化**:
- 无动作视频利用: CoT-VLA整合EPIC-KITCHEN-100
- 社区数据挖掘: SmolVLA 481个开源数据集
- 合成数据生成: Hi robot反向VLM生成、π₀.₅多源异构融合

### 3. 技术演进

**Action表示演进**:
```
2022 RT-1: Per-dim 256-bin离散化
2023 π0:   Flow matching连续表示
2024 FAST: DCT压缩式tokenization (13.2x压缩)
2025 SpatialVLA: 自适应高斯网格 (3 tokens/动作)
```

**推理效率提升**:
| 模型 | 推理延迟 | 吞吐量 | 加速技术 |
|------|----------|--------|----------|
| OpenVLA | 292ms | 3.4Hz | - |
| TinyVLA | 14ms | 71Hz | Diffusion Policy |
| FAST | 750ms | 1.3Hz | DCT压缩 |
| SpatialVLA | 50ms | 20Hz | 3-token表示 |
| SmolVLA | 100ms | 10Hz | 异步推理栈 |

**视觉推理增强**:
- CoT-VLA: 子目标图像生成(视觉思维链)
- DexVLA: 子步推理FiLM调制
- Hi robot: 情境化视觉-语言交互

---

## 推荐阅读顺序

### 1. 入门路径 (VLA零基础→掌握核心概念)

**第1周: 领域全景认知**
1. **[Survey] VLA综述** (论文1)
   - 阅读重点: Abstract + 第III节(组件/策略/规划器) + 第V节(数据集/基准)
   - 收获: 建立VLA全景认知、了解LIBERO/CALVIN等标准基准
   - 实践: 在VIMA-Bench上运行现成模型，体验VLA输入输出

**第2周: 经典范式理解**
2. **[FAST] 高效tokenization** (论文3)
   - 阅读重点: 第II节(问题形式化) + 第III节(DCT方法) + 实验对比
   - 收获: 理解action tokenization困境、DCT压缩原理
   - 实践: 实现FAST tokenizer，对比naive binning在50Hz数据上的效果

3. **[π₀.₅] 分层VLA** (论文2)
   - 阅读重点: 两阶段分层架构 + 异构数据协同训练
   - 收获: 掌握高低层分层推理、flow matching连续动作生成
   - 实践: 在OXE数据子集上训练简化版分层模型

**第3周: 实战能力建设**
4. **[OpenVLA-OFT] 微调优化** (论文4)
   - 阅读重点: 并行解码+动作分块 + L1回归 + FiLM增强
   - 收获: 学会VLA微调技巧，理解速度-性能trade-off
   - 实践: 在LIBERO上微调OpenVLA，复现Table 2结果

### 2. 深度研究路径 (掌握前沿→推动创新)

**阶段1: 效率前沿探索**
5. **[TinyVLA] 轻量化设计** (论文6)
   - 研究重点: 小型VLM+Diffusion Policy架构、无需预训练的数据效率
   - 延伸阅读: Diffusion Policy原论文、LoRA技术
   - 研究方向: 探索更小模型(100M级)的性能边界

6. **[SmolVLA] 社区数据挖掘** (论文8)
   - 研究重点: 481个开源数据集标准化、异步推理栈设计
   - 延伸阅读: Flow Matching理论、LeRobot框架
   - 研究方向: 自动化数据质量评估、更优的异步调度策略

**阶段2: 能力边界拓展**
7. **[CoT-VLA] 视觉推理** (论文5)
   - 研究重点: 视觉思维链、混合注意力机制、无动作视频利用
   - 延伸阅读: VILA-U多模态模型、残差量化
   - 研究方向: 更复杂的推理链(multi-hop)、视频预训练新范式

8. **[DexVLA] 灵巧操作** (论文9)
   - 研究重点: 十亿参数扩散专家、具身课程学习、子步推理
   - 延伸阅读: ScaleDP、FiLM调制机制
   - 研究方向: 更精细的灵巧手控制、自动化子步分割

**阶段3: 系统集成创新**
9. **[SpatialVLA] 3D空间感知** (论文7)
   - 研究重点: Ego3D位置编码、自适应动作网格、跨具身泛化
   - 延伸阅读: ZoeDepth深度估计、高斯混合模型
   - 研究方向: 融合触觉/力反馈的多模态空间表征

10. **[Hi robot] 开放式交互** (论文10)
    - 研究重点: 双VLM分层架构、合成数据反向生成、情境化反馈
    - 延伸阅读: System 1/System 2认知模型、PaliGemma架构
    - 研究方向: 更自然的人机协作、主动询问机制

---

**学习建议**:
- **入门路径**: 适合6个月内快速掌握VLA核心技能，每周投入20小时
- **深度路径**: 适合博士研究/工业研发，需3-6个月深入探索，每篇论文投入1-2周复现验证
- **交叉阅读**: 在深度路径中，同时关注效率(5,6)、能力(7,8)、系统(9,10)三个维度，形成立体认知
- **实践优先**: 每读完一篇论文，至少完成一个简化版实验验证核心想法

---

**本周报生成时间**: 2026-06-08  
**数据覆盖**: 2024-2025年VLA领域10篇高影响力论文(总被引3000+次)  
**下期预告**: VLA在具身智能长时程任务规划中的最新进展
