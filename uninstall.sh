#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=config/default.conf
. "${SOURCE_DIR}/config/default.conf"
# shellcheck source=lib/common.sh
. "${SOURCE_DIR}/lib/common.sh"

wat_require_root

if [[ -L $WAT_BIN_LINK ]]; then
    link_target=$(readlink "$WAT_BIN_LINK")
    if [[ $link_target == "$WAT_INSTALL_DIR/toolbox.sh" ]]; then
        rm -- "$WAT_BIN_LINK"
    else
        printf '跳过非本项目软链接：%s -> %s\n' "$WAT_BIN_LINK" "$link_target" >&2
    fi
fi

if [[ -d $WAT_INSTALL_DIR ]]; then
    rm -rf -- "$WAT_INSTALL_DIR"
fi

printf 'WinAlong Toolbox 已卸载。\n'
printf '日志和备份已保留：%s，%s\n' "$WAT_LOG_DIR" "$WAT_BACKUP_DIR"
