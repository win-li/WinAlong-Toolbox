#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
required_files=(
    README.md CHANGELOG.md .gitignore .gitattributes toolbox.sh install.sh uninstall.sh
    lib/common.sh lib/ui.sh modules/system.sh modules/packages.sh modules/time.sh
    modules/swap.sh config/default.conf
    logs/.gitkeep backup/.gitkeep docs/architecture.md tests/smoke.sh
)

failures=0
for file in "${required_files[@]}"; do
    if [[ ! -e ${PROJECT_DIR}/${file} ]]; then
        printf '缺少关键文件：%s\n' "$file" >&2
        failures=$((failures + 1))
    fi
done

while IFS= read -r -d '' script; do
    printf 'bash -n: %s\n' "${script#"${PROJECT_DIR}"/}"
    if ! bash -n "$script"; then
        failures=$((failures + 1))
    fi
done < <(find "$PROJECT_DIR" -type f -name '*.sh' -print0)

if command -v shellcheck >/dev/null 2>&1; then
    mapfile -d '' scripts < <(find "$PROJECT_DIR" -type f -name '*.sh' -print0)
    printf 'shellcheck: %s 个脚本\n' "${#scripts[@]}"
    if ! shellcheck -x "${scripts[@]}"; then
        failures=$((failures + 1))
    fi
else
    printf 'shellcheck: 未安装，跳过。\n'
fi

if ((failures > 0)); then
    printf '烟雾测试失败：%d 项。\n' "$failures" >&2
    exit 1
fi

printf '烟雾测试通过。\n'
