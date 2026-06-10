#!/bin/bash
#
# 并行版本的周报生成脚本
# 通过并行分析多篇论文提速3倍（30min → 10min）
#

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CLAUDE_BIN="/opt/homebrew/bin/claude"

# 配置邮件发送授权码 (用于cron/LaunchAgent定时任务)
# 注意: 此授权码仅用于本地自动化,不会上传到git
export QQ_MAIL_AUTH_CODE="${QQ_MAIL_AUTH_CODE:-jxzjlacotuvnedfg}"

FIELD="$1"
DATE=$(date +%Y%m%d)
REPORT_DIR="/Users/alexyang/git_repo/follow_ad/research_reports"
TEMP_DIR="/tmp/paper_scholar_${FIELD}_${DATE}"

mkdir -p "$REPORT_DIR"
mkdir -p "$TEMP_DIR"

if [[ ! -x "$CLAUDE_BIN" ]]; then
    echo "[ERROR] $(date) - Claude CLI not found at $CLAUDE_BIN" >&2
    exit 1
fi

echo "[$(date)] Starting parallel analysis for ${FIELD}..."

# Step 1: 搜索论文（使用原有的search脚本）
echo "[$(date)] Step 1/4: Searching papers..."

cd /Users/alexyang/.claude/skills/paper-scholar/scripts
source venv/bin/activate

# 构建搜索查询
case "${FIELD}" in
    vla) QUERY="vision language action model robot" ;;
    llm) QUERY="large language model" ;;
    mathematics) QUERY="mathematics algebra geometry" ;;
    formal-logic) QUERY="formal logic verification" ;;
    temporal-logic) QUERY="temporal logic model checking" ;;
    planning-control) QUERY="motion planning trajectory control autonomous" ;;
    gpu-graphics) QUERY="GPU graphics rendering" ;;
    *) QUERY="${FIELD}" ;;
esac

# 直接用search_papers.py搜索
python3 search_papers.py \
    --query "${QUERY}" \
    --sources arxiv,semantic-scholar,google-scholar \
    --count 10 \
    --min-year 2025 \
    --output "${TEMP_DIR}/search_results.json" 2>&1 | tee "${TEMP_DIR}/search.log"

# 解析搜索结果
PAPER_COUNT=$(python3 -c "import json; d=json.load(open('${TEMP_DIR}/search_results.json')); print(len(d.get('papers', [])))")
echo "[$(date)] Found ${PAPER_COUNT} papers to analyze"

cd /Users/alexyang/git_repo/follow_ad

# Step 2: 并行分析论文（最多4个并行）
echo "[$(date)] Step 2/4: Analyzing papers in parallel (max 4 concurrent)..."

# 提取论文列表并启动并行分析
TEMP_DIR="${TEMP_DIR}" DATE="${DATE}" FIELD="${FIELD}" CLAUDE_BIN="${CLAUDE_BIN}" python3 << 'PYTHON'
import json
import subprocess
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

temp_dir = os.environ.get('TEMP_DIR', '/tmp/paper_scholar')
claude_bin = os.environ.get('CLAUDE_BIN', '/opt/homebrew/bin/claude')
field = os.environ.get('FIELD', 'unknown')
date = os.environ.get('DATE', '20260602')

# 读取搜索结果
with open(f"{temp_dir}/search_results.json") as f:
    data = json.load(f)
    papers = data.get('papers', [])

print(f"[{date}] Analyzing {len(papers)} papers in parallel...")

def analyze_paper(idx, paper):
    """分析单篇论文"""
    arxiv_id = paper.get('arxiv_id', 'N/A')
    title = paper.get('title', 'Unknown')
    citation_count = paper.get('citation_count', 0)

    output_file = f"{temp_dir}/paper_{idx+1}_analysis.md"

    # 判断是否高优先级（综述或高引用）
    is_survey = any(kw in title.lower() for kw in ['survey', 'review', 'overview'])
    priority = "high" if (is_survey or citation_count > 50) else "medium"
    levels = "Level 1-4" if priority == "high" else "Level 1-2"

    prompt = f"""对{field}领域论文进行完整、严谨的学术总结，按照标准学术论文结构撰写。

**论文信息**：
标题: {title}
arXiv ID: {arxiv_id}

**写作要求**：
1. 严格按照 Motivation → Contribution → Method → Experiment 四部分结构
2. 逻辑连贯：每部分承上启下，形成完整的论述链条
3. 术语规范：首次出现的缩写必须给出全称，如 VLA (Vision-Language-Action)
4. 完整性：每部分都要写透，不能跳跃或省略关键信息
5. 学术性：保持客观、准确，用数据说话

**输出格式**：

## {idx+1}. [{arxiv_id}] {title}

### 1. Motivation（研究动机）

**问题背景**：
[当前{field}领域的现状是什么？存在哪些具体问题或局限？3-5句话说清楚]

**为什么重要**：
[这些问题为什么需要解决？不解决会有什么影响？2-3句话说明研究意义]

**现有方法的不足**：
[已有工作尝试了什么？为什么不够好？指出gap在哪里]

### 2. Contribution（核心贡献）

本文的主要贡献包括：

1. **[贡献点1]**：[具体是什么，解决了什么问题]
2. **[贡献点2]**：[具体是什么，相比已有工作的优势]
3. **[贡献点3]**：[具体是什么，技术/方法上的创新]
4. **[实验验证]**：[在哪些任务上取得了什么样的效果]

### 3. Method（技术方法）

**3.1 整体框架**
[用2-3句话描述方法的总体思路，让读者建立全局认知]

**3.2 核心技术**

**(1) [技术模块1名称]**
- **作用**：[这个模块是干什么的]
- **设计**：[具体怎么实现的，关键技术点是什么]
- **为什么这样设计**：[设计背后的考虑，为什么能解决前面提到的问题]

**(2) [技术模块2名称]**
- **作用**：[这个模块是干什么的]
- **设计**：[具体怎么实现的，关键技术点是什么]
- **为什么这样设计**：[设计背后的考虑]

[如果有更多模块，继续按此结构展开]

**3.3 算法流程**
[如果有明确的算法流程，用分步骤的方式说明；如果是端到端模型，说明训练和推理的过程]

**3.4 与现有方法的区别**
[对比2-3个最相关的已有工作，说明本文方法在哪些方面不同，为什么这些不同能带来改进]

### 4. Experiment（实验验证）

**4.1 实验设置**
- **数据集**：[使用了哪些数据集，规模多大]
- **基线方法**：[对比了哪些方法]
- **评估指标**：[用什么指标衡量性能]

**4.2 主要结果**

[用表格或明确的数字对比展示主要实验结果]

**关键发现**：
- [发现1：具体的性能提升，相比哪个基线提升了多少]
- [发现2：在哪类任务上效果最好，说明了什么]

**4.3 消融实验**

[验证各个技术模块的有效性]

实验A - [验证什么]：
- 结果：[具体数字]
- 结论：[说明了这个模块的贡献是什么]

实验B - [验证什么]：
- 结果：[具体数字]
- 结论：[说明了什么]

**4.4 分析与讨论**
[对实验结果的深入分析：为什么会有这样的结果？有什么surprising的发现？局限性在哪里？]

---

只输出markdown格式，不要任何额外说明。
"""

    try:
        result = subprocess.run(
            [claude_bin, '-p', '--permission-mode', 'bypassPermissions', '--model', 'sonnet'],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=600
        )

        with open(output_file, 'w') as f:
            f.write(result.stdout)

        print(f"[{date}] ✓ Paper {idx+1}/{len(papers)}: {title[:60]}...")
        return True
    except Exception as e:
        print(f"[{date}] ✗ Paper {idx+1} failed: {e}")
        # 写入错误占位符
        with open(output_file, 'w') as f:
            f.write(f"## {idx+1}. [{arxiv_id}] {title}\n\n分析失败: {e}\n")
        return False

