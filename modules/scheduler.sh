#!/usr/bin/env bash
set -Eeuo pipefail

wat_scheduler_service_path() {
    printf '/etc/systemd/system/%s' "$WAT_BACKUP_SERVICE"
}

wat_scheduler_timer_path() {
    printf '/etc/systemd/system/%s' "$WAT_BACKUP_TIMER"
}

wat_scheduler_validate() {
    [[ $WAT_BACKUP_SERVICE == 'winalong-backup.service' ]] || return 1
    [[ $WAT_BACKUP_TIMER == 'winalong-backup.timer' ]] || return 1
    [[ $WAT_BIN_LINK == '/usr/local/bin/winalong' ]] || return 1
    [[ $WAT_BACKUP_CALENDAR != *$'\n'* && $WAT_BACKUP_CALENDAR != *$'\r'* ]] || return 1
    systemd-analyze calendar "$WAT_BACKUP_CALENDAR" >/dev/null 2>&1
}

wat_scheduler_status() {
    wat_ui_title '自动备份计划状态'
    wat_command_exists systemctl || { wat_ui_error '未找到 systemctl。'; return 1; }
    wat_scheduler_validate || { wat_ui_error '自动备份计划配置无效。'; return 1; }
    printf '计划：%s\n' "$WAT_BACKUP_CALENDAR"
    printf 'Timer 启用：%s\n' "$(systemctl is-enabled "$WAT_BACKUP_TIMER" 2>/dev/null || printf '未启用')"
    printf 'Timer 运行：%s\n\n' "$(systemctl is-active "$WAT_BACKUP_TIMER" 2>/dev/null || printf '未运行')"
    systemctl list-timers "$WAT_BACKUP_TIMER" --no-pager 2>/dev/null || true
    printf '\n最近执行结果：\n'
    systemctl show "$WAT_BACKUP_SERVICE" \
        --property=Result,ExecMainStatus,ExecMainStartTimestamp,ExecMainExitTimestamp \
        --no-pager 2>/dev/null || wat_ui_info '尚无执行记录。'
}

wat_scheduler_enable() {
    local answer service_tmp timer_tmp
    wat_ui_title '启用自动备份计划'
    wat_require_root || return 1
    wat_command_exists systemctl || { wat_ui_error '未找到 systemctl。'; return 1; }
    wat_apps_require_docker || return 1
    wat_scheduler_validate || { wat_ui_error '自动备份计划配置无效。'; return 1; }
    wat_ui_warn "将按 ${WAT_BACKUP_CALENDAR} 自动备份已部署的 Nginx 和 Uptime Kuma。"
    wat_ui_warn '不会自动删除任何历史备份。'
    read -r -p '请输入 ENABLE 确认启用自动备份：' answer
    if [[ $answer != 'ENABLE' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        return 0
    fi

    service_tmp=$(mktemp)
    timer_tmp=$(mktemp)
    if ! cat >"$service_tmp" <<EOF
[Unit]
Description=WinAlong Toolbox application backup
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=${WAT_BIN_LINK} --backup-run
User=root
Group=root
UMask=0077
EOF
    then
        rm -f -- "$service_tmp" "$timer_tmp"
        wat_ui_error '无法生成自动备份 Service。'
        return 1
    fi
    if ! cat >"$timer_tmp" <<EOF
[Unit]
Description=WinAlong Toolbox daily application backup

[Timer]
OnCalendar=${WAT_BACKUP_CALENDAR}
Persistent=true
RandomizedDelaySec=10m
Unit=${WAT_BACKUP_SERVICE}

[Install]
WantedBy=timers.target
EOF
    then
        rm -f -- "$service_tmp" "$timer_tmp"
        wat_ui_error '无法生成自动备份 Timer。'
        return 1
    fi
    if ! install -o root -g root -m 0644 "$service_tmp" "$(wat_scheduler_service_path)" || \
        ! install -o root -g root -m 0644 "$timer_tmp" "$(wat_scheduler_timer_path)"; then
        rm -f -- "$service_tmp" "$timer_tmp"
        rm -f -- "$(wat_scheduler_service_path)" "$(wat_scheduler_timer_path)"
        wat_ui_error '无法安装自动备份 systemd 单元。'
        return 1
    fi
    rm -f -- "$service_tmp" "$timer_tmp"
    if ! systemctl daemon-reload || ! systemctl enable --now "$WAT_BACKUP_TIMER"; then
        systemctl disable --now "$WAT_BACKUP_TIMER" 2>/dev/null || true
        rm -f -- "$(wat_scheduler_service_path)" "$(wat_scheduler_timer_path)"
        systemctl daemon-reload 2>/dev/null || true
        wat_ui_error '启用自动备份计划失败，已回滚 systemd 单元。'
        return 1
    fi
    wat_log INFO "已启用自动备份计划：${WAT_BACKUP_CALENDAR}"
    wat_ui_success '自动备份计划已启用。'
}

wat_scheduler_disable() {
    local answer service_path timer_path
    wat_ui_title '停用自动备份计划'
    wat_require_root || return 1
    wat_command_exists systemctl || { wat_ui_error '未找到 systemctl。'; return 1; }
    wat_scheduler_validate || { wat_ui_error '自动备份计划配置无效。'; return 1; }
    wat_ui_warn '停用计划不会删除已有备份。'
    read -r -p '请输入 DISABLE 确认停用自动备份：' answer
    if [[ $answer != 'DISABLE' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        return 0
    fi
    service_path=$(wat_scheduler_service_path)
    timer_path=$(wat_scheduler_timer_path)
    systemctl disable --now "$WAT_BACKUP_TIMER" 2>/dev/null || true
    rm -f -- "$service_path" "$timer_path"
    systemctl daemon-reload
    systemctl reset-failed "$WAT_BACKUP_SERVICE" 2>/dev/null || true
    wat_log INFO '已停用自动备份计划'
    wat_ui_success '自动备份计划已停用，已有备份保持不变。'
}

wat_scheduler_menu() {
    local choice
    while true; do
        wat_ui_title '自动备份计划'
        wat_ui_menu \
            '1. 查看计划状态' \
            '2. 启用计划' \
            '3. 立即运行备份任务' \
            '4. 停用计划' \
            '0. 返回'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_scheduler_status; wat_pause ;;
            2) wat_scheduler_enable || true; wat_pause ;;
            3) wat_backup_run_all || true; wat_pause ;;
            4) wat_scheduler_disable || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
