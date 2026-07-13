#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
UPDATE_MODULE="${PROJECT_DIR}/modules/update.sh"

required_functions=(
    wat_update_repo_uses_ssh wat_update_stage wat_update_check wat_update_rollback
    wat_update_apply wat_update_menu
)
for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$UPDATE_MODULE"; then
        printf '更新模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$UPDATE_MODULE"; then
    printf '更新模块包含远程脚本管道执行。\n' >&2
    exit 1
fi
if ! grep -Fq '请输入 UPDATE 确认更新' "$UPDATE_MODULE"; then
    printf '更新操作缺少 UPDATE 确认短语。\n' >&2
    exit 1
fi
if ! grep -Fq "WAT_INSTALL_DIR != '/opt/winalong-toolbox'" "$UPDATE_MODULE"; then
    printf '更新或回滚缺少固定安装目录保护。\n' >&2
    exit 1
fi
if ! grep -Fq 'tests/smoke.sh' "$UPDATE_MODULE"; then
    printf '更新前未运行远程版本烟雾测试。\n' >&2
    exit 1
fi

if ! grep -Fq 'wat_update_repo_uses_ssh &&' "$UPDATE_MODULE"; then
    printf 'SSH 密钥选择没有按仓库协议进行条件限制。\n' >&2
    exit 1
fi

if ! grep -Fq 'WAT_UPDATE_REPO="https://github.com/win-li/WinAlong-Toolbox.git"' \
    "${PROJECT_DIR}/config/update.conf"; then
    printf '默认更新仓库不是公开 GitHub HTTPS 地址。\n' >&2
    exit 1
fi

printf '在线更新静态安全测试通过。\n'
