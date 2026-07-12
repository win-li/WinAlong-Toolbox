#!/usr/bin/env bash
set -Eeuo pipefail

wat_security_ssh_port() {
    local port=''
    if wat_command_exists sshd; then
        port=$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2; exit}' || true)
    elif [[ -x /usr/sbin/sshd ]]; then
        port=$(/usr/sbin/sshd -T 2>/dev/null | awk '$1 == "port" {print $2; exit}' || true)
    fi
    port=${port:-22}
    if [[ ! $port =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        wat_ui_error "检测到无效 SSH 端口：${port}"
        return 1
    fi
    printf '%s' "$port"
}

wat_security_sshd_value() {
    local key=$1
    local value='unknown'
    if wat_command_exists sshd; then
        value=$(sshd -T 2>/dev/null | awk -v key="$key" '$1 == key {print $2; exit}' || true)
    elif [[ -x /usr/sbin/sshd ]]; then
        value=$(/usr/sbin/sshd -T 2>/dev/null | awk -v key="$key" '$1 == key {print $2; exit}' || true)
    fi
    printf '%s' "${value:-unknown}"
}

wat_security_overview() {
    local ssh_port updates='unknown' root_login password_auth
    wat_ui_title '安全体检'
    ssh_port=$(wat_security_ssh_port) || return 1
    root_login=$(wat_security_sshd_value permitrootlogin)
    password_auth=$(wat_security_sshd_value passwordauthentication)
    if wat_command_exists apt; then
        updates=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l | awk '{$1=$1};1')
    fi

    printf 'SSH 端口：%s\n' "$ssh_port"
    printf 'SSH root 登录策略：%s\n' "$root_login"
    printf 'SSH 密码认证策略：%s\n' "$password_auth"
    printf '待更新软件包：%s\n' "$updates"
    if wat_command_exists ufw; then
        printf 'UFW：%s\n' "$(ufw status 2>/dev/null | head -n 1 || printf '状态不可读')"
    else
        printf '%s\n' 'UFW：未安装'
    fi
    if wat_command_exists fail2ban-client; then
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            printf '%s\n' 'Fail2ban：运行中'
        else
            printf '%s\n' 'Fail2ban：已安装但未运行'
        fi
    else
        printf '%s\n' 'Fail2ban：未安装'
    fi

    printf '\n%s\n' 'Docker 公开端口检查：'
    if wat_command_exists docker && docker info >/dev/null 2>&1; then
        if ! docker ps --format '{{.Names}}  {{.Ports}}' | \
            grep -E '0\.0\.0\.0|\[::\]|:::'; then
            printf '%s\n' '未发现绑定所有地址的 Docker 端口。'
        fi
    else
        printf '%s\n' 'Docker 不可用或当前用户无权访问。'
    fi
    wat_log INFO '完成安全体检'
}

wat_security_listening_ports() {
    wat_ui_title '监听端口'
    if wat_command_exists ss; then
        ss -lntup
    else
        wat_ui_error '未找到 ss 命令。'
        return 1
    fi
    wat_log INFO '查看监听端口'
}

wat_security_ufw_status() {
    wat_ui_title 'UFW 状态'
    if ! wat_command_exists ufw; then
        wat_ui_info 'UFW 尚未安装。'
        return 0
    fi
    ufw status verbose
    wat_log INFO '查看 UFW 状态'
}

wat_security_ufw_install() {
    wat_ui_title '安装 UFW'
    wat_require_root || return 1
    if wat_command_exists ufw; then
        wat_ui_info 'UFW 已安装。'
        return 0
    fi
    if ! wat_confirm '确定从系统软件源安装 UFW 吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi
    apt-get update
    apt-get install -y ufw
    wat_log INFO 'UFW 安装完成'
    wat_ui_success 'UFW 已安装，但尚未启用。'
}

