#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BOOTSTRAP_SCRIPT="${PROJECT_DIR}/bootstrap.sh"

for file in LICENSE SECURITY.md CONTRIBUTING.md docs/public-release.md bootstrap.sh; do
    if [[ ! -f ${PROJECT_DIR}/${file} ]]; then
        printf '公开发布缺少文件：%s\n' "$file" >&2
        exit 1
    fi
done

if ! grep -Fq 'https://github.com/win-li/WinAlong-Toolbox.git' "$BOOTSTRAP_SCRIPT"; then
    printf '引导安装未使用 GitHub HTTPS 仓库。\n' >&2
    exit 1
fi
if ! grep -Fq 'bash tests/smoke.sh' "$BOOTSTRAP_SCRIPT"; then
    printf '引导安装没有在安装前运行完整烟雾测试。\n' >&2
    exit 1
fi
if ! grep -Fq 'bash install.sh' "$BOOTSTRAP_SCRIPT"; then
    printf '引导安装没有调用项目安装器。\n' >&2
    exit 1
fi
if grep -Eq 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' \
    "${PROJECT_DIR}/modules/update.sh"; then
    printf '在线更新模块不得执行远程管道脚本。\n' >&2
    exit 1
fi
if ! grep -Fq '*.key' "${PROJECT_DIR}/.gitignore" || \
    ! grep -Fq '.env.*' "${PROJECT_DIR}/.gitignore"; then
    printf '.gitignore 缺少密钥或环境文件保护。\n' >&2
    exit 1
fi

printf '公开发布静态安全测试通过。\n'
