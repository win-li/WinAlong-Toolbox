#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SECURITY_MODULE="${PROJECT_DIR}/modules/security.sh"

required_functions=(
    wat_security_ssh_port wat_security_overview wat_security_listening_ports
    wat_security_ufw_status wat_security_ufw_install wat_security_ufw_enable
    wat_security_fail2ban_status wat_security_fail2ban_install wat_security_menu
)

for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$SECURITY_MODULE"; then
        printf '安全模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq 'ufw[[:space:]]+(disable|reset)|ufw[[:space:]]+allow[[:space:]]+[0-9]' "$SECURITY_MODULE"; then
    printf '安全模块包含 UFW 禁用、重置或硬编码开放端口。\n' >&2
    exit 1
fi
if grep -Eq '(/etc/ssh/sshd_config|PermitRootLogin|PasswordAuthentication).*([>]|sed[[:space:]]+-i)' "$SECURITY_MODULE"; then
    printf '安全模块包含未授权的 SSH 配置修改。\n' >&2
    exit 1
fi
if ! grep -Fq '请输入 ENABLE 确认启用 UFW' "$SECURITY_MODULE"; then
    printf 'UFW 启用缺少 ENABLE 确认短语。\n' >&2
    exit 1
fi

printf '安全中心静态安全测试通过。\n'
