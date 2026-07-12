#!/usr/bin/env bash
set -Eeuo pipefail

wat_portainer_require_docker() {
    wat_docker_require_client || return 1
    if ! docker info >/dev/null 2>&1; then
        wat_ui_error '无法连接 Docker 服务。请确认服务正在运行并使用 sudo。'
        return 1
    fi
}

wat_portainer_config_valid() {
    if [[ $WAT_PORTAINER_BIND != '127.0.0.1' ]]; then
        wat_ui_error '安全策略要求 Portainer 仅绑定 127.0.0.1。'
        return 1
    fi
    if [[ ! $WAT_PORTAINER_PORT =~ ^[0-9]+$ ]] || \
        ((WAT_PORTAINER_PORT < 1 || WAT_PORTAINER_PORT > 65535)); then
        wat_ui_error "Portainer 端口无效：${WAT_PORTAINER_PORT}"
        return 1
    fi
    if [[ ! $WAT_PORTAINER_CONTAINER =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || \
        [[ ! $WAT_PORTAINER_VOLUME =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        wat_ui_error 'Portainer 容器名或数据卷名称无效。'
        return 1
    fi
}

wat_portainer_exists() {
    docker container inspect "$WAT_PORTAINER_CONTAINER" >/dev/null 2>&1
}

wat_portainer_status() {
    wat_ui_title 'Portainer 状态'
    wat_portainer_require_docker || return 1
    if ! wat_portainer_exists; then
        wat_ui_info 'Portainer 尚未部署。'
        return 0
    fi
    docker ps -a --filter "name=^/${WAT_PORTAINER_CONTAINER}$" \
        --format '名称={{.Names}}  状态={{.Status}}  端口={{.Ports}}  镜像={{.Image}}'
    wat_log INFO '查看 Portainer 状态'
}

wat_portainer_install() {
    wat_ui_title '部署 Portainer CE'
    wat_require_root || return 1
    wat_portainer_config_valid || return 1
    wat_portainer_require_docker || return 1
    if wat_portainer_exists; then
        wat_ui_info "容器 ${WAT_PORTAINER_CONTAINER} 已存在，不会覆盖。"
        wat_portainer_status
        return 0
    fi

    wat_ui_warn 'Portainer 将获得 Docker socket 访问权，等同于较高的服务器管理权限。'
    wat_ui_info "管理界面仅监听 ${WAT_PORTAINER_BIND}:${WAT_PORTAINER_PORT}，不会公开暴露端口。"
    if ! wat_confirm '确定拉取官方 LTS 镜像并部署吗？'; then
        wat_ui_info '操作已取消。'
        wat_log INFO '用户取消 Portainer 部署'
        return 0
    fi

    wat_log INFO "开始部署 Portainer：${WAT_PORTAINER_IMAGE}"
    docker volume create "$WAT_PORTAINER_VOLUME" >/dev/null
    docker pull "$WAT_PORTAINER_IMAGE"
    docker run -d \
        --name "$WAT_PORTAINER_CONTAINER" \
        --restart=always \
        -p "${WAT_PORTAINER_BIND}:${WAT_PORTAINER_PORT}:9443" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${WAT_PORTAINER_VOLUME}:/data" \
        "$WAT_PORTAINER_IMAGE" >/dev/null
    wat_log INFO 'Portainer 部署完成'
    wat_ui_success 'Portainer 部署完成。'
    wat_portainer_access_info
}

wat_portainer_action() {
    local action=$1
    local label=$2
    wat_ui_title "${label} Portainer"
    wat_require_root || return 1
    wat_portainer_require_docker || return 1
    if ! wat_portainer_exists; then
        wat_ui_error 'Portainer 容器不存在。'
        return 1
    fi
    if ! wat_confirm "确定${label} Portainer 吗？"; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    docker "$action" "$WAT_PORTAINER_CONTAINER" >/dev/null
    wat_log INFO "Portainer 容器操作：${action}"
    wat_ui_success "Portainer 已${label}。"
}

wat_portainer_logs() {
    wat_ui_title 'Portainer 日志'
    wat_portainer_require_docker || return 1
    if ! wat_portainer_exists; then
        wat_ui_error 'Portainer 容器不存在。'
        return 1
    fi
    docker logs --tail 100 "$WAT_PORTAINER_CONTAINER"
    wat_log INFO '查看 Portainer 日志'
}

wat_portainer_access_info() {
    wat_ui_title 'Portainer 访问方式'
    wat_portainer_config_valid || return 1
    printf '%s\n' 'Portainer 默认仅允许服务器本机访问。'
    printf '%s\n\n' '请在 Windows PowerShell 建立 SSH 隧道：'
    printf 'ssh -L %s:127.0.0.1:%s ubuntu@<服务器公网IP>\n\n' \
        "$WAT_PORTAINER_PORT" "$WAT_PORTAINER_PORT"
    printf '保持 SSH 窗口运行，然后浏览器打开：\nhttps://localhost:%s\n' \
        "$WAT_PORTAINER_PORT"
    wat_ui_info '首次访问会使用自签名证书，浏览器可能显示安全提醒。'
    wat_ui_warn '首次管理员初始化需在容器启动后 5 分钟内完成。'
    printf '%s\n' 'Setup token 可在 VPS 上通过以下命令查看：'
    printf '%s\n' 'sudo docker logs --since 2m portainer 2>&1 | grep -i "token"'
    wat_ui_warn 'Setup token 和管理员密码属于敏感信息，请勿截图或发送给他人。'
}

wat_portainer_menu() {
    local choice
    while true; do
        wat_ui_title 'Portainer 管理'
        wat_ui_menu \
            '1. 查看 Portainer 状态' \
            '2. 部署 Portainer CE' \
            '3. 启动 Portainer' \
            '4. 停止 Portainer' \
            '5. 重启 Portainer' \
            '6. 查看最近 100 行日志' \
            '7. 查看安全访问方式' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_portainer_status || true; wat_pause ;;
            2) wat_portainer_install || true; wat_pause ;;
            3) wat_portainer_action start '启动' || true; wat_pause ;;
            4) wat_portainer_action stop '停止' || true; wat_pause ;;
            5) wat_portainer_action restart '重启' || true; wat_pause ;;
            6) wat_portainer_logs || true; wat_pause ;;
            7) wat_portainer_access_info || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
