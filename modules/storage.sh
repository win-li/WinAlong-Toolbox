#!/usr/bin/env bash
set -Eeuo pipefail

wat_storage_validate_config() {
    [[ $WAT_BACKUP_KEEP_COUNT =~ ^[0-9]+$ ]] &&
        [[ $WAT_BACKUP_MIN_KEEP_COUNT =~ ^[0-9]+$ ]] &&
        [[ $WAT_BACKUP_STALE_HOURS =~ ^[0-9]+$ ]] &&
        [[ $WAT_BACKUP_MIN_FREE_PERCENT =~ ^[0-9]+$ ]] &&
        ((WAT_BACKUP_MIN_KEEP_COUNT >= 1)) &&
        ((WAT_BACKUP_KEEP_COUNT >= WAT_BACKUP_MIN_KEEP_COUNT)) &&
        ((WAT_BACKUP_STALE_HOURS >= 1)) &&
        ((WAT_BACKUP_MIN_FREE_PERCENT >= 1 && WAT_BACKUP_MIN_FREE_PERCENT <= 50))
}

wat_storage_archive_name_valid() {
    [[ $1 =~ ^(nginx|uptime)-[0-9]{8}-[0-9]{6}-(manual|scheduled|pre-restore)-[0-9]+\.tar\.gz$ ]]
}

wat_storage_archive_valid() {
    local archive=$1 listing
    [[ -f $archive && ! -L $archive && -s $archive ]] || return 1
    wat_storage_archive_name_valid "$(basename -- "$archive")" || return 1
    listing=$(tar -tzf "$archive" 2>/dev/null) || return 1
    [[ -n $listing ]]
}

wat_storage_archive_files() {
    local app_id=$1 backup_dir file
    backup_dir=$(wat_backup_app_dir)
    [[ -d $backup_dir ]] || return 0
    while IFS= read -r -d '' file; do
        wat_storage_archive_name_valid "$(basename -- "$file")" || continue
        printf '%s\n' "$file"
    done < <(find "$backup_dir" -maxdepth 1 -type f -name "${app_id}-*.tar.gz" -print0)
}

wat_storage_all_archives() {
    local backup_dir
    backup_dir=$(wat_backup_app_dir)
    [[ -d $backup_dir ]] || return 0
    find "$backup_dir" -maxdepth 1 -name '*.tar.gz' -print
}

wat_storage_latest_archive() {
    local app_id=$1 file newest='' newest_time=0 file_time
    while IFS= read -r file; do
        file_time=$(stat -c '%Y' -- "$file" 2>/dev/null || printf '0')
        if ((file_time > newest_time)); then
            newest=$file
            newest_time=$file_time
        fi
    done < <(wat_storage_archive_files "$app_id")
    printf '%s' "$newest"
}

wat_storage_backup_space_ok() {
    local target used_percent free_percent
    wat_storage_validate_config || return 1
    target=$WAT_BACKUP_DIR
    [[ -d $target ]] || target=$(dirname -- "$target")
    used_percent=$(df -P "$target" 2>/dev/null | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
    [[ $used_percent =~ ^[0-9]+$ ]] || return 1
    free_percent=$((100 - used_percent))
    ((free_percent >= WAT_BACKUP_MIN_FREE_PERCENT))
}

wat_storage_health_summary() {
    local app_id app_name latest count size age_hours now status total_size=0 issues=0
    local file nonstandard=0 timer_state='未安装' service_result='无记录'
    local backup_dir
    backup_dir=$(wat_backup_app_dir)
    now=$(date +%s)
    printf '备份目录：%s\n' "$backup_dir"
    for app_id in nginx uptime; do
        case $app_id in
            nginx) app_name='Nginx' ;;
            uptime) app_name='Uptime Kuma' ;;
        esac
        count=$(wat_storage_archive_files "$app_id" | awk 'NF {count++} END {print count+0}')
        latest=$(wat_storage_latest_archive "$app_id")
        if [[ -n $latest ]]; then
            size=$(stat -c '%s' -- "$latest" 2>/dev/null || printf '0')
            age_hours=$(((now - $(stat -c '%Y' -- "$latest")) / 3600))
            if wat_storage_archive_valid "$latest"; then
                status='正常'
            else
                status='损坏'
                issues=$((issues + 1))
            fi
            if ((age_hours > WAT_BACKUP_STALE_HOURS)); then
                status="${status}/过期"
                issues=$((issues + 1))
            fi
            printf '%s：%s 个；最新=%s；%s 字节；%s 小时前；%s\n' \
                "$app_name" "$count" "$(basename -- "$latest")" "$size" "$age_hours" "$status"
        else
            printf '%s：0 个；尚无备份\n' "$app_name"
        fi
    done
    while IFS= read -r file; do
        if [[ ! -f $file || -L $file ]] || ! wat_storage_archive_name_valid "$(basename -- "$file")"; then
            nonstandard=$((nonstandard + 1))
        fi
    done < <(wat_storage_all_archives)
    if ((nonstandard > 0)); then
        printf '非标准或链接归档：%s 个\n' "$nonstandard"
        issues=$((issues + nonstandard))
    else
        printf '非标准或链接归档：0 个\n'
    fi
    if [[ -d $backup_dir ]]; then
        total_size=$(find "$backup_dir" -maxdepth 1 -type f -name '*.tar.gz' -printf '%s\n' 2>/dev/null |
            awk '{sum += $1} END {print sum+0}')
    fi
    printf '归档总大小：%s 字节\n' "$total_size"
    if wat_storage_backup_space_ok; then
        printf '备份磁盘余量：正常（至少 %s%%）\n' "$WAT_BACKUP_MIN_FREE_PERCENT"
    else
        printf '备份磁盘余量：不足或无法读取\n'
        issues=$((issues + 1))
    fi
    if wat_command_exists systemctl && systemctl cat "$WAT_BACKUP_TIMER" >/dev/null 2>&1; then
        if systemctl is-active --quiet "$WAT_BACKUP_TIMER" 2>/dev/null; then
            timer_state='active'
        else
            timer_state='inactive'
        fi
        service_result=$(systemctl show "$WAT_BACKUP_SERVICE" -p Result --value 2>/dev/null || printf 'unknown')
        [[ -n $service_result ]] || service_result='无记录'
    fi
    printf '自动备份 Timer：%s；最近服务结果：%s\n' "$timer_state" "$service_result"
    WAT_STORAGE_HEALTH_ISSUES=$issues
    export WAT_STORAGE_HEALTH_ISSUES
    ((issues == 0))
}

