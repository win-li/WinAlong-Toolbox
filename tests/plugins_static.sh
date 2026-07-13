#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN_MODULE="${PROJECT_DIR}/modules/plugins.sh"
INSTALL_SCRIPT="${PROJECT_DIR}/install.sh"

required_functions=(
    wat_plugins_find wat_plugins_validate_file wat_plugins_list wat_plugins_run wat_plugins_menu
)
for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$PLUGIN_MODULE"; then
        printf '插件模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq '(^|[[:space:]])eval([[:space:]]|$)' "$PLUGIN_MODULE"; then
    printf '插件模块禁止使用 eval。\n' >&2
    exit 1
fi
if ! grep -Fq '请输入 RUN 确认执行插件' "$PLUGIN_MODULE"; then
    printf '插件执行缺少 RUN 确认短语。\n' >&2
    exit 1
fi
if ! grep -Fq "owner != '0'" "$PLUGIN_MODULE"; then
    printf '插件执行缺少 root 所有者检查。\n' >&2
    exit 1
fi
if ! grep -Fq 'sha256sum' "$PLUGIN_MODULE"; then
    printf '插件执行前未显示 SHA-256。\n' >&2
    exit 1
fi
if ! grep -Fq "chown -R root:root \"\$WAT_INSTALL_DIR\"" "$INSTALL_SCRIPT"; then
    printf '安装程序未确保内置插件和程序文件归 root 所有。\n' >&2
    exit 1
fi

printf '插件框架静态安全测试通过。\n'
