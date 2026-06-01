#!/bin/bash
# test_email.sh - 测试邮件发送功能

EMAIL_RECIPIENT="1922585801@qq.com"

echo "测试邮件发送到 ${EMAIL_RECIPIENT}..."

osascript << 'APPLESCRIPT'
tell application "Mail"
    set testMessage to make new outgoing message with properties {subject:"📧 Paper Scholar 测试邮件", content:"这是一封测试邮件。

如果您在 iPhone 上收到此邮件，说明邮件通知配置成功！

📱 iOS 通知已启用
🔔 您将在每次报告生成时收到邮件推送

测试时间：" & (current date) as string}

    tell testMessage
        make new to recipient at end of to recipients with properties {address:"1922585801@qq.com"}
    end tell

    send testMessage
end tell
APPLESCRIPT

if [[ $? -eq 0 ]]; then
    echo "✓ 测试邮件已发送！请检查您的 iPhone 邮件 app"
    echo ""
    echo "如果未收到邮件，请检查："
    echo "1. Mail.app 是否已配置邮箱账户"
    echo "2. 邮箱账户是否可以发送邮件"
    echo "3. iPhone 邮件推送是否开启"
else
    echo "✗ 邮件发送失败"
    echo ""
    echo "请确保："
    echo "1. 打开 Mail.app 并配置至少一个邮箱账户"
    echo "2. 邮箱账户状态正常（可以发送邮件）"
fi
