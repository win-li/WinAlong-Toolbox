#!/usr/bin/env bash
set -Eeuo pipefail

wat_backup_app_dir() {
    printf '%s/apps' "$WAT_BACKUP_DIR"
}

wat_backup_latest() {
    local app_id=$1
    local backup_dir
    backup_dir=$(wat_backup_app_dir)
    find "$backup_dir" -maxdepth 1 -type f -name "${app_id}-*.tar.gz" \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-
}

wat_backup_snapshot() {
    local app_id=$1
    local reason=${2:-manual}
    local backup_dir archive was_running='false'
    wat_apps_select "$app_id" || return 1
    wat_require_root || return 1
    wat_apps_require_docker || return 1
    if ! wat_apps_exists; then
        wat_ui_error "${WAT_APP_NAME} 尚未部署。"
        return 1
    fi
    if ! docker volume inspect "$WAT_APP_VOLUME" >/dev/null 2>&1; then
        wat_ui_error "数据卷不存在：${WAT_APP_VOLUME}"
        return 1
    fi

    backup_dir=$(wat_backup_app_dir)
    install -m 0700 -d "$backup_dir"
    if ! wat_storage_backup_space_ok; then
        wat_ui_error "备份磁盘可用空间低于 ${WAT_BACKUP_MIN_FREE_PERCENT}% 或无法读取，已拒绝创建新备份。"
        return 1
    fi
    archive="${app_id}-$(date '+%Y%m%d-%H%M%S')-${reason}-$$.tar.gz"
    if ! docker image inspect "$WAT_BACKUP_IMAGE" >/dev/null 2>&1; then
        docker pull "$WAT_BACKUP_IMAGE" >/dev/null
    fi
    if [[ $(docker container inspect --format '{{.State.Running}}' "$WAT_APP_CONTAINER") == 'true' ]]; then
        was_running='true'
        docker stop "$WAT_APP_CONTAINER" >/dev/null
    fi

    if ! docker run --rm \
        -v "${WAT_APP_VOLUME}:/source:ro" \
        -v "${backup_dir}:/backup" \
        "$WAT_BACKUP_IMAGE" sh -c \
        'cd /source && tar -czf "/backup/$1" .' sh "$archive"; then
        if [[ $was_running == 'true' ]]; then
            docker start "$WAT_APP_CONTAINER" >/dev/null || true
        fi
        wat_log ERROR "应用备份失败：${WAT_APP_NAME}"
        wat_ui_error '备份失败，应用数据未被修改。'
        return 1
    fi

    if [[ $was_running == 'true' ]]; then
        docker start "$WAT_APP_CONTAINER" >/dev/null
    fi
    WAT_LAST_BACKUP_PATH="${backup_dir}/${archive}"
    export WAT_LAST_BACKUP_PATH
    wat_log INFO "应用备份完成：${WAT_APP_NAME} ${WAT_LAST_BACKUP_PATH}"
    wat_ui_success "备份完成：${WAT_LAST_BACKUP_PATH}"
}

wat_backup_create() {
    local app_id=$1
    wat_apps_select "$app_id" || return 1
    wat_ui_title "备份 ${WAT_APP_NAME}"
    wat_ui_warn '备份期间应用会短暂停止，以保证数据一致性。'
    if ! wat_confirm "确定备份 ${WAT_APP_NAME} 吗？"; then
        wat_ui_info '操作已取消。'
        return 0
    fi
    wat_backup_snapshot "$app_id" manual
}

# Non-interactive entry point used only by the fixed systemd backup service.
# Missing applications are skipped; deployed application failures are reported.
wat_backup_run_all() {
    local app_id failures=0 backed_up=0
    wat_require_root || return 1
    wat_apps_require_docker || return 1
    for app_id in nginx uptime; do
        wat_apps_select "$app_id" || continue
        if ! wat_apps_exists; then
            wat_log INFO "定时备份跳过未部署应用：${WAT_APP_NAME}"
            continue
        fi
        if wat_backup_snapshot "$app_id" scheduled; then
            backed_up=$((backed_up + 1))
        else
            failures=$((failures + 1))
        fi
    done
    if ((failures > 0)); then
        wat_log ERROR "定时备份完成但存在失败：${failures}"
        return 1
    fi
    wat_log INFO "定时备份完成：${backed_up} 个应用"
    wat_ui_success "备份任务完成：${backed_up} 个应用。"
}

wat_backup_list() {
    local backup_dir
    wat_ui_title '应用备份列表'
    backup_dir=$(wat_backup_app_dir)
    if [[ ! -d $backup_dir ]]; then
        wat_ui_info '尚无应用备份。'
        return 0
    fi
    find "$backup_dir" -maxdepth 1 -type f -name '*.tar.gz' \
        -printf '%TY-%Tm-%Td %TH:%TM  %10s bytes  %f\n' | sort -r
}

