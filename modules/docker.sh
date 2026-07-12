#!/usr/bin/env bash
set -Eeuo pipefail

wat_docker_supported() {
    wat_detect_system
    [[ $WAT_OS_ID == 'ubuntu' || $WAT_OS_ID == 'debian' ]]
}

wat_docker_installed() {
    wat_command_exists docker
}

wat_docker_require_client() {
    if ! wat_docker_installed; then
        wat_ui_error 'Docker 尚未安装。'
        return 1
    fi
}

wat_docker_status() {
    wat_ui_title 'Docker 状态'
    if ! wat_docker_installed; then
        wat_ui_info 'Docker 尚未安装。'
        return 0
    fi
    docker --version
    if wat_command_exists systemctl; then
        systemctl --no-pager --full status docker || true
    else
        wat_ui_warn '当前系统没有 systemctl，无法读取服务状态。'
    fi
    wat_log INFO '查看 Docker 状态'
}

wat_docker_versions() {
    wat_ui_title 'Docker 版本'
    wat_docker_require_client || return 1
    docker --version
    if docker compose version >/dev/null 2>&1; then
        docker compose version
    else
        wat_ui_info 'Docker Compose 插件尚未安装。'
    fi
    wat_log INFO '查看 Docker 与 Compose 版本'
}

wat_docker_configure_repo() {
    local arch codename keyring repo_file
    wat_docker_supported || {
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    }

    arch=$(dpkg --print-architecture)
    codename=${VERSION_CODENAME:-}
    if [[ $WAT_OS_ID == 'ubuntu' && -n ${UBUNTU_CODENAME:-} ]]; then
        codename=$UBUNTU_CODENAME
    fi
    if [[ -z $codename ]]; then
        wat_ui_error '无法识别系统代号，未修改软件源。'
        return 1
    fi

    keyring='/etc/apt/keyrings/docker.asc'
    repo_file='/etc/apt/sources.list.d/docker.list'
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${WAT_OS_ID}/gpg" -o "$keyring"
    chmod a+r "$keyring"
    printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/%s %s stable\n' \
        "$arch" "$keyring" "$WAT_OS_ID" "$codename" >"$repo_file"
    apt-get update
}

wat_docker_install_engine() {
    wat_ui_title '安装 Docker Engine'
    wat_require_root || return 1
    if wat_docker_installed; then
        wat_ui_info "Docker 已安装：$(docker --version)"
        return 0
    fi
    if ! wat_docker_supported; then
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    fi
    wat_ui_warn '将添加 Docker 官方 APT 仓库并安装 Docker Engine。'
    if ! wat_confirm '确定继续安装吗？'; then
        wat_ui_info '操作已取消。'
        wat_log INFO '用户取消 Docker Engine 安装'
        return 0
    fi

    wat_log INFO '开始安装 Docker Engine'
    wat_docker_configure_repo
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    wat_log INFO 'Docker Engine 安装完成'
    wat_ui_success 'Docker Engine 安装完成。'
    docker --version
    docker compose version
}

wat_docker_install_compose() {
    wat_ui_title '安装 Docker Compose 插件'
    wat_require_root || return 1
    wat_docker_require_client || {
        wat_ui_info '请先选择“安装 Docker Engine”。'
        return 1
    }
    if docker compose version >/dev/null 2>&1; then
        wat_ui_info "Compose 已安装：$(docker compose version)"
        return 0
    fi
    if ! wat_docker_supported; then
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    fi
    if ! wat_confirm '确定从 Docker 官方仓库安装 Compose 插件吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    wat_docker_configure_repo
    apt-get install -y docker-compose-plugin
    wat_log INFO 'Docker Compose 插件安装完成'
    wat_ui_success 'Docker Compose 插件安装完成。'
    docker compose version
}

wat_docker_service_action() {
    local action=$1
    local label=$2
    wat_ui_title "${label} Docker"
    wat_require_root || return 1
    wat_docker_require_client || return 1
    if ! wat_command_exists systemctl; then
        wat_ui_error '当前系统没有 systemctl。'
        return 1
    fi
    if ! wat_confirm "确定${label} Docker 服务吗？"; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    systemctl "$action" docker
    wat_log INFO "Docker 服务操作：${action}"
    wat_ui_success "Docker 服务已${label}。"
}

wat_docker_list_containers() {
    wat_ui_title 'Docker 容器'
    wat_docker_require_client || return 1
    docker ps -a
    wat_log INFO '查看 Docker 容器'
}

wat_docker_list_images() {
    wat_ui_title 'Docker 镜像'
    wat_docker_require_client || return 1
    docker image ls
    wat_log INFO '查看 Docker 镜像'
}

wat_docker_disk_usage() {
    wat_ui_title 'Docker 磁盘占用'
    wat_docker_require_client || return 1
    docker system df
    wat_log INFO '查看 Docker 磁盘占用'
}

wat_docker_menu() {
    local choice
    while true; do
        wat_ui_title 'Docker 管理'
        wat_ui_menu \
            '1. 查看 Docker 状态' \
            '2. 查看 Docker 与 Compose 版本' \
            '3. 安装 Docker Engine' \
            '4. 安装 Docker Compose 插件' \
            '5. 启动 Docker 服务' \
            '6. 停止 Docker 服务' \
            '7. 重启 Docker 服务' \
            '8. 查看所有容器' \
            '9. 查看镜像' \
            '10. 查看磁盘占用' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_docker_status || true; wat_pause ;;
            2) wat_docker_versions || true; wat_pause ;;
            3) wat_docker_install_engine || true; wat_pause ;;
            4) wat_docker_install_compose || true; wat_pause ;;
            5) wat_docker_service_action start '启动' || true; wat_pause ;;
            6) wat_docker_service_action stop '停止' || true; wat_pause ;;
            7) wat_docker_service_action restart '重启' || true; wat_pause ;;
            8) wat_docker_list_containers || true; wat_pause ;;
            9) wat_docker_list_images || true; wat_pause ;;
            10) wat_docker_disk_usage || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
