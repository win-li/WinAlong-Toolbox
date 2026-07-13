#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
NETWORK_MODULE="${PROJECT_DIR}/modules/network.sh"

required_functions=(
    wat_network_summary wat_network_connectivity wat_network_route_test
    wat_network_install_tools wat_network_speed_test wat_network_bbr_status
    wat_network_bbr_enable wat_network_menu
)

for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$NETWORK_MODULE"; then
        printf '网络模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$NETWORK_MODULE"; then
    printf '网络模块包含远程脚本管道执行。\n' >&2
    exit 1
fi
if grep -Eq 'ip[[:space:]]+route[[:space:]]+(add|del|replace)|route[[:space:]]+(add|del)' "$NETWORK_MODULE"; then
    printf '网络诊断模块包含路由修改。\n' >&2
    exit 1
fi
if ! grep -Fq '请输入 ENABLE 确认启用 BBR' "$NETWORK_MODULE"; then
    printf 'BBR 启用缺少 ENABLE 确认短语。\n' >&2
    exit 1
fi

printf '网络诊断静态安全测试通过。\n'
