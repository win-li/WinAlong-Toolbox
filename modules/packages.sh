#!/usr/bin/env bash
set -Eeuo pipefail

wat_packages_supported() {
    wat_detect_system
    [[ $WAT_OS_ID == 'ubuntu' || $WAT_OS_ID == 'debian' ]]
}

wat_packages_show_updates() {
    wat_ui_title '软件包更新检查'
    if ! wat_packages_supported; then
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    fi
    if ! wat_command_exists apt-get || ! wat_command_exists apt; then
        wat_ui_error '未找到 apt/apt-get。'
        return 1
    fi

    wat_ui_info '正在刷新软件包索引，此操作需要 root 权限。'
    wat_require_root || return 1
    apt-get update
    printf '\n%s\n' '可升级软件包：'
    apt list --upgradable 2>/dev/null || true
    wat_log INFO '刷新软件包索引并列出可升级软件包'
}

wat_packages_upgrade() {
    wat_ui_title '安装软件包更新'
    if ! wat_packages_supported; then
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    fi
    wat_require_root || return 1
    wat_ui_warn '此操作会更新已安装的软件包，但不会执行发行版升级。'
    if ! wat_confirm '确定刷新索引并安装常规更新吗？'; then
        wat_ui_info '操作已取消。'
        wat_log INFO '用户取消软件包更新'
        return 0
    fi

    wat_log INFO '开始安装软件包更新'
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    wat_log INFO '软件包更新完成'
    wat_ui_success '软件包更新完成。若更新了内核，请择机重启服务器。'
}
