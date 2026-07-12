#!/usr/bin/env bash
set -Eeuo pipefail

wat_apps_select() {
    case $1 in
        nginx)
            WAT_APP_ID='nginx'
            WAT_APP_NAME='Nginx'
            WAT_APP_IMAGE=$WAT_NGINX_IMAGE
            WAT_APP_CONTAINER=$WAT_NGINX_CONTAINER
            WAT_APP_VOLUME=$WAT_NGINX_VOLUME
            WAT_APP_PORT=$WAT_NGINX_PORT
            WAT_APP_INTERNAL_PORT='80'
            WAT_APP_VOLUME_TARGET='/usr/share/nginx/html'
            WAT_APP_SCHEME='http'
            ;;
        uptime)
            WAT_APP_ID='uptime'
            WAT_APP_NAME='Uptime Kuma'
            WAT_APP_IMAGE=$WAT_UPTIME_IMAGE
            WAT_APP_CONTAINER=$WAT_UPTIME_CONTAINER
            WAT_APP_VOLUME=$WAT_UPTIME_VOLUME
            WAT_APP_PORT=$WAT_UPTIME_PORT
            WAT_APP_INTERNAL_PORT='3001'
            WAT_APP_VOLUME_TARGET='/app/data'
            WAT_APP_SCHEME='http'
            ;;
        *)
            wat_ui_error "未知应用：$1"
            return 1
            ;;
    esac
}

