# Skill和脚本SMTP迁移指南

## 概述

本文档说明 Paper Scholar 和 Paper Digest skills 如何适配 v2.0 的 SMTP 邮件发送方式。

## 修改范围

### 1. Paper Digest Skill

#### 已修改文件

**`~/.claude/skills/paper-digest/scripts/send_email.py`**
- ❌ 移除 `send_email_via_applescript()` - 使用AppleScript的旧方法
- ✅ 新增 `send_email_via_smtp()` - 使用Python SMTP的新方法
- ✅ 更新主函数调用: `send_email_via_smtp()`

**关键变更:**
```python
# 旧方法 (已移除)
def send_email_via_applescript(field, date, report_path, html_content):
    temp_html = f"/tmp/email_body_{date}.html"
    with open(temp_html, 'w') as f:
        f.write(html_content)
    
    applescript = f'''
    set htmlContent to (do shell script "cat {temp_html}")
    # ... AppleScript代码 ...
    '''
    subprocess.run(['osascript', '-e', applescript])

# 新方法 (已实现)
def send_email_via_smtp(field, date, report_path, html_content):
    import smtplib
    from email.mime.multipart import MIMEMultipart
    
    auth_code = os.environ.get('QQ_MAIL_AUTH_CODE', '')
    msg = MIMEMultipart('mixed')
    msg.attach(MIMEText(html_content, 'html', 'utf-8'))
    
    with smtplib.SMTP_SSL('smtp.qq.com', 465) as server:
        server.login(sender_email, auth_code)
        server.send_message(msg)
```

#### 新增文档

**`~/.claude/skills/paper-digest/EMAIL_SETUP.md`**
- 完整的SMTP配置指南
- QQ邮箱授权码获取步骤
- 故障排查和安全建议

**`~/.claude/skills/paper-digest/QUICKSTART.md`** (已更新)
- 添加 Step 0: 配置SMTP邮件发送
- 强调v2.0需要授权码

### 2. Paper Scholar Skill

#### 新增文档

**`~/.claude/skills/paper-scholar/EMAIL_CONFIG.md`**
- Paper Scholar的邮件配置说明
- 技术细节和性能对比
- 与主项目文档的交叉引用

**`~/.claude/skills/paper-scholar/AUTOMATION.md`** (已更新)
- 添加邮件配置警告
- 提示用户先配置SMTP

### 3. 主项目脚本

**`scripts/cron_weekly_parallel.sh`**
- ✅ 无需修改
- 第299行已调用新的 `commit_report.sh`
- 自动使用SMTP发送

**`scripts/commit_report.sh`**
- ✅ 已在主修复中更新
- 完整的SMTP实现

## 配置要求

### 必需: QQ邮箱授权码

所有邮件发送功能都需要配置:

```bash
# 在你的本地终端执行
echo 'export QQ_MAIL_AUTH_CODE="你的16位授权码"' >> ~/.zshrc
source ~/.zshrc
```

### 获取授权码步骤

1. 访问 https://mail.qq.com/
2. 设置 → 账户 → POP3/IMAP/SMTP服务
3. 开启 IMAP/SMTP服务
4. 生成授权码 (16位)

详细步骤见:
- `EMAIL_SETUP_GUIDE.md` (主项目)
- `~/.claude/skills/paper-digest/EMAIL_SETUP.md`
- `~/.claude/skills/paper-scholar/EMAIL_CONFIG.md`

## 技术对比

### 为什么迁移到SMTP?

| 指标 | AppleScript (v1.0) | SMTP (v2.0) | 改进 |
|------|-------------------|------------|------|
| 内存占用 | 83GB | < 50MB | **99.9%↓** |
| 发送时间 | 10-60秒 | 2-5秒 | **80%↓** |
| 最大HTML | 287KB失败 | >10MB | ∞ |
| 依赖 | Mail.app | 无 | N/A |

**根本原因:**
- AppleScript通过变量传递HTML导致多重内存拷贝
- 287KB HTML在Apple Events序列化时膨胀至数十GB
- Mail.app的NSTextStorage处理进一步放大内存占用

**SMTP优势:**
- 流式传输,内存占用恒定
- 不依赖GUI应用
- 支持任意大小内容

详细技术分析: [BUGFIX_83GB_MEMORY_LEAK.md](BUGFIX_83GB_MEMORY_LEAK.md)