# 并行分析（最多4个）
with ThreadPoolExecutor(max_workers=4) as executor:
    futures = {executor.submit(analyze_paper, i, p): i for i, p in enumerate(papers)}
    for future in as_completed(futures):
        future.result()

print(f"[{date}] All papers analyzed")
PYTHON

# Step 3: 汇总生成最终报告
echo "[$(date)] Step 3/4: Generating final report..."

# 合并所有分析结果
cat ${TEMP_DIR}/paper_*_analysis.md > "${TEMP_DIR}/all_analyses.md" 2>/dev/null

# 首字母大写（兼容bash 3）
FIELD_TITLE=$(echo "${FIELD}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
ANALYSIS_COUNT=$(ls ${TEMP_DIR}/paper_*_analysis.md 2>/dev/null | wc -l | tr -d ' ')

"$CLAUDE_BIN" -p --permission-mode bypassPermissions --model sonnet << EOF > "${REPORT_DIR}/weekly_${FIELD}_${DATE}.md"
汇总生成${FIELD}领域周报。目标：帮助读者快速理解本周研究进展，同时保留足够深度。

**已完成的论文分析**：
$(cat "${TEMP_DIR}/all_analyses.md" 2>/dev/null || echo "无分析内容")

---

**格式要求**：

# ${FIELD_TITLE} 领域周报（${DATE}）

**本期论文**: ${ANALYSIS_COUNT}篇
**数据来源**: arXiv + Semantic Scholar

---

## 本周研究亮点

[用3-5句话总结本周最重要的研究突破，要求：]
1. 说清楚"取得了什么突破"，不要只罗列论文标题
2. 如有多篇论文探索同一方向，归纳共同趋势
3. 所有缩写必须解释（如 VLA: Vision-Language-Action）
4. 不使用表格、emoji

---

## 技术路线分类

[将本期论文按技术路线/应用场景分组，每组包括：]
### [分组名称]：[这组论文在解决什么问题]

**核心思路**: [这组论文的共同技术特点，2-3句话]

**代表论文**:
- 论文X ([arxiv_id]): [该论文的独特贡献，一句话]
- 论文Y ([arxiv_id]): [该论文的独特贡献，一句话]

**横向对比**: [这组论文之间的差异/互补性]

[重复以上结构，直到覆盖所有论文]

---

## 详细论文分析

[保留上面所有论文分析的原始内容，不要修改或删减]

---

## 阅读建议

**快速了解（3篇核心论文）**：
1. 论文X - [为什么推荐：代表性技术/高引用/开创性]
2. 论文Y - [为什么推荐：实用性/工程价值/SOTA性能]
3. 论文Z - [为什么推荐：方法新颖/未来方向]

**深度研读路径**（按技术关联排序）：
- [路径1名称]：论文A → 论文B → 论文C（先读A理解基础，B看改进，C看应用）
- [路径2名称]：论文D → 论文E（先读D的方法，再看E的验证）

---

输出完整markdown，不要添加任何解释性文字。
EOF

# Step 4: Git提交和邮件发送
echo "[$(date)] Step 4/4: Committing and sending email..."
REPORT_FILE="${REPORT_DIR}/weekly_${FIELD}_${DATE}.md"
if [[ -f "$REPORT_FILE" ]]; then
    /Users/alexyang/git_repo/follow_ad/scripts/commit_report.sh "${FIELD}" "${DATE}" "$REPORT_FILE"
    echo "[$(date)] ✓ Weekly ${FIELD} report completed"
else
    echo "[$(date)] ✗ Report file not found"
    exit 1
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo "[$(date)] Total time: check git log for timestamps"
