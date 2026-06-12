# 邮件发送配置指南

## 快速开始 (5分钟)

### 第1步: 获取QQ邮箱授权码

1. 访问 [QQ邮箱网页版](https://mail.qq.com/)
2. 点击 **设置** → **账户**
3. 找到 **POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务**
4. 开启 **IMAP/SMTP服务**
5. 点击 **生成授权码** (会发送短信验证码)
6. 复制生成的 **16位授权码**

### 第2步: 配置环境变量

⚠️ **安全警告:** 
- **禁止**将授权码写入任何可能被git追踪的文件
- **禁止**通过即时通讯工具明文传输授权码
- **必须**仅在本地 `~/.zshrc` 或环境变量中配置

#### 方式A: 永久配置 (推荐)
```bash
# 在你的本地终端执行 (不要复制到脚本文件)
echo 'export QQ_MAIL_AUTH_CODE="你的16位授权码"' >> ~/.zshrc
source ~/.zshrc
```

#### 方式B: 临时配置 (仅当前会话)
```bash
# 仅当前终端会话有效
export QQ_MAIL_AUTH_CODE="你的16位授权码"
```

#### 验证配置 (不显示实际值)
```bash
# 检查是否已设置 (输出: QQ_MAIL_AUTH_CODE is set)
[ -n "$QQ_MAIL_AUTH_CODE" ] && echo "QQ_MAIL_AUTH_CODE is set" || echo "NOT set"
```

### 第3步: 验证配置

```bash
# 检查环境变量
echo $QQ_MAIL_AUTH_CODE

# 测试邮件发送
cd /Users/alexyang/git_repo/follow_ad
./scripts/test_email.sh
```

## 常见问题

### Q1: 提示 "Missing QQ_MAIL_AUTH_CODE"
**原因:** 环境变量未设置  
**解决:** 运行 `export QQ_MAIL_AUTH_CODE="你的授权码"`

### Q2: "SMTP authentication failed"
**原因:** 授权码错误或已失效  
**解决:** 重新生成授权码并更新环境变量

### Q3: "certificate verify failed"
**原因:** SSL证书验证问题 (已在代码中自动处理)  
**解决:** 无需操作,代码已禁用证书验证

### Q4: 邮件发送很慢
**原因:** 网络问题或SMTP服务器响应慢  
**解决:** 
- 检查网络连接
- 尝试使用代理: `export ALL_PROXY=socks5://127.0.0.1:1080`

### Q5: 收不到邮件
**检查清单:**
- [ ] QQ邮箱垃圾箱
- [ ] QQ邮箱设置 → 反垃圾 → 白名单
- [ ] 查看脚本日志: `[SUCCESS] Email sent to ...`

## 高级配置

### 更换邮件服务商

#### Gmail
```python
smtp_server = "smtp.gmail.com"
smtp_port = 587  # TLS端口
# 需要在Google账号启用"应用专用密码"
```

#### 163邮箱
```python
smtp_server = "smtp.163.com"
smtp_port = 465
# 需要在163邮箱开启SMTP服务并生成授权码
```

### 自定义收件人

编辑 `scripts/commit_report.sh` 第340行:
```python
EMAIL_RECIPIENT = "your_email@example.com"
```

### 监控邮件发送

```bash
# 查看发送日志
tail -f /tmp/email_send.log

# 监控内存占用
watch -n 1 'ps aux | grep python3 | grep -v grep'
```

## 安全建议 (重要!)

### 🔒 授权码保护规则

#### ✅ 必须遵守
1. **仅本地保存**: 授权码只能存储在本地 `~/.zshrc` 或环境变量中
2. **禁止上传git**: 
   - ❌ 不要写入任何git跟踪的文件
   - ❌ 不要写入脚本(.sh/.py)
   - ❌ 不要写入配置文件(除非已在.gitignore)
   - ✅ `.claude/` 目录已加入 `.gitignore`,可安全使用
3. **禁止明文传输**: 
   - ❌ 不要通过微信/QQ/邮件发送
   - ❌ 不要复制到剪贴板共享
   - ✅ 只能本人在本地终端配置
4. **设置文件权限**: `chmod 600 ~/.zshrc`
5. **定期更换**: 每3-6个月重新生成授权码

#### ❌ 严禁的危险操作
- ❌ 将授权码硬编码到脚本中
- ❌ 提交包含授权码的文件到git
- ❌ 在公共电脑或共享环境配置
- ❌ 使用个人主邮箱的授权码做自动化
- ❌ 将含授权码的 .zshrc 加入云同步

### 🔍 自查清单

运行以下命令检查是否泄漏:
```bash
# 检查git历史
git log --all -S "你的授权码" --oneline

# 检查当前工作目录
grep -r "你的授权码" . --exclude-dir=.git --exclude-dir=.claude

# 检查暂存区
git diff --cached | grep "你的授权码"
```

如果发现泄漏,立即:
1. 重新生成新的授权码
2. 使用 `git filter-branch` 或 `BFG Repo-Cleaner` 清理git历史
3. Force push到远程仓库 (如果已推送)

## 故障排查

### 调试模式

```bash
# 启用详细日志
export DEBUG=1

# 运行测试
./scripts/commit_report.sh vla 20260609 research_reports/weekly_vla_20260609.md
```

### 手动测试SMTP连接

```python
python3 << 'EOF'
import smtplib, ssl, os

context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

try:
    server = smtplib.SMTP_SSL('smtp.qq.com', 465, context=context, timeout=10)
    server.login('1922585801@qq.com', os.environ['QQ_MAIL_AUTH_CODE'])
    print("✓ SMTP连接成功")
    server.quit()
except Exception as e:
    print(f"✗ 连接失败: {e}")
EOF
```

## 性能指标

正常情况下的预期性能:

| 指标 | 期望值 |
|------|--------|
| 连接时间 | < 2秒 |
| 发送时间 (小邮件) | < 3秒 |
| 发送时间 (大邮件) | < 5秒 |
| 内存占用 | < 50MB |
| CPU占用 | < 10% |

如果超出这些指标,请检查:
1. 网络连接质量
2. SMTP服务器状态
3. 邮件大小 (附件>10MB需要优化)

## 更新历史

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-09 | v2.0 | 修复83GB内存泄漏,改用SMTP |
| 2026-06-08 | v1.0 | 初始版本 (AppleScript) |

## 支持

- **文档:** `BUGFIX_83GB_MEMORY_LEAK.md`
- **测试脚本:** `scripts/test_email.sh`
- **主脚本:** `scripts/commit_report.sh`

---

**最后更新:** 2026-06-09  
**维护者:** @Kntcs
