#!/usr/bin/env bash
set -Eeuo pipefail

readonly WAT_BOOTSTRAP_REPO="${WAT_BOOTSTRAP_REPO:-https://github.com/win-li/WinAlong-Toolbox.git}"
readonly WAT_BOOTSTRAP_REF="${WAT_BOOTSTRAP_REF:-main}"
WAT_BOOTSTRAP_TEMP_DIR=''

wat_bootstrap_cleanup() {
    if [[ -n $WAT_BOOTSTRAP_TEMP_DIR && -d $WAT_BOOTSTRAP_TEMP_DIR ]]; then
        rm -rf -- "$WAT_BOOTSTRAP_TEMP_DIR"
    fi
}

trap wat_bootstrap_cleanup EXIT

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    printf '请使用 root 权限运行，例如：curl -fsSL URL | sudo bash\n' >&2
    exit 1
fi

for command_name in git bash; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '缺少必要命令：%s\n' "$command_name" >&2
        exit 1
    fi
done

if [[ $WAT_BOOTSTRAP_REPO != https://github.com/* ]]; then
    printf '引导安装仅允许使用 GitHub HTTPS 仓库。\n' >&2
    exit 1
fi

WAT_BOOTSTRAP_TEMP_DIR=$(mktemp -d)
printf '正在通过 HTTPS 获取 WinAlong Toolbox（%s）...\n' "$WAT_BOOTSTRAP_REF"
git clone --quiet --depth 1 --branch "$WAT_BOOTSTRAP_REF" -- \
    "$WAT_BOOTSTRAP_REPO" "$WAT_BOOTSTRAP_TEMP_DIR/repo"

cd "$WAT_BOOTSTRAP_TEMP_DIR/repo"
printf '正在执行完整烟雾测试...\n'
bash tests/smoke.sh
printf '测试通过，开始安装...\n'
bash install.sh
printf '安装完成。请运行：winalong\n'
