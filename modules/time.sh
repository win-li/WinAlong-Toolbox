#!/usr/bin/env bash
set -Eeuo pipefail

wat_time_status() {
    wat_ui_title '时间同步状态'
    if ! wat_command_exists timedatectl; then
        wat_ui_error '当前系统没有 timedatectl。'
        return 1
    fi
    timedatectl status
    wat_log INFO '查看时间同步状态'
}

wat_time_enable_sync() {
    wat_ui_title '启用时间同步'
    wat_require_root || return 1
    if ! wat_command_exists timedatectl; then
        wat_ui_error '当前系统没有 timedatectl。'
        return 1
    fi
    if ! wat_confirm '确定启用系统 NTP 自动同步吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    timedatectl set-ntp true
    wat_log INFO '已启用系统 NTP 自动同步'
    wat_ui_success '时间同步已启用。'
    timedatectl status
}
