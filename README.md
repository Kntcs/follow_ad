# 学术研究自动跟踪系统

自动跟踪和整理自动驾驶、大模型、GPU/图形学等领域的最新研究进展。

## 系统概览

该系统通过定时任务自动搜索学术论文、下载PDF、分析内容并生成周报，支持：

- ✅ **自动去重**：避免重复分析相同论文
- ✅ **综述优先**：优先选择和分析综述类论文
- ✅ **Git 集成**：报告自动提交到版本控制
- ✅ **系统通知**：macOS 通知提醒新报告生成
- ✅ **自动归档**：30 天后旧报告自动归档

## 跟踪领域

| 领域 | 更新频率 | 时间 |
|------|---------|------|
| **VLA/端到端学习** | 每周两次 | 周一、周四 9:07 |
| **大模型 (LLM)** | 每周两次 | 周一、周四 9:22 |
| **规划与控制** | 每周一次 | 周一 9:37 |
| **GPU加速/图形学** | 每周一次 | 周四 9:52 |
| **数学** | 每周一次 | 周一 9:52 |
| **形式逻辑** | 每周一次 | 周一 10:07 |

## 目录结构

```
follow_ad/
├── research_reports/          # 研究报告
│   ├── weekly_vla_20260601.md
│   ├── weekly_llm_20260601.md
│   └── archive/               # 归档目录（30天后）
│       └── 2026-05/
├── scripts/                   # 自动化脚本
│   ├── commit_report.sh       # Git 提交脚本
│   └── archive_old_reports.sh # 归档脚本
├── .analyzed_papers.json      # 已分析论文数据库
└── README.md                  # 本文档
```

## 报告格式

每份周报包含：

1. **Executive Summary** - 综合所有论文的核心发现
2. **论文深度分析**（4级框架）
   - Level 1: Overview（一句话总结、主要贡献）
   - Level 2: Technical Deep Dive（方法论、公式、算法）
   - Level 3: Reproduction Guide（数据集、架构、训练配置）
   - Level 4: Innovation Analysis（突破点、局限、未来方向）
3. **Trend Analysis** - 横向对比和趋势分析
4. **推荐阅读顺序** - 按难度/重要性排序
5. **References** - 完整引用和链接

## 自动化流程

```
每周一/周四 9:00-10:00
    ↓
1. Cron 触发搜索
    ↓
2. 搜索 arxiv + Semantic Scholar
    ↓
3. 过滤已分析论文（去重）
    ↓
4. 下载 PDFs 并提取内容
    ↓
5. Claude AI 执行 4 级分析
    ↓
6. 生成 Markdown 报告
    ↓
7. 更新论文数据库
    ↓
8. Git 自动提交
    ↓
9. 发送 macOS 通知
```

## 手动使用

### 立即生成某个领域的报告

```bash
# 在 Terminal 中运行
/Users/alexyang/.claude/skills/paper-scholar/scripts/cron_weekly.sh vla
```

支持的领域：`vla`, `llm`, `planning-control`, `gpu-graphics`, `mathematics`, `formal-logic`

### 查看定时任务

```bash
crontab -l
```

### 查看执行日志

```bash
tail -f ~/paper_scholar_cron.log
```

### 手动归档旧报告

```bash
./scripts/archive_old_reports.sh
```

## 已分析论文数据库

系统维护一个 `.analyzed_papers.json` 文件，记录所有已分析的论文 ID。

查看已分析论文数量：
```bash
cat .analyzed_papers.json | python3 -c "import sys, json; print(len(json.load(sys.stdin)))"
```

## Git 工作流

- ✅ 每次报告生成后自动 commit
- ✅ 包含详细的 commit message（领域、日期、报告路径）
- ✅ 自动添加 `.analyzed_papers.json` 更新
- ✅ 归档操作也会自动 commit

查看提交历史：
```bash
git log --oneline --grep="research report"
```

## 自定义配置

### 修改更新频率

编辑 crontab：
```bash
crontab -e
```

Cron 时间格式：`分 时 日 月 星期`
- 星期：0=周日, 1=周一, ..., 6=周六
- 示例：`7 9 * * 1,4` = 每周一和周四 9:07

### 添加新领域

1. 编辑 `/Users/alexyang/.claude/skills/paper-scholar/scripts/auto_search.sh`
2. 在 `FIELD_QUERIES` 中添加新领域：
   ```bash
   ["new-field"]="your search query here"
   ```
3. 添加到 crontab：
   ```bash
   30 9 * * 1 /path/to/cron_weekly.sh new-field >> ~/paper_scholar_cron.log 2>&1
   ```

### 调整综述权重

编辑 `/Users/alexyang/.claude/skills/paper-scholar/scripts/search_papers.py`：
```python
# 第 156 行附近
if any(keyword in title_lower for keyword in ['survey', 'review', 'overview', 'tutorial']):
    base_score *= 3.0  # 修改这个倍数
```

## 故障排查

### 报告没有生成

1. 检查 cron 日志：
   ```bash
   tail -50 ~/paper_scholar_cron.log
   ```

2. 验证 Claude CLI 可用：
   ```bash
   which claude
   /opt/homebrew/bin/claude --version
   ```

3. 手动测试脚本：
   ```bash
   /Users/alexyang/.claude/skills/paper-scholar/scripts/cron_weekly.sh vla
   ```

### macOS 通知没有显示

检查系统偏好设置 → 通知 → 脚本编辑器 → 允许通知

### Git 提交失败

```bash
cd /Users/alexyang/git_repo/follow_ad
git status
git log
```

## 维护

### 每月检查

- 查看归档目录大小
- 检查 `.analyzed_papers.json` 是否过大（>1000 条考虑清理）
- 查看 `~/paper_scholar_cron.log`（定期清空）

### 清理日志

```bash
# 备份日志
mv ~/paper_scholar_cron.log ~/paper_scholar_cron.log.backup

# 创建新日志
touch ~/paper_scholar_cron.log
```

## 高级功能

### 批量测试所有领域

```bash
for field in vla llm planning-control gpu-graphics; do
    echo "Testing $field..."
    /Users/alexyang/.claude/skills/paper-scholar/scripts/cron_weekly.sh "$field"
    sleep 5
done
```

### 生成统计报告

```bash
# 统计各领域报告数量
ls -1 research_reports/weekly_*.md | cut -d'_' -f2 | sort | uniq -c
```

### 搜索特定主题

```bash
# 在所有报告中搜索关键词
grep -r "transformer" research_reports/
```

## 系统要求

- macOS (用于通知功能)
- Git
- Claude CLI (`/opt/homebrew/bin/claude`)
- Python 3.x (用于搜索和过滤)
- Node.js (用于 PDF 提取)

## 技术栈

- **调度**: Unix cron
- **搜索**: arxiv API + Semantic Scholar API
- **AI 分析**: Claude Sonnet 4 (via Claude CLI)
- **版本控制**: Git
- **通知**: macOS osascript
- **语言**: Bash, Python 3, Node.js

## 贡献者

系统由 Claude Sonnet 4 设计和实现，基于用户需求定制。

---

**最后更新**: 2026-06-01  
**系统版本**: 1.0  
**状态**: ✅ 运行中
