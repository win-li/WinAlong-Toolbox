#!/usr/bin/env bash
set -Eeuo pipefail

wat_system_info() {
    wat_detect_system
    wat_ui_title '系统信息'
    printf '系统：%s\n' "$WAT_OS_NAME"
    printf '内核：%s\n' "$(uname -sr)"
    printf '架构：%s\n' "$(uname -m)"
    printf '主机名：%s\n\n' "$(hostname)"
    printf '%s\n' '内存：'
    free -h
    printf '\n%s\n' '磁盘：'
    df -h / 
    wat_log INFO '查看系统信息'
}

wat_system_bbr_status() {
    local congestion='unknown'
    local available='unknown'
    wat_ui_title 'BBR 状态'

    if wat_command_exists sysctl; then
        congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')
        available=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || printf 'unknown')
    fi

    printf '当前拥塞控制：%s\n' "$congestion"
    printf '可用拥塞控制：%s\n' "$available"
    if [[ $congestion == 'bbr' ]]; then
        wat_ui_success 'BBR 已启用。'
    elif [[ $available == *bbr* ]]; then
        wat_ui_info '系统支持 BBR，但当前未启用。'
    else
        wat_ui_info '未检测到可用的 BBR。'
    fi
    wat_log INFO "查看 BBR 状态：${congestion}"
}

wat_system_swap_status() {
    wat_ui_title 'Swap 状态'
    if wat_command_exists swapon; then
        swapon --show || true
    else
        wat_ui_warn '未找到 swapon 命令。'
    fi
    printf '\n'
    free -h
    wat_log INFO '查看 Swap 状态'
}

wat_system_menu() {
    local choice
    while true; do
        wat_ui_title '系统检查'
        wat_ui_menu \
            '1. 查看系统信息' \
            '2. 查看 BBR 状态' \
            '3. 查看 Swap 状态' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_system_info; wat_pause ;;
            2) wat_system_bbr_status; wat_pause ;;
            3) wat_system_swap_status; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
