#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=config/default.conf
. "${SOURCE_DIR}/config/default.conf"
# shellcheck source=lib/common.sh
. "${SOURCE_DIR}/lib/common.sh"

wat_require_root

# Remove only systemd units owned by this project. Runtime logs and backups remain.
if wat_command_exists systemctl; then
    systemctl disable --now winalong-backup.timer 2>/dev/null || true
fi
rm -f -- /etc/systemd/system/winalong-backup.timer \
    /etc/systemd/system/winalong-backup.service
if wat_command_exists systemctl; then
    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed winalong-backup.service 2>/dev/null || true
fi

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
printf '管理员插件目录已保留：%s\n' "${WAT_PLUGIN_DIR:-/etc/winalong-toolbox/plugins}"
