#!/bin/bash
# 安全检查脚本: 检测授权码泄漏

echo "=========================================="
echo "🔒 授权码安全检查"
echo "=========================================="

LEAKED=0

# 检查1: git跟踪的文件
echo "[1/4] 检查git跟踪的文件..."
if git ls-files | xargs grep -l "QQ_MAIL_AUTH_CODE.*[a-z0-9]{16}" 2>/dev/null | grep -v "security_check.sh"; then
    echo "❌ 发现泄漏: git跟踪的文件中包含授权码"
    LEAKED=1
else
    echo "✓ git跟踪的文件安全"
fi

# 检查2: git暂存区
echo "[2/4] 检查git暂存区..."
if git diff --cached | grep -q "QQ_MAIL_AUTH_CODE.*[a-z0-9]{16}"; then
    echo "❌ 发现泄漏: 暂存区包含授权码"
    LEAKED=1
else
    echo "✓ 暂存区安全"
fi

# 检查3: 工作目录 (排除安全目录)
echo "[3/4] 检查工作目录..."
FOUND=$(grep -r "QQ_MAIL_AUTH_CODE.*[a-z0-9]{16}" . \
    --exclude-dir=.git \
    --exclude-dir=.claude \
    --exclude-dir=node_modules \
    --exclude-dir=venv \
    --exclude="security_check.sh" \
    --exclude="*.md" \
    2>/dev/null)

if [ -n "$FOUND" ]; then
    echo "❌ 发现泄漏:"
    echo "$FOUND"
    LEAKED=1
else
    echo "✓ 工作目录安全"
fi

# 检查4: .gitignore配置
echo "[4/4] 检查 .gitignore 配置..."
if grep -q "^\.claude" .gitignore 2>/dev/null; then
    echo "✓ .claude/ 已在 .gitignore 中"
else
    echo "⚠️  建议添加: echo '.claude/' >> .gitignore"
fi

echo "=========================================="
if [ $LEAKED -eq 0 ]; then
    echo "✅ 安全检查通过"
    echo "=========================================="
    exit 0
else
    echo "🔴 发现安全问题!"
    echo "=========================================="
    echo "修复步骤:"
    echo "1. 立即重新生成QQ邮箱授权码"
    echo "2. 从代码中移除泄漏的授权码"
    echo "3. 清理git历史: git filter-branch 或 BFG"
    echo "4. 如果已推送远程: git push --force"
    echo "=========================================="
    exit 1
fi
