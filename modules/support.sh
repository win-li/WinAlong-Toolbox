#!/usr/bin/env bash
set -Eeuo pipefail

wat_support_bundle_create() {
    local temp archive report
    wat_ui_title '生成脱敏支持包'
    wat_require_root || return 1
    install -o root -g root -m 0700 -d "$WAT_REPORT_DIR"
    wat_report_generate || return 1
    report=$WAT_LAST_REPORT_PATH
    temp=$(mktemp -d)
    install -m 0600 -- "$report" "$temp/diagnostic-report.txt"
    wat_storage_health_summary >"$temp/backup-health.txt" || true
    {
        printf 'WinAlong Toolbox 脱敏支持包\n'
        printf '版本=%s\n' "$WAT_VERSION"
        printf '生成时间=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        printf '%s\n' '内容=diagnostic-report.txt,backup-health.txt,SHA256SUMS'
        printf '%s\n' '排除=原始日志,主机名,IP,MAC,环境变量,SSH配置,密钥,本地覆盖配置,Docker详情'
    } >"$temp/manifest.txt"
    (cd "$temp" && sha256sum diagnostic-report.txt backup-health.txt manifest.txt) >"$temp/SHA256SUMS"
    archive="${WAT_REPORT_DIR}/support-$(date '+%Y%m%d-%H%M%S')-$$.tar.gz"
    umask 077
    if ! tar -czf "$archive" -C "$temp" diagnostic-report.txt backup-health.txt manifest.txt SHA256SUMS; then
        rm -rf -- "${temp:?}"
        wat_ui_error '创建脱敏支持包失败。'
        return 1
    fi
    if ! tar -tzf "$archive" >/dev/null; then
        rm -f -- "$archive"
        rm -rf -- "${temp:?}"
        wat_ui_error '脱敏支持包完整性校验失败。'
        return 1
    fi
    chmod 0600 "$archive"
    rm -rf -- "${temp:?}"
    WAT_LAST_SUPPORT_BUNDLE=$archive
    export WAT_LAST_SUPPORT_BUNDLE
    wat_log INFO "脱敏支持包已生成：${archive}"
    wat_ui_success "支持包已生成：${archive}"
    wat_ui_warn '分享前仍应解压并人工检查内容。'
}
