#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
APPS_MODULE="${PROJECT_DIR}/modules/apps.sh"
APPS_CONFIG="${PROJECT_DIR}/config/apps.conf"

required_functions=(
    wat_apps_select wat_apps_config_valid wat_apps_status_all wat_apps_deploy
    wat_apps_action wat_apps_logs wat_apps_access_info wat_apps_network_ensure
    wat_apps_network_connect_existing wat_apps_network_status wat_apps_menu
)

for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$APPS_MODULE"; then
        printf '应用中心缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq 'docker[[:space:]]+(rm|volume[[:space:]]+rm|system[[:space:]]+prune)' "$APPS_MODULE"; then
    printf '应用中心包含未授权的数据删除操作。\n' >&2
    exit 1
fi
if ! grep -Eq '^WAT_APPS_BIND="127\.0\.0\.1"$' "$APPS_CONFIG"; then
    printf '应用中心默认绑定地址不是 127.0.0.1。\n' >&2
    exit 1
fi
if ! grep -Eq '^WAT_APPS_NETWORK="winalong_apps"$' "$APPS_CONFIG"; then
    printf '应用中心默认网络名称不符合预期。\n' >&2
    exit 1
fi
if grep -Eq '0\.0\.0\.0|--network[=[:space:]]+host' "$APPS_MODULE" "$APPS_CONFIG"; then
    printf '应用中心包含公开绑定或 host 网络模式。\n' >&2
    exit 1
fi

printf '应用中心静态安全测试通过。\n'
