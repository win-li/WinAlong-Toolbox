#!/usr/bin/env bash
set -Eeuo pipefail

wat_plugins_paths() {
    printf '%s\n' "${WAT_ROOT_DIR}/plugins" "$WAT_PLUGIN_DIR"
}

wat_plugins_find() {
    local plugin_id=$1 directory candidate
    if [[ ! $plugin_id =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        wat_ui_error '插件 ID 只能包含小写字母、数字、下划线和连字符。'
        return 1
    fi
    while IFS= read -r directory; do
        candidate="${directory}/${plugin_id}.plugin.sh"
        if [[ -f $candidate ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done < <(wat_plugins_paths)
    wat_ui_error "未找到插件：${plugin_id}"
    return 1
}

wat_plugins_validate_file() {
    local plugin_file=$1 owner mode group_digit other_digit
    owner=$(stat -c '%u' "$plugin_file")
    mode=$(stat -c '%a' "$plugin_file")
    group_digit=$(((10#$mode / 10) % 10))
    other_digit=$((10#$mode % 10))
    if [[ $owner != '0' ]]; then
        wat_ui_error '插件文件必须由 root 所有。'
        return 1
    fi
    if (((group_digit & 2) != 0 || (other_digit & 2) != 0)); then
        wat_ui_error '插件文件不能允许组或其他用户写入。'
        return 1
    fi
}

wat_plugins_list() {
    local directory plugin_file found='false'
    wat_ui_title '插件列表'
    while IFS= read -r directory; do
        [[ -d $directory ]] || continue
        while IFS= read -r -d '' plugin_file; do
            found='true'
            printf '%-24s  %s\n' "$(basename "$plugin_file" .plugin.sh)" "$plugin_file"
        done < <(find "$directory" -maxdepth 1 -type f -name '*.plugin.sh' -print0)
    done < <(wat_plugins_paths)
    if [[ $found == 'false' ]]; then
        wat_ui_info '没有可用插件。'
    fi
    printf '\n%s\n' '插件只在用户明确选择后加载，不会自动执行。'
}

wat_plugins_run() {
    local plugin_id plugin_file checksum answer
    wat_ui_title '运行插件'
    read -r -p '请输入插件 ID：' plugin_id
    plugin_file=$(wat_plugins_find "$plugin_id") || return 1
    wat_plugins_validate_file "$plugin_file" || return 1
    checksum=$(sha256sum "$plugin_file" | awk '{print $1}')
    printf '插件文件：%s\nSHA-256：%s\n' "$plugin_file" "$checksum"
    grep -E '^WAT_PLUGIN_(ID|NAME|VERSION)=' "$plugin_file" || true
    wat_ui_warn '插件拥有当前用户的全部权限；使用 sudo 运行时等同于 root 权限。'
    read -r -p '请输入 RUN 确认执行插件：' answer
    if [[ $answer != 'RUN' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        return 0
    fi

    (
        unset WAT_PLUGIN_ID WAT_PLUGIN_NAME WAT_PLUGIN_VERSION
        unset -f wat_plugin_run 2>/dev/null || true
        # shellcheck source=/dev/null
        . "$plugin_file"
        if [[ ${WAT_PLUGIN_ID:-} != "$plugin_id" ]] || \
            ! declare -F wat_plugin_run >/dev/null; then
            wat_ui_error '插件元数据或入口函数无效。'
            exit 1
        fi
        wat_plugin_run
    )
    wat_log INFO "执行插件：${plugin_id} ${checksum}"
}

wat_plugins_menu() {
    local choice
    while true; do
        wat_ui_title '插件中心'
        wat_ui_menu \
            '1. 查看插件列表' \
            '2. 按 ID 运行插件' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_plugins_list; wat_pause ;;
            2) wat_plugins_run || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