wat_apps_config_valid() {
    if [[ $WAT_APPS_BIND != '127.0.0.1' ]]; then
        wat_ui_error '安全策略要求应用仅绑定 127.0.0.1。'
        return 1
    fi
    if [[ ! $WAT_APP_PORT =~ ^[0-9]+$ ]] || \
        ((WAT_APP_PORT < 1 || WAT_APP_PORT > 65535)); then
        wat_ui_error "${WAT_APP_NAME} 端口无效：${WAT_APP_PORT}"
        return 1
    fi
    if [[ ! $WAT_APP_CONTAINER =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || \
        [[ ! $WAT_APP_VOLUME =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        wat_ui_error "${WAT_APP_NAME} 的容器名或数据卷名称无效。"
        return 1
    fi
}

wat_apps_require_docker() {
    wat_docker_require_client || return 1
    if ! docker info >/dev/null 2>&1; then
        wat_ui_error '无法连接 Docker 服务。请确认服务正在运行并使用 sudo。'
        return 1
    fi
}

wat_apps_exists() {
    docker container inspect "$WAT_APP_CONTAINER" >/dev/null 2>&1
}

wat_apps_status_one() {
    wat_apps_select "$1" || return 1
    if wat_apps_exists; then
        docker ps -a --filter "name=^/${WAT_APP_CONTAINER}$" \
            --format '名称={{.Names}}  状态={{.Status}}  端口={{.Ports}}  镜像={{.Image}}'
    else
        printf '%s：未部署\n' "$WAT_APP_NAME"
    fi
}

wat_apps_status_all() {
    wat_ui_title '应用中心状态'
    wat_apps_require_docker || return 1
    wat_apps_status_one nginx
    wat_apps_status_one uptime
    wat_log INFO '查看应用中心状态'
}

wat_apps_deploy() {
    wat_apps_select "$1" || return 1
    wat_ui_title "部署 ${WAT_APP_NAME}"
    wat_require_root || return 1
    wat_apps_config_valid || return 1
    wat_apps_require_docker || return 1
    if wat_apps_exists; then
        wat_ui_info "容器 ${WAT_APP_CONTAINER} 已存在，不会覆盖。"
        wat_apps_status_one "$WAT_APP_ID"
        return 0
    fi

    wat_ui_info "${WAT_APP_NAME} 仅监听 ${WAT_APPS_BIND}:${WAT_APP_PORT}。"
    if ! wat_confirm "确定拉取镜像并部署 ${WAT_APP_NAME} 吗？"; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    wat_log INFO "开始部署应用：${WAT_APP_NAME} ${WAT_APP_IMAGE}"
    docker volume create "$WAT_APP_VOLUME" >/dev/null
    docker pull "$WAT_APP_IMAGE"
    docker run -d \
        --name "$WAT_APP_CONTAINER" \
        --restart=unless-stopped \
        -p "${WAT_APPS_BIND}:${WAT_APP_PORT}:${WAT_APP_INTERNAL_PORT}" \
        -v "${WAT_APP_VOLUME}:${WAT_APP_VOLUME_TARGET}" \
        "$WAT_APP_IMAGE" >/dev/null
    wat_log INFO "应用部署完成：${WAT_APP_NAME}"
    wat_ui_success "${WAT_APP_NAME} 部署完成。"
    wat_apps_access_info "$WAT_APP_ID"
}

wat_apps_action() {
    local app_id=$1
    local action=$2
    local label=$3
    wat_apps_select "$app_id" || return 1
    wat_ui_title "${label} ${WAT_APP_NAME}"
    wat_require_root || return 1
    wat_apps_require_docker || return 1
    if ! wat_apps_exists; then
        wat_ui_error "${WAT_APP_NAME} 尚未部署。"
        return 1
    fi
    if ! wat_confirm "确定${label} ${WAT_APP_NAME} 吗？"; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    docker "$action" "$WAT_APP_CONTAINER" >/dev/null
    wat_log INFO "应用容器操作：${WAT_APP_NAME} ${action}"
    wat_ui_success "${WAT_APP_NAME} 已${label}。"
}

wat_apps_logs() {
    wat_apps_select "$1" || return 1
    wat_ui_title "${WAT_APP_NAME} 日志"
    wat_apps_require_docker || return 1
    if ! wat_apps_exists; then
        wat_ui_error "${WAT_APP_NAME} 尚未部署。"
        return 1
    fi
    docker logs --tail 100 "$WAT_APP_CONTAINER"
    wat_log INFO "查看应用日志：${WAT_APP_NAME}"
}

wat_apps_access_info() {
    wat_apps_select "$1" || return 1
    wat_apps_config_valid || return 1
    wat_ui_title "${WAT_APP_NAME} 访问方式"
    printf '在 Windows PowerShell 建立 SSH 隧道：\n'
    printf 'ssh -L %s:127.0.0.1:%s ubuntu@<服务器公网IP>\n\n' \
        "$WAT_APP_PORT" "$WAT_APP_PORT"
    printf '保持 SSH 窗口运行，然后访问：\n%s://localhost:%s\n' \
        "$WAT_APP_SCHEME" "$WAT_APP_PORT"
}

wat_apps_single_menu() {
    local app_id=$1
    local choice
    wat_apps_select "$app_id" || return 1
    while true; do
        wat_apps_select "$app_id" || return 1
        wat_ui_title "${WAT_APP_NAME} 管理"
        wat_ui_menu \
            '1. 查看状态' \
            '2. 部署应用' \
            '3. 启动应用' \
            '4. 停止应用' \
            '5. 重启应用' \
            '6. 查看最近 100 行日志' \
            '7. 查看安全访问方式' \
            '0. 返回应用中心'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1)
                if wat_apps_require_docker; then
                    wat_apps_status_one "$app_id" || true
                fi
                wat_pause
                ;;
            2) wat_apps_deploy "$app_id" || true; wat_pause ;;
            3) wat_apps_action "$app_id" start '启动' || true; wat_pause ;;
            4) wat_apps_action "$app_id" stop '停止' || true; wat_pause ;;
            5) wat_apps_action "$app_id" restart '重启' || true; wat_pause ;;
            6) wat_apps_logs "$app_id" || true; wat_pause ;;
            7) wat_apps_access_info "$app_id" || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}

wat_apps_menu() {
    local choice
    while true; do
        wat_ui_title 'Docker 应用中心'
        wat_ui_menu \
            '1. 查看全部应用状态' \
            '2. Nginx 管理' \
            '3. Uptime Kuma 管理' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_apps_status_all || true; wat_pause ;;
            2) wat_apps_single_menu nginx ;;
            3) wat_apps_single_menu uptime ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
