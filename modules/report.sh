#!/usr/bin/env bash
set -Eeuo pipefail

wat_report_package_counts() {
    local upgradable held
    upgradable=$(apt list --upgradable 2>/dev/null | awk 'NR > 1 {count++} END {print count+0}')
    held=$(apt-mark showhold 2>/dev/null | awk 'NF {count++} END {print count+0}')
    printf '可升级软件包：%s\n暂缓软件包：%s\n' "$upgradable" "$held"
}

wat_report_docker_status() {
    if ! wat_command_exists docker; then
        printf 'Docker：未安装\n'
        return 0
    fi
    if ! docker info >/dev/null 2>&1; then
        printf 'Docker：已安装但服务不可用\n'
        return 0
    fi
    printf 'Docker：运行中\n'
    docker ps --format '容器={{.Names}} 状态={{.Status}}'
}

wat_report_security_status() {
    if wat_command_exists ufw; then
        printf 'UFW：%s\n' "$(ufw status 2>/dev/null | awk 'NR == 1 {print $2}')"
    else
        printf 'UFW：未安装\n'
    fi
    if wat_command_exists fail2ban-client && fail2ban-client ping >/dev/null 2>&1; then
        printf 'Fail2ban：运行中\n'
    else
        printf 'Fail2ban：未运行\n'
    fi
    printf '拥塞控制：%s\n' "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')"
    printf '队列算法：%s\n' "$(sysctl -n net.core.default_qdisc 2>/dev/null || printf 'unknown')"
}

wat_report_failed_units() {
    local failed_count
    failed_count=$(systemctl --failed --no-legend 2>/dev/null | awk 'NF {count++} END {print count+0}')
    printf '失败的 systemd 单元：%s\n' "$failed_count"
}

wat_report_log_summary() {
    local errors=0 warnings=0
    if [[ -r ${WAT_LOG_FILE:-} ]]; then
        errors=$(grep -Ec '\[ERROR\]|失败|错误' "$WAT_LOG_FILE" || true)
        warnings=$(grep -Ec '\[WARN|警告' "$WAT_LOG_FILE" || true)
    fi
    printf 'WinAlong 错误记录数：%s\nWinAlong 警告记录数：%s\n' "$errors" "$warnings"
}

wat_report_generate() {
    local report_file
    wat_ui_title '生成脱敏诊断报告'
    wat_require_root || return 1
    wat_detect_system
    install -o root -g root -m 0700 -d "$WAT_REPORT_DIR"
    report_file="${WAT_REPORT_DIR}/report-$(date '+%Y%m%d-%H%M%S')-$$.txt"
    if ! (
        local temp_file
        temp_file=$(mktemp)
        trap 'rm -f -- "$temp_file"' EXIT
        umask 077
        {
        printf 'WinAlong Toolbox 脱敏诊断报告\n'
        printf '生成时间：%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        printf '工具版本：%s\n' "$WAT_VERSION"
        printf '系统：%s\n内核：%s\n架构：%s\n' "$WAT_OS_NAME" "$(uname -r)" "$(uname -m)"
        printf '运行时间：%s\n\n' "$(uptime -p 2>/dev/null || printf 'unknown')"
        printf '[内存]\n'
        free -h
        printf '\n[根磁盘]\n'
        df -h /
        printf '\n[系统维护]\n'
        wat_report_package_counts
        wat_report_failed_units
        if [[ -e /var/run/reboot-required ]]; then
            printf '重启要求：需要重启\n'
        else
            printf '重启要求：当前不需要\n'
        fi
        printf '\n[安全与网络]\n'
        wat_report_security_status
        printf '\n[Docker]\n'
        wat_report_docker_status
        printf '\n[日志摘要]\n'
        wat_report_log_summary
        printf '\n说明：本报告不采集主机名、IP、MAC、环境变量、SSH 配置或原始应用日志。\n'
        } >"$temp_file"
        install -o root -g root -m 0600 "$temp_file" "$report_file"
    ); then
        wat_ui_error '生成诊断报告失败。'
        return 1
    fi
    wat_log INFO "已生成脱敏诊断报告：${report_file}"
    wat_ui_success "诊断报告已生成：${report_file}"
}
