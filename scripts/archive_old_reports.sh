#!/bin/bash
# archive_old_reports.sh - 归档30天前的报告

REPORT_DIR="/Users/alexyang/git_repo/follow_ad/research_reports"
ARCHIVE_BASE="${REPORT_DIR}/archive"

# 创建当前月份的归档目录
CURRENT_MONTH=$(date +%Y-%m)
ARCHIVE_DIR="${ARCHIVE_BASE}/${CURRENT_MONTH}"
mkdir -p "$ARCHIVE_DIR"

# 查找30天前的报告并移动
ARCHIVED_COUNT=0

find "$REPORT_DIR" -maxdepth 1 -name "weekly_*.md" -mtime +30 | while read -r report; do
    BASENAME=$(basename "$report")
    mv "$report" "${ARCHIVE_DIR}/${BASENAME}"
    echo "[$(date)] Archived: ${BASENAME} -> archive/${CURRENT_MONTH}/"
    ((ARCHIVED_COUNT++))
done

echo "[$(date)] Archived ${ARCHIVED_COUNT} old reports"

# Git 提交归档变更（可选）
cd /Users/alexyang/git_repo/follow_ad
if [[ -n $(git status --porcelain research_reports/) ]]; then
    git add research_reports/
    git commit -m "Archive old research reports

Moved reports older than 30 days to archive/${CURRENT_MONTH}/

Co-Authored-By: Claude Sonnet 4 <noreply@anthropic.com>"

    if [[ $? -eq 0 ]]; then
        echo "[$(date)] ✓ Archive committed to git"
    fi
fi
