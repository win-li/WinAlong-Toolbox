#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
required_files=(
    README.md CHANGELOG.md .gitignore .gitattributes toolbox.sh install.sh uninstall.sh
    lib/common.sh lib/ui.sh modules/system.sh modules/packages.sh modules/time.sh
    modules/swap.sh modules/docker.sh modules/portainer.sh modules/apps.sh modules/backup.sh
    modules/security.sh modules/network.sh modules/update.sh modules/plugins.sh modules/doctor.sh
    config/default.conf config/apps.conf config/security.conf config/network.conf config/update.conf
    config/doctor.conf
    logs/.gitkeep backup/.gitkeep docs/architecture.md tests/smoke.sh
    tests/docker_static.sh tests/portainer_static.sh tests/apps_static.sh
    tests/backup_static.sh tests/security_static.sh tests/network_static.sh
    tests/update_static.sh tests/plugins_static.sh tests/doctor_static.sh tests/maintenance_static.sh
    update.sh plugins/system-summary.plugin.sh docs/release.md
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

if ! bash "${PROJECT_DIR}/tests/docker_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/portainer_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/apps_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/backup_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/security_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/network_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/update_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/plugins_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/doctor_static.sh"; then
    failures=$((failures + 1))
fi
if ! bash "${PROJECT_DIR}/tests/maintenance_static.sh"; then
    failures=$((failures + 1))
fi

expected_version=$(awk -F'"' '$1 == "WAT_VERSION=" {print $2; exit}' \
    "${PROJECT_DIR}/config/default.conf")
if [[ $(bash "${PROJECT_DIR}/toolbox.sh" --version) != "$expected_version" ]]; then
    printf '命令行版本输出与默认配置不一致。\n' >&2
    failures=$((failures + 1))
fi
help_output=$(bash "${PROJECT_DIR}/toolbox.sh" --help)
if [[ $help_output != *'--doctor'* ]]; then
    printf '命令行帮助缺少健康体检入口。\n' >&2
    failures=$((failures + 1))
fi
if [[ $help_output != *'--maintenance'* ]]; then
    printf '命令行帮助缺少更新后维护状态入口。\n' >&2
    failures=$((failures + 1))
fi

if command -v shellcheck >/dev/null 2>&1; then
    mapfile -d '' scripts < <(find "$PROJECT_DIR" -type f -name '*.sh' -print0)
    printf 'shellcheck: %s 个脚本\n' "${#scripts[@]}"
    # ShellCheck resolves source= directives from its working directory.
    # Always lint from the project root so this test works from any caller cwd.
    if ! (cd "$PROJECT_DIR" && shellcheck -x "${scripts[@]}"); then
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
