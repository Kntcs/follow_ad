#!/usr/bin/env python3
"""
filter_research_papers.py - 过滤研究型论文（排除综述）

用法:
  python3 filter_research_papers.py input.json output.json
"""

import json
import sys
import re

# 综述关键词（出现在标题中则排除）
SURVEY_KEYWORDS = [
    'survey', 'review', 'overview', 'tutorial',
    '综述', '综合', '概述', '评述',
    'state-of-the-art', 'state of the art',
    'systematic review', 'literature review',
    'recent advances', 'recent progress',
    'taxonomy', 'categorization'
]

# 研究型论文特征关键词（出现则加分）
RESEARCH_KEYWORDS = [
    'novel', 'propose', 'method', 'algorithm', 'model',
    'architecture', 'framework', 'approach', 'technique',
    'learning', 'training', 'optimization',
    'experimental', 'evaluation', 'benchmark',
    'outperform', 'improve', 'enhance', 'achieve'
]


def is_survey(paper):
    """判断是否为综述论文"""
    title = paper.get('title', '').lower()
    abstract = paper.get('abstract', '').lower()

    # 检查标题中的综述关键词
    for keyword in SURVEY_KEYWORDS:
        if keyword in title:
            return True

    # 检查摘要前100字符
    abstract_head = abstract[:200]
    survey_count = sum(1 for kw in SURVEY_KEYWORDS if kw in abstract_head)

    # 如果摘要开头出现>=2个综述关键词，很可能是综述
    if survey_count >= 2:
        return True

    return False


def research_score(paper):
    """计算研究型论文得分（越高越可能是研究型）"""
    title = paper.get('title', '').lower()
    abstract = paper.get('abstract', '').lower()

    score = 0

    # 研究型关键词加分
    for keyword in RESEARCH_KEYWORDS:
        if keyword in title:
            score += 2
        if keyword in abstract[:300]:
            score += 1

    # 有实验结果的加分
    if any(word in abstract for word in ['experiment', 'result', 'performance', 'accuracy', 'benchmark']):
        score += 3

    # 有方法描述的加分
    if any(word in abstract for word in ['propose', 'introduce', 'present', 'develop']):
        score += 2

    # 综述特征减分
    if any(word in title for word in ['survey', 'review', 'overview']):
        score -= 10

    return score


def filter_papers(input_file, output_file, max_papers=10):
    """过滤论文并输出研究型论文"""

    # 读取输入
    with open(input_file, 'r') as f:
        data = json.load(f)

    papers = data.get('papers', [])

    print(f"原始论文数: {len(papers)}")

    # 过滤综述
    research_papers = [p for p in papers if not is_survey(p)]
    print(f"排除综述后: {len(research_papers)}")

    # 按研究得分排序
    scored = [(p, research_score(p)) for p in research_papers]
    scored.sort(key=lambda x: x[1], reverse=True)

    # 取前N篇
    top_papers = [p for p, score in scored[:max_papers]]

    print(f"\n筛选出的研究型论文:")
    for i, (p, score) in enumerate(scored[:max_papers], 1):
        title = p.get('title', 'Unknown')[:80]
        print(f"  {i}. [{score:2d}分] {title}")

    # 输出
    data['papers'] = top_papers
    data['filter_info'] = {
        'original_count': len(papers),
        'after_filter': len(research_papers),
        'selected': len(top_papers),
        'filter_type': 'research_papers_only'
    }

    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"\n✓ 已保存到 {output_file}")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("用法: python3 filter_research_papers.py input.json output.json")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    max_papers = int(sys.argv[3]) if len(sys.argv) > 3 else 10

    filter_papers(input_file, output_file, max_papers)
