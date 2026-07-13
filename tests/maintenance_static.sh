#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGES_MODULE="${PROJECT_DIR}/modules/packages.sh"

required_functions=(
    wat_packages_upgradable_count wat_packages_kept_back
    wat_packages_latest_installed_kernel wat_packages_maintenance_status
)
for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$PACKAGES_MODULE"; then
        printf '维护状态模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if ! grep -Fq 'apt-get -s upgrade' "$PACKAGES_MODULE"; then
    printf '暂缓软件包检测未使用 APT 模拟模式。\n' >&2
    exit 1
fi
if ! grep -Fq '/var/run/reboot-required' "$PACKAGES_MODULE"; then
    printf '维护状态缺少重启要求检测。\n' >&2
    exit 1
fi
if grep -Eq 'apt(-get)?[[:space:]]+(full-upgrade|dist-upgrade)|^[[:space:]]*(reboot|shutdown)[[:space:]]' "$PACKAGES_MODULE"; then
    printf '维护状态模块包含禁止的升级或重启操作。\n' >&2
    exit 1
fi

printf '更新后维护状态静态安全测试通过。\n'
