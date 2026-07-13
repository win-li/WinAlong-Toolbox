#!/usr/bin/env bash
set -Eeuo pipefail

wat_update_version_valid() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

wat_update_stage() {
    local ssh_command='' sudo_home='' clone_failed='false'
    if ! wat_command_exists git; then
        wat_ui_error '未找到 git，无法检查更新。'
        return 1
    fi
    WAT_UPDATE_TEMP_DIR=$(mktemp -d)
    export WAT_UPDATE_TEMP_DIR
    if [[ ${EUID:-$(id -u)} -eq 0 && -n ${SUDO_USER:-} && $SUDO_USER != 'root' ]]; then
        if ! id "$SUDO_USER" >/dev/null 2>&1; then
            wat_ui_error 'SUDO_USER 无效，拒绝选择 SSH 密钥。'
            wat_update_cleanup
            return 1
        fi
        sudo_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ ! -r ${sudo_home}/.ssh/id_ed25519 ]]; then
            wat_ui_error "未找到 ${SUDO_USER} 的 GitHub SSH 私钥。"
            wat_update_cleanup
            return 1
        fi
        ssh_command="ssh -i ${sudo_home}/.ssh/id_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${sudo_home}/.ssh/known_hosts"
    fi
    if [[ -n $ssh_command ]]; then
        GIT_SSH_COMMAND="$ssh_command" git clone --quiet --depth 1 --branch "$WAT_UPDATE_BRANCH" \
            "$WAT_UPDATE_REPO" "${WAT_UPDATE_TEMP_DIR}/repo" || clone_failed='true'
    else
        git clone --quiet --depth 1 --branch "$WAT_UPDATE_BRANCH" \
            "$WAT_UPDATE_REPO" "${WAT_UPDATE_TEMP_DIR}/repo" || clone_failed='true'
    fi
    if [[ ${clone_failed:-false} == 'true' ]]; then
        rm -rf -- "$WAT_UPDATE_TEMP_DIR"
        unset WAT_UPDATE_TEMP_DIR
        wat_ui_error '无法通过 GitHub SSH 克隆更新仓库。'
        return 1
    fi
    WAT_UPDATE_STAGE_DIR="${WAT_UPDATE_TEMP_DIR}/repo"
    export WAT_UPDATE_STAGE_DIR
}

wat_update_cleanup() {
    if [[ -n ${WAT_UPDATE_TEMP_DIR:-} && -d ${WAT_UPDATE_TEMP_DIR:-} ]]; then
        rm -rf -- "$WAT_UPDATE_TEMP_DIR"
    fi
    unset WAT_UPDATE_TEMP_DIR WAT_UPDATE_STAGE_DIR
}

wat_update_remote_version() {
    local config_file="${WAT_UPDATE_STAGE_DIR}/config/default.conf"
    local version
    version=$(awk -F'"' '$1 == "WAT_VERSION=" {print $2; exit}' "$config_file")
    if ! wat_update_version_valid "$version"; then
        wat_ui_error '远程版本号无效，已拒绝更新。'
        return 1
    fi
    printf '%s' "$version"
}

wat_update_check() {
    local remote_version newest
    wat_ui_title '检查在线更新'
    wat_ui_info "更新通道：${WAT_UPDATE_CHANNEL}，分支：${WAT_UPDATE_BRANCH}"
    wat_update_stage || return 1
    remote_version=$(wat_update_remote_version) || {
        wat_update_cleanup
        return 1
    }
    printf '当前版本：%s\n远程版本：%s\n' "$WAT_VERSION" "$remote_version"
    newest=$(printf '%s\n%s\n' "$WAT_VERSION" "$remote_version" | sort -V | tail -n 1)
    if [[ $remote_version == "$WAT_VERSION" ]]; then
        wat_ui_success '当前已经是最新版本。'
    elif [[ $newest == "$remote_version" ]]; then
        wat_ui_info '发现新版本。'
    else
        wat_ui_warn '本地版本高于远程版本，不会自动降级。'
    fi
    wat_update_cleanup
}

wat_update_rollback() {
    local archive=$1
    if [[ $WAT_INSTALL_DIR != '/opt/winalong-toolbox' ]]; then
        wat_ui_error '安装目录不符合安全策略，拒绝回滚。'
        return 1
    fi
    install -m 0755 -d "$WAT_INSTALL_DIR"
    find "$WAT_INSTALL_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    tar -xzf "$archive" -C "$WAT_INSTALL_DIR"
    ln -sfn "$WAT_INSTALL_DIR/toolbox.sh" "$WAT_BIN_LINK"
}

wat_update_apply() {
    local remote_version newest backup_dir backup_file answer
    wat_ui_title '应用在线更新'
    wat_require_root || return 1
    if [[ $WAT_INSTALL_DIR != '/opt/winalong-toolbox' ]]; then
        wat_ui_error '在线更新只允许操作 /opt/winalong-toolbox。'
        return 1
    fi
    wat_update_stage || return 1
    remote_version=$(wat_update_remote_version) || {
        wat_update_cleanup
        return 1
    }
    newest=$(printf '%s\n%s\n' "$WAT_VERSION" "$remote_version" | sort -V | tail -n 1)
    if [[ $remote_version == "$WAT_VERSION" ]]; then
        wat_ui_success '当前已经是最新版本。'
        wat_update_cleanup
        return 0
    fi
    if [[ $newest != "$remote_version" ]]; then
        wat_ui_warn '远程版本低于本地版本，拒绝自动降级。'
        wat_update_cleanup
        return 1
    fi

    wat_ui_warn "即将从 ${WAT_VERSION} 更新到 ${remote_version}。"
    read -r -p '请输入 UPDATE 确认更新：' answer
    if [[ $answer != 'UPDATE' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        wat_update_cleanup
        return 0
    fi
    wat_ui_info '正在运行远程版本完整烟雾测试。'
    if ! bash "${WAT_UPDATE_STAGE_DIR}/tests/smoke.sh"; then
        wat_ui_error '远程版本测试失败，未修改当前安装。'
        wat_update_cleanup
        return 1
    fi

    backup_dir="${WAT_BACKUP_DIR}/updates"
    install -m 0700 -d "$backup_dir"
    backup_file="${backup_dir}/winalong-${WAT_VERSION}-$(date '+%Y%m%d-%H%M%S').tar.gz"
    tar -czf "$backup_file" -C "$WAT_INSTALL_DIR" .
    wat_log INFO "更新前备份：${backup_file}"

    if ! bash "${WAT_UPDATE_STAGE_DIR}/install.sh"; then
        wat_ui_error '新版本安装失败，正在恢复原安装。'
        wat_update_rollback "$backup_file" || \
            wat_ui_error "自动回滚失败，请保留备份：${backup_file}"
        wat_update_cleanup
        return 1
    fi
    wat_log INFO "在线更新完成：${WAT_VERSION} -> ${remote_version}"
    wat_update_cleanup
    wat_ui_success "已更新到 ${remote_version}。请退出并重新运行 winalong。"
}

wat_update_menu() {
    local choice
    while true; do
        wat_ui_title '在线更新'
        wat_ui_menu \
            '1. 检查更新' \
            '2. 应用更新' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_update_check || true; wat_pause ;;
            2) wat_update_apply || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