wat_backup_verify_archive() {
    local archive=$1
    local backup_dir filename
    backup_dir=$(wat_backup_app_dir)
    filename=$(basename -- "$archive")
    docker run --rm -v "${backup_dir}:/backup:ro" "$WAT_BACKUP_IMAGE" \
        tar -tzf "/backup/${filename}" >/dev/null
}

wat_backup_extract_archive() {
    local archive=$1
    local backup_dir filename
    backup_dir=$(wat_backup_app_dir)
    filename=$(basename -- "$archive")
    docker run --rm \
        -v "${WAT_APP_VOLUME}:/target" \
        -v "${backup_dir}:/backup:ro" \
        "$WAT_BACKUP_IMAGE" sh -c \
        'rm -rf -- /target/* /target/.[!.]* /target/..?* && tar -xzf "/backup/$1" -C /target' \
        sh "$filename"
}

wat_backup_restore_latest() {
    local app_id=$1
    local target safety was_running='false' answer
    wat_apps_select "$app_id" || return 1
    wat_ui_title "恢复 ${WAT_APP_NAME}"
    wat_require_root || return 1
    wat_apps_require_docker || return 1
    if ! wat_apps_exists; then
        wat_ui_error "${WAT_APP_NAME} 尚未部署。"
        return 1
    fi
    target=$(wat_backup_latest "$app_id")
    if [[ -z $target ]]; then
        wat_ui_error '没有可恢复的备份。'
        return 1
    fi

    wat_ui_warn "即将用最新备份覆盖当前数据：${target}"
    read -r -p '请输入 RESTORE 确认恢复：' answer
    if [[ $answer != 'RESTORE' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        return 0
    fi
    if ! wat_backup_verify_archive "$target"; then
        wat_ui_error '目标备份校验失败，未修改当前数据。'
        return 1
    fi

    wat_ui_info '正在创建恢复前安全快照。'
    wat_backup_snapshot "$app_id" pre-restore || return 1
    safety=$WAT_LAST_BACKUP_PATH
    if [[ $(docker container inspect --format '{{.State.Running}}' "$WAT_APP_CONTAINER") == 'true' ]]; then
        was_running='true'
        docker stop "$WAT_APP_CONTAINER" >/dev/null
    fi

    if ! wat_backup_extract_archive "$target"; then
        wat_ui_error '恢复目标备份失败，正在回滚安全快照。'
        wat_backup_extract_archive "$safety" || \
            wat_ui_error "自动回滚失败，请保留安全备份：${safety}"
        if [[ $was_running == 'true' ]]; then
            docker start "$WAT_APP_CONTAINER" >/dev/null || true
        fi
        wat_log ERROR "应用恢复失败：${WAT_APP_NAME} ${target}"
        return 1
    fi

    if [[ $was_running == 'true' ]]; then
        docker start "$WAT_APP_CONTAINER" >/dev/null
    fi
    wat_log INFO "应用恢复完成：${WAT_APP_NAME} ${target}"
    wat_ui_success "恢复完成。安全快照保留于：${safety}"
}

wat_backup_menu() {
    local choice
    while true; do
        wat_ui_title '应用网络与备份'
        wat_ui_menu \
            '1. 查看应用专用网络状态' \
            '2. 创建网络并连接现有应用' \
            '3. 备份 Nginx' \
            '4. 备份 Uptime Kuma' \
            '5. 查看备份列表' \
            '6. 恢复 Nginx 最新备份' \
            '7. 恢复 Uptime Kuma 最新备份' \
            '8. 查看备份健康状态' \
            '9. 校验全部备份并生成 SHA-256 清单' \
            '10. 预览备份保留清理' \
            '11. 手动清理旧备份' \
            '12. 创建托管配置快照' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_apps_network_status || true; wat_pause ;;
            2) wat_apps_network_connect_existing || true; wat_pause ;;
            3) wat_backup_create nginx || true; wat_pause ;;
            4) wat_backup_create uptime || true; wat_pause ;;
            5) wat_backup_list || true; wat_pause ;;
            6) wat_backup_restore_latest nginx || true; wat_pause ;;
            7) wat_backup_restore_latest uptime || true; wat_pause ;;
            8) wat_storage_health || true; wat_pause ;;
            9) wat_storage_verify_all || true; wat_pause ;;
            10) wat_storage_cleanup_preview || true; wat_pause ;;
            11) wat_storage_cleanup_purge || true; wat_pause ;;
            12) wat_config_snapshot_create || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