wat_security_ufw_enable() {
    local ssh_port answer
    wat_ui_title '安全启用 UFW'
    wat_require_root || return 1
    if ! wat_command_exists ufw; then
        wat_ui_error '请先安装 UFW。'
        return 1
    fi
    if ufw status | grep -Fq 'Status: active'; then
        wat_ui_info 'UFW 已经启用。'
        ufw status verbose
        return 0
    fi
    ssh_port=$(wat_security_ssh_port) || return 1
    wat_ui_warn "将先允许 TCP ${ssh_port}（当前 SSH 端口），再启用默认拒绝入站策略。"
    wat_ui_warn '错误的云防火墙或 SSH 配置仍可能导致连接中断，请保留当前 SSH 会话。'
    read -r -p '请输入 ENABLE 确认启用 UFW：' answer
    if [[ $answer != 'ENABLE' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        return 0
    fi

    ufw allow "${ssh_port}/tcp" comment 'WinAlong SSH safeguard'
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    wat_log INFO "UFW 已启用，SSH 端口：${ssh_port}"
    wat_ui_success 'UFW 已启用。请另开一个 SSH 窗口验证连接后再关闭当前会话。'
    ufw status verbose
}

wat_security_fail2ban_status() {
    wat_ui_title 'Fail2ban 状态'
    if ! wat_command_exists fail2ban-client; then
        wat_ui_info 'Fail2ban 尚未安装。'
        return 0
    fi
    fail2ban-client status || true
    printf '\n'
    fail2ban-client status sshd || true
    wat_log INFO '查看 Fail2ban 状态'
}

wat_security_fail2ban_install() {
    local ssh_port backup_dir backup_file='' temp_file
    wat_ui_title '安装并配置 Fail2ban'
    wat_require_root || return 1
    ssh_port=$(wat_security_ssh_port) || return 1
    wat_ui_warn "将启用 sshd 防护：端口 ${ssh_port}，${WAT_FAIL2BAN_FINDTIME} 内失败 ${WAT_FAIL2BAN_MAXRETRY} 次后封禁 ${WAT_FAIL2BAN_BANTIME}。"
    if ! wat_confirm '确定安装并应用 Fail2ban SSH 防护吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    apt-get update
    apt-get install -y fail2ban
    backup_dir="${WAT_BACKUP_DIR}/security"
    install -m 0700 -d "$backup_dir"
    if [[ -f $WAT_FAIL2BAN_JAIL_FILE ]]; then
        backup_file="${backup_dir}/winalong-sshd-$(date '+%Y%m%d-%H%M%S').local"
        cp -a -- "$WAT_FAIL2BAN_JAIL_FILE" "$backup_file"
    fi
    temp_file=$(mktemp)
    printf '%s\n' \
        '[sshd]' \
        'enabled = true' \
        "port = ${ssh_port}" \
        'backend = systemd' \
        "bantime = ${WAT_FAIL2BAN_BANTIME}" \
        "findtime = ${WAT_FAIL2BAN_FINDTIME}" \
        "maxretry = ${WAT_FAIL2BAN_MAXRETRY}" >"$temp_file"
    install -m 0644 "$temp_file" "$WAT_FAIL2BAN_JAIL_FILE"
    rm -f -- "$temp_file"

    if ! fail2ban-client -t; then
        if [[ -n $backup_file ]]; then
            cp -a -- "$backup_file" "$WAT_FAIL2BAN_JAIL_FILE"
        else
            rm -f -- "$WAT_FAIL2BAN_JAIL_FILE"
        fi
        wat_log ERROR 'Fail2ban 配置校验失败，已回滚'
        wat_ui_error 'Fail2ban 配置校验失败，已恢复原配置。'
        return 1
    fi
    systemctl enable --now fail2ban
    systemctl restart fail2ban
    wat_log INFO "Fail2ban sshd 防护已启用，SSH 端口：${ssh_port}"
    wat_ui_success 'Fail2ban SSH 防护已启用。'
    fail2ban-client status sshd
}

wat_security_menu() {
    local choice
    while true; do
        wat_ui_title '安全中心'
        wat_ui_menu \
            '1. 安全体检' \
            '2. 查看监听端口' \
            '3. 查看 UFW 状态' \
            '4. 安装 UFW' \
            '5. 安全启用 UFW' \
            '6. 查看 Fail2ban 状态' \
            '7. 安装并配置 Fail2ban SSH 防护' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_security_overview || true; wat_pause ;;
            2) wat_security_listening_ports || true; wat_pause ;;
            3) wat_security_ufw_status || true; wat_pause ;;
            4) wat_security_ufw_install || true; wat_pause ;;
            5) wat_security_ufw_enable || true; wat_pause ;;
            6) wat_security_fail2ban_status || true; wat_pause ;;
            7) wat_security_fail2ban_install || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
