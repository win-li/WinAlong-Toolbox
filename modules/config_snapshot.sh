#!/usr/bin/env bash
set -Eeuo pipefail

wat_config_snapshot_create() {
    local temp archive path destination
    local -a paths=(
        /etc/sysctl.d/99-winalong-bbr.conf
        /etc/fail2ban/jail.d/winalong-sshd.local
        /etc/systemd/system/winalong-backup.service
        /etc/systemd/system/winalong-backup.timer
        "${WAT_INSTALL_DIR}/config/default.conf"
        "${WAT_INSTALL_DIR}/config/apps.conf"
        "${WAT_INSTALL_DIR}/config/security.conf"
        "${WAT_INSTALL_DIR}/config/network.conf"
        "${WAT_INSTALL_DIR}/config/update.conf"
        "${WAT_INSTALL_DIR}/config/doctor.conf"
        "${WAT_INSTALL_DIR}/config/maintenance.conf"
        "${WAT_INSTALL_DIR}/config/storage.conf"
    )
    wat_ui_title '创建托管配置快照'
    wat_require_root || return 1
    [[ $WAT_CONFIG_SNAPSHOT_DIR == "${WAT_BACKUP_DIR}/config" ]] || {
        wat_ui_error '配置快照目录必须位于 WinAlong 备份目录。'
        return 1
    }
    install -o root -g root -m 0700 -d "$WAT_CONFIG_SNAPSHOT_DIR"
    temp=$(mktemp -d)
    install -m 0700 -d "$temp/files"
    printf 'WinAlong Toolbox 托管配置快照\n版本=%s\n生成时间=%s\n' \
        "$WAT_VERSION" "$(date '+%Y-%m-%d %H:%M:%S %Z')" >"$temp/manifest.txt"
    for path in "${paths[@]}"; do
        [[ -f $path && ! -L $path ]] || continue
        destination="${temp}/files${path}"
        install -D -m 0600 -- "$path" "$destination"
        printf '文件=%s\n' "$path" >>"$temp/manifest.txt"
    done
    (cd "$temp" && find files -type f -print0 | sort -z | xargs -0 -r sha256sum) >"$temp/SHA256SUMS"
    archive="${WAT_CONFIG_SNAPSHOT_DIR}/config-$(date '+%Y%m%d-%H%M%S')-$$.tar.gz"
    umask 077
    if ! tar -czf "$archive" -C "$temp" manifest.txt SHA256SUMS files; then
        rm -rf -- "${temp:?}"
        wat_ui_error '创建配置快照失败。'
        return 1
    fi
    if ! tar -tzf "$archive" >/dev/null; then
        rm -f -- "$archive"
        rm -rf -- "${temp:?}"
        wat_ui_error '配置快照完整性校验失败。'
        return 1
    fi
    chmod 0600 "$archive"
    rm -rf -- "${temp:?}"
    WAT_LAST_CONFIG_SNAPSHOT=$archive
    export WAT_LAST_CONFIG_SNAPSHOT
    wat_log INFO "托管配置快照已生成：${archive}"
    wat_ui_success "配置快照已生成：${archive}"
    wat_ui_info '快照仅包含固定允许清单；不包含本地覆盖配置、密钥、SSH、UFW 规则、插件或日志。'
}