wat_storage_health() {
    wat_ui_title '备份健康状态'
    wat_require_root || return 1
    wat_storage_validate_config || { wat_ui_error '备份生命周期配置无效。'; return 1; }
    if wat_storage_health_summary; then
        wat_ui_success '现有备份未发现完整性、过期或磁盘余量问题。'
    else
        wat_ui_warn "发现 ${WAT_STORAGE_HEALTH_ISSUES} 项备份健康问题。"
    fi
}

wat_storage_write_checksums() {
    local backup_dir manifest temp file
    backup_dir=$(wat_backup_app_dir)
    install -o root -g root -m 0700 -d "$backup_dir"
    manifest="${backup_dir}/SHA256SUMS-$(date '+%Y%m%d-%H%M%S')-$$.txt"
    temp=$(mktemp)
    while IFS= read -r file; do
        (cd "$backup_dir" && sha256sum -- "$(basename -- "$file")") >>"$temp"
    done < <(
        for app_id in nginx uptime; do
            wat_storage_archive_files "$app_id"
        done | sort
    )
    if [[ ! -s $temp ]]; then
        rm -f -- "$temp"
        wat_ui_info '没有可生成校验和的标准备份。'
        return 0
    fi
    install -o root -g root -m 0600 "$temp" "$manifest"
    rm -f -- "$temp"
    WAT_LAST_CHECKSUM_PATH=$manifest
    export WAT_LAST_CHECKSUM_PATH
    wat_ui_success "SHA-256 清单已生成：${manifest}"
}

wat_storage_verify_all() {
    local file checked=0 failures=0
    wat_ui_title '校验应用备份'
    wat_require_root || return 1
    while IFS= read -r file; do
        checked=$((checked + 1))
        if wat_storage_archive_valid "$file"; then
            printf '[正常] %s\n' "$(basename -- "$file")"
        else
            printf '[损坏或非标准] %s\n' "$(basename -- "$file")" >&2
            failures=$((failures + 1))
        fi
    done < <(wat_storage_all_archives)
    printf '已校验：%d 个；失败：%d 个\n' "$checked" "$failures"
    ((failures == 0)) || return 1
    wat_storage_write_checksums
}

wat_storage_cleanup_candidates() {
    local app_id=$1 keep=$2 file
    local -a archives=()
    while IFS= read -r file; do
        archives+=("$file")
    done < <(wat_storage_archive_files "$app_id" | while IFS= read -r file; do
        printf '%s %s\n' "$(stat -c '%Y' -- "$file")" "$file"
    done | sort -rn | awk '{print $2}')
    if ((${#archives[@]} > keep)); then
        printf '%s\n' "${archives[@]:keep}"
    fi
}

wat_storage_cleanup_preview() {
    local app_id file count=0
    wat_ui_title '备份保留清理预览'
    wat_require_root || return 1
    wat_storage_validate_config || { wat_ui_error '备份生命周期配置无效。'; return 1; }
    printf '每个应用保留最新 %s 个备份（最低允许 %s 个）。\n' \
        "$WAT_BACKUP_KEEP_COUNT" "$WAT_BACKUP_MIN_KEEP_COUNT"
    for app_id in nginx uptime; do
        while IFS= read -r file; do
            printf '将删除：%s\n' "$(basename -- "$file")"
            count=$((count + 1))
        done < <(wat_storage_cleanup_candidates "$app_id" "$WAT_BACKUP_KEEP_COUNT")
    done
    printf '候选文件：%d 个。当前仅预览，未删除。\n' "$count"
}

wat_storage_cleanup_purge() {
    local answer app_id file resolved backup_real deleted=0
    wat_ui_title '手动清理旧备份'
    wat_require_root || return 1
    wat_storage_validate_config || { wat_ui_error '备份生命周期配置无效。'; return 1; }
    wat_storage_cleanup_preview
    read -r -p '请输入 PURGE 确认删除上述旧备份：' answer
    if [[ $answer != 'PURGE' ]]; then
        wat_ui_info '输入不匹配，未删除任何文件。'
        return 0
    fi
    backup_real=$(realpath -e -- "$(wat_backup_app_dir)") || return 1
    for app_id in nginx uptime; do
        while IFS= read -r file; do
            [[ -f $file && ! -L $file ]] || continue
            wat_storage_archive_name_valid "$(basename -- "$file")" || continue
            resolved=$(realpath -e -- "$file") || continue
            [[ $(dirname -- "$resolved") == "$backup_real" ]] || continue
            rm -f -- "$resolved"
            deleted=$((deleted + 1))
        done < <(wat_storage_cleanup_candidates "$app_id" "$WAT_BACKUP_KEEP_COUNT")
    done
    wat_log INFO "手动备份保留清理完成：${deleted} 个"
    wat_ui_success "已安全删除 ${deleted} 个旧备份。"
}