## 使用说明

### Paper Digest

```bash
# 在Claude Code中
/paper-digest vla

# 或直接运行脚本
cd ~/.claude/skills/paper-digest/scripts
./generate_digest.sh vla
```

### Paper Scholar

```bash
# 在Claude Code中  
/paper-scholar vla

# 或使用cron脚本
cd ~/git_repo/follow_ad
./scripts/cron_weekly_parallel.sh vla
```

## 测试验证

### 1. 环境变量检查

```bash
[ -n "$QQ_MAIL_AUTH_CODE" ] && echo "✓ 已配置" || echo "✗ 未配置"
```

### 2. SMTP连接测试

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

### 3. Paper Digest邮件测试

```bash
cd ~/.claude/skills/paper-digest/scripts
export QQ_MAIL_AUTH_CODE="your_code"
./test_email.sh
```

### 4. 完整流程测试

```bash
cd ~/git_repo/follow_ad
export QQ_MAIL_AUTH_CODE="your_code"
./scripts/commit_report.sh vla 20260609 research_reports/weekly_vla_20260609.md
```

## 故障排查

### 提示 "Missing QQ_MAIL_AUTH_CODE"

```bash
export QQ_MAIL_AUTH_CODE="你的授权码"
```

### "SMTP authentication failed"

- 重新生成QQ邮箱授权码
- 确认授权码输入正确

### 邮件发送很慢

- 检查网络连接
- 尝试使用代理: `export ALL_PROXY=socks5://127.0.0.1:1080`

### 收不到邮件

- 检查QQ邮箱垃圾箱
- 查看日志: `[SUCCESS] Email sent to ...`

## 安全注意事项

### ✅ 必须遵守

1. **仅本地保存**: 授权码只存储在 `~/.zshrc`
2. **禁止上传git**: 
   - ❌ 不要写入脚本文件
   - ❌ 不要写入配置文件
   - ✅ `.claude/` 已在 `.gitignore` 中
3. **禁止明文传输**: 不要通过微信/QQ/邮件发送
4. **定期更换**: 每3-6个月重新生成授权码

### 🔍 安全自查

```bash
cd ~/git_repo/follow_ad
./scripts/security_check.sh
```

## 文档体系

```
主项目 (follow_ad)
├── BUGFIX_83GB_MEMORY_LEAK.md       # 技术分析报告
├── EMAIL_SETUP_GUIDE.md              # 用户配置指南
├── SKILL_SMTP_MIGRATION.md           # 本文档
├── scripts/
│   ├── commit_report.sh              # SMTP实现
│   ├── cron_weekly_parallel.sh       # 周报生成
│   └── security_check.sh             # 安全检查
│
Paper Digest (~/.claude/skills/paper-digest/)
├── EMAIL_SETUP.md                    # Digest配置指南
├── QUICKSTART.md                     # 快速入门
└── scripts/
    ├── send_email.py                 # SMTP实现
    ├── generate_digest.sh            # 周报生成
    └── test_email.sh                 # 测试脚本
│
Paper Scholar (~/.claude/skills/paper-scholar/)
├── EMAIL_CONFIG.md                   # Scholar配置指南
└── AUTOMATION.md                     # 自动化文档
```

## 迁移检查清单

- [x] 主项目 `commit_report.sh` 更新为SMTP
- [x] Paper Digest `send_email.py` 更新为SMTP
- [x] Paper Digest 文档更新
- [x] Paper Scholar 文档更新
- [x] `cron_weekly_parallel.sh` 验证兼容性
- [x] 安全检查脚本完善
- [x] `.gitignore` 配置 `.claude/`
- [x] 所有文档添加安全警告
- [x] 测试验证通过

## 相关链接

- [主项目修复报告](BUGFIX_83GB_MEMORY_LEAK.md)
- [邮件配置指南](EMAIL_SETUP_GUIDE.md)
- [安全检查脚本](scripts/security_check.sh)
- [Paper Digest配置](~/.claude/skills/paper-digest/EMAIL_SETUP.md)
- [Paper Scholar配置](~/.claude/skills/paper-scholar/EMAIL_CONFIG.md)

---

**版本**: v2.0  
**迁移日期**: 2026-06-09  
**状态**: ✅ 已完成
