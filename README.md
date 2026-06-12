# Follow AD - 论文跟踪与分析系统

自动化追踪和深度分析学术论文的系统，专注于AI、自动驾驶、大语言模型等前沿领域。

## 功能特性

### 📚 自动化周报
- 每周自动搜索、分析、汇总最新论文
- 支持多个研究领域：VLA、LLM、自动驾驶、数学、形式逻辑等
- 邮件自动发送HTML格式周报

### 🔍 深度论文分析
- 4层级深度分析：动机、贡献、方法、实验
- 包含公式推导、代码实现、复现指南
- 覆盖VLA、多模态、密码学等多个方向

### 🤖 智能筛选
- 自动过滤综述类论文
- 研究型论文评分排序
- 长尾场景特别关注

## 目录结构

```
follow_ad/
├── README.md                   # 项目说明
├── docs/                       # 文档目录
│   ├── BUGFIX_*.md            # Bug修复记录
│   ├── EMAIL_SETUP_GUIDE.md   # 邮件配置
│   └── SKILL_*.md             # 技术迁移文档
├── research_reports/           # 周报汇总
│   ├── weekly_vla_*.md        # VLA周报
│   ├── weekly_llm_*.md        # LLM周报
│   └── ...
├── paper_analysis/             # 单篇论文深度分析
│   ├── vla/                   # VLA相关
│   ├── llm/                   # LLM相关
│   ├── autonomous_driving/    # 自动驾驶
│   ├── multimodal/            # 多模态
│   ├── cryptography/          # 密码学
│   └── others/                # 其他
├── scripts/                    # 自动化脚本
│   ├── commit_report.sh       # 提交报告脚本
│   ├── cron_weekly_parallel.sh # 周报并行生成
│   ├── filter_research_papers.py # 论文筛选
│   └── search_papers.py       # 论文搜索
└── .gitignore

```

## 快速开始

### 前置要求
- Python 3.8+
- Claude CLI
- 邮件SMTP配置

### 生成周报
```bash
# VLA领域周报
./scripts/cron_weekly_parallel.sh vla

# LLM领域周报
./scripts/cron_weekly_parallel.sh llm

# 具身智能周报（自动过滤综述）
./scripts/cron_weekly_parallel.sh embodied-ai
```

### 配置定时任务
```bash
# 查看当前定时任务
crontab -l | grep follow_ad

# 示例cron配置
# 每周一9:07 - VLA周报
7 9 * * 1 /Users/alexyang/git_repo/follow_ad/scripts/cron_weekly_parallel.sh vla

# 每周二9:22 - 具身智能周报
22 9 * * 2 /Users/alexyang/git_repo/follow_ad/scripts/cron_weekly_parallel.sh embodied-ai
```

## 核心功能

### 1. 论文搜索与筛选
- 来源：arXiv + Semantic Scholar + Google Scholar
- 智能过滤：排除综述，优选研究型论文
- 评分系统：基于创新度、实验质量、引用量

### 2. 深度分析
每篇论文包含：
- **Motivation**: 研究动机和问题背景
- **Contribution**: 核心创新点
- **Method**: 技术方法和公式推导
- **Experiment**: 实验结果和消融分析
- **Innovation**: 创新点和影响分析

### 3. 自动化流程
1. **搜索** → 多源并行搜索最新论文
2. **筛选** → 智能过滤和评分排序
3. **分析** → Claude深度分析(并行处理)
4. **汇总** → 生成结构化周报
5. **提交** → Git自动提交
6. **发送** → 邮件HTML格式发送

## 技术栈

- **搜索引擎**: arXiv API, Semantic Scholar API
- **分析引擎**: Claude Sonnet 4
- **邮件发送**: Python smtplib (SMTP_SSL)
- **并行处理**: Python ThreadPoolExecutor
- **格式转换**: Markdown → HTML (MathJax支持)

## 已修复的重大Bug

### 83GB内存泄漏 (2026-06-09)
- **问题**: AppleScript处理大HTML导致内存膨胀至83GB
- **解决**: 迁移到Python smtplib直接SMTP发送
- **效果**: 内存占用从83GB降至<50MB (降低99.9%)
- **详细**: 见 `docs/BUGFIX_83GB_MEMORY_LEAK.md`

## 贡献领域

### VLA (Vision-Language-Action)
- 10+ 篇论文深度分析
- 涵盖DexVLA、HiroBot、SpatialVLA、TinyVLA等
- 周报自动生成，每周二/周五

### 自动驾驶
- SafeAuto深度分析 (18,000字)
- FocalAD学术总结
- MLLM驾驶系统研究

### 多模态
- 注意力机制分析
- LVLM目标检测
- 视觉语言模型

### 其他
- 密码学 (Hardened CTIDH)
- 形式逻辑
- GPU图形学

## 统计数据

- **论文分析**: 50+ 篇
- **周报生成**: 30+ 期
- **代码行数**: 5000+ 行
- **自动化任务**: 8个定时任务
- **邮件发送**: 100+ 封

## 许可证

MIT License

## 作者

Kntcs (alexyang)

## 更新日志

### 2026-06-12
- 重构目录结构
- 新增paper_analysis/和docs/目录
- 更新README文档

### 2026-06-10
- 新增SafeAuto深度分析
- 修复邮件发送bug

### 2026-06-09
- 修复83GB内存泄漏
- SMTP邮件发送迁移
- 新增具身智能定时任务

---

**Star** ⭐ 本项目，持续关注前沿研究！
