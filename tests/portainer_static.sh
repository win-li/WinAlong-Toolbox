#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PORTAINER_MODULE="${PROJECT_DIR}/modules/portainer.sh"

required_functions=(
    wat_portainer_config_valid wat_portainer_status wat_portainer_install wat_portainer_action
    wat_portainer_logs wat_portainer_access_info wat_portainer_menu
)

for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$PORTAINER_MODULE"; then
        printf 'Portainer 模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq 'docker[[:space:]]+(rm|volume[[:space:]]+rm|system[[:space:]]+prune)' "$PORTAINER_MODULE"; then
    printf 'Portainer 模块包含未授权的数据删除操作。\n' >&2
    exit 1
fi

if ! grep -Eq '^WAT_PORTAINER_BIND="127\.0\.0\.1"$' "${PROJECT_DIR}/config/default.conf"; then
    printf 'Portainer 默认绑定地址不是 127.0.0.1。\n' >&2
    exit 1
fi
if grep -Eq -- '-p[[:space:]]+(0\.0\.0\.0:)?9443:9443|-p[[:space:]]+9443:9443' "$PORTAINER_MODULE"; then
    printf 'Portainer 管理端口可能被公开绑定。\n' >&2
    exit 1
fi
if grep -Eq -- '(-p|--publish)[[:space:]]+8000' "$PORTAINER_MODULE"; then
    printf 'Portainer Edge 端口 8000 不应在 v0.4.0 中启用。\n' >&2
    exit 1
fi

printf 'Portainer 静态安全测试通过。\n'
