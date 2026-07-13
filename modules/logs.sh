#!/usr/bin/env bash
set -Eeuo pipefail

wat_logs_validate_limit() {
    [[ $WAT_LOG_TAIL_LINES =~ ^[0-9]+$ ]] && \
        ((WAT_LOG_TAIL_LINES >= 10 && WAT_LOG_TAIL_LINES <= 500))
}

wat_logs_toolbox() {
    wat_ui_title 'WinAlong 运行日志'
    wat_logs_validate_limit || { wat_ui_error '日志行数配置无效。'; return 1; }
    [[ -r ${WAT_LOG_FILE:-} ]] || { wat_ui_info '当前没有可读取的运行日志。'; return 0; }
    wat_ui_warn '日志可能包含操作路径或服务名称，分享前请人工检查。'
    tail -n "$WAT_LOG_TAIL_LINES" -- "$WAT_LOG_FILE"
}

wat_logs_recent_errors() {
    local matches
    wat_ui_title '最近错误与警告'
    wat_logs_validate_limit || { wat_ui_error '日志行数配置无效。'; return 1; }
    [[ -r ${WAT_LOG_FILE:-} ]] || { wat_ui_info '当前没有可读取的运行日志。'; return 0; }
    matches=$(tail -n 1000 -- "$WAT_LOG_FILE" | \
        grep -Ei '\[(ERROR|WARN|WARNING)\]|失败|错误|警告' || true)
    if [[ -z $matches ]]; then
        wat_ui_success '最近日志中未发现错误或警告。'
        return 0
    fi
    printf '%s\n' "$matches" | tail -n "$WAT_LOG_TAIL_LINES"
}

wat_logs_container_name() {
    case $1 in
        1) printf '%s' "$WAT_NGINX_CONTAINER" ;;
        2) printf '%s' "$WAT_UPTIME_CONTAINER" ;;
        3) printf '%s' "$WAT_PORTAINER_CONTAINER" ;;
        *) return 1 ;;
    esac
}

wat_logs_container() {
    local choice container
    wat_ui_title '查看容器日志'
    wat_logs_validate_limit || { wat_ui_error '日志行数配置无效。'; return 1; }
    wat_apps_require_docker || return 1
    wat_ui_menu \
        '1. Nginx' \
        '2. Uptime Kuma' \
        '3. Portainer' \
        '0. 返回'
    read -r -p '请输入菜单编号：' choice
    [[ $choice == '0' ]] && return 0
    container=$(wat_logs_container_name "$choice") || {
        wat_ui_error '无效容器选项。'
        return 1
    }
    if ! docker container inspect "$container" >/dev/null 2>&1; then
        wat_ui_error "容器不存在：${container}"
        return 1
    fi
    wat_ui_warn '容器日志可能包含访问地址或应用数据，分享前请人工检查。'
    docker logs --tail "$WAT_LOG_TAIL_LINES" -- "$container" 2>&1
}

wat_logs_latest_report() {
    local report
    wat_ui_title '最新诊断报告'
    report=$(find "$WAT_REPORT_DIR" -maxdepth 1 -type f -name 'report-*.txt' \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)
    if [[ -z $report || ! -r $report ]]; then
        wat_ui_info '没有可读取的诊断报告。'
        return 0
    fi
    printf '文件：%s\n\n' "$report"
    cat -- "$report"
}

wat_logs_menu() {
    local choice
    while true; do
        wat_ui_title '日志与诊断'
        wat_ui_menu \
            '1. 查看 WinAlong 日志' \
            '2. 查看最近错误与警告' \
            '3. 查看容器日志' \
            '4. 生成脱敏诊断报告' \
            '5. 查看最新诊断报告' \
            '6. 自动备份计划' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_logs_toolbox || true; wat_pause ;;
            2) wat_logs_recent_errors || true; wat_pause ;;
            3) wat_logs_container || true; wat_pause ;;
            4) wat_report_generate || true; wat_pause ;;
            5) wat_logs_latest_report || true; wat_pause ;;
            6) wat_scheduler_menu ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
