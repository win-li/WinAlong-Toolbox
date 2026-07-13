#!/usr/bin/env bash
set -Eeuo pipefail

wat_network_summary() {
    wat_ui_title '网络概况'
    printf '%s\n' '网络接口：'
    ip -brief address
    printf '\n%s\n' 'IPv4 路由：'
    ip -4 route
    printf '\n%s\n' 'IPv6 路由：'
    ip -6 route || true
    printf '\n%s\n' 'DNS 配置：'
    if wat_command_exists resolvectl; then
        resolvectl status
    else
        cat /etc/resolv.conf
    fi
    wat_log INFO '查看网络概况'
}

wat_network_connectivity() {
    local target
    local -a targets
    wat_ui_title '连通性与 DNS 测试'
    if ! wat_command_exists ping; then
        wat_ui_error '未找到 ping，请先安装网络诊断工具。'
        return 1
    fi
    read -r -a targets <<<"$WAT_PING_TARGETS"
    for target in "${targets[@]}"; do
        printf '\n--- %s ---\n' "$target"
        if ! ping -c 4 -W 2 "$target"; then
            wat_ui_warn "${target} 测试失败或丢包。"
        fi
    done
    printf '\n%s\n' 'DNS 解析结果：'
    getent ahosts github.com | head -n 6 || true
    wat_log INFO '完成网络连通性测试'
}

wat_network_route_test() {
    wat_ui_title '路由质量测试'
    if wat_command_exists mtr; then
        mtr --report --report-cycles 10 --no-dns "$WAT_TRACE_TARGET" || true
    elif wat_command_exists traceroute; then
        traceroute -n -m 20 -w 2 "$WAT_TRACE_TARGET" || true
    else
        wat_ui_error '未找到 mtr 或 traceroute，请先安装网络诊断工具。'
        return 1
    fi
    wat_log INFO "完成路由测试：${WAT_TRACE_TARGET}"
}

wat_network_install_tools() {
    wat_ui_title '安装网络诊断工具'
    wat_require_root || return 1
    if ! wat_confirm '确定安装 ping、DNS、Traceroute 和 MTR 工具吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi
    apt-get update
    apt-get install -y iproute2 iputils-ping dnsutils traceroute mtr-tiny curl
    wat_log INFO '网络诊断工具安装完成'
    wat_ui_success '网络诊断工具安装完成。'
}

wat_network_speed_test() {
    local speed_bps speed_mbps
    wat_ui_title '限量下载测速'
    if ! wat_command_exists curl; then
        wat_ui_error '未找到 curl，请先安装网络诊断工具。'
        return 1
    fi
    wat_ui_warn "本次测试最多下载 ${WAT_SPEED_BYTES} 字节（约 25 MB）。"
    wat_ui_warn '测速请求会向 Cloudflare 暴露服务器出口 IP。'
    if ! wat_confirm '确定开始下载测速吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    speed_bps=$(curl --fail --location --max-time 60 --output /dev/null \
        --silent --show-error --write-out '%{speed_download}' "$WAT_SPEED_URL") || {
        wat_ui_error '测速请求失败。'
        return 1
    }
    speed_mbps=$(awk -v speed="$speed_bps" 'BEGIN {printf "%.2f", speed * 8 / 1000000}')
    printf '平均下载速度：%s Mbps\n' "$speed_mbps"
    wat_log INFO "Cloudflare 限量测速：${speed_mbps} Mbps"
}

wat_network_bbr_status() {
    local current available qdisc module_state='未加载' persistent='不存在'
    wat_ui_title 'BBR 详细状态'
    current=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')
    available=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || printf 'unknown')
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || printf 'unknown')
    if lsmod | awk '$1 == "tcp_bbr" {found=1} END {exit !found}'; then
        module_state='已加载'
    fi
    if [[ -f $WAT_BBR_SYSCTL_FILE ]]; then
        persistent='存在'
    fi
    printf '当前拥塞控制：%s\n' "$current"
    printf '可用拥塞控制：%s\n' "$available"
    printf '默认队列算法：%s\n' "$qdisc"
    printf 'tcp_bbr 模块：%s\n' "$module_state"
    printf '持久配置：%s\n' "$persistent"
    wat_log INFO "查看 BBR 详细状态：${current} ${qdisc}"
}

wat_network_bbr_enable() {
    local previous_cc previous_qdisc available backup_dir backup_file='' temp_file answer
    wat_ui_title '启用 BBR'
    wat_require_root || return 1
    previous_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    previous_qdisc=$(sysctl -n net.core.default_qdisc)
    if [[ $previous_cc == 'bbr' && $previous_qdisc == 'fq' ]]; then
        wat_ui_info 'BBR 与 fq 已经启用。'
        return 0
    fi

    available=$(sysctl -n net.ipv4.tcp_available_congestion_control)
    if [[ $available != *bbr* ]] && ! modinfo tcp_bbr >/dev/null 2>&1; then
        wat_ui_error '当前内核没有 BBR 算法或可加载模块，未修改系统。'
        return 1
    fi
    wat_ui_warn "将把拥塞控制从 ${previous_cc} 改为 bbr，队列算法从 ${previous_qdisc} 改为 fq。"
    read -r -p '请输入 ENABLE 确认启用 BBR：' answer
    if [[ $answer != 'ENABLE' ]]; then
        wat_ui_info '输入不匹配，操作已取消。'
        return 0
    fi

    modprobe tcp_bbr 2>/dev/null || true
    available=$(sysctl -n net.ipv4.tcp_available_congestion_control)
    if [[ $available != *bbr* ]]; then
        wat_ui_error 'BBR 模块加载后仍不可用，未修改 sysctl。'
        return 1
    fi

    backup_dir="${WAT_BACKUP_DIR}/network"
    install -m 0700 -d "$backup_dir"
    if [[ -f $WAT_BBR_SYSCTL_FILE ]]; then
        backup_file="${backup_dir}/99-winalong-bbr-$(date '+%Y%m%d-%H%M%S').conf"
        cp -a -- "$WAT_BBR_SYSCTL_FILE" "$backup_file"
    fi
    temp_file=$(mktemp)
    printf '%s\n' \
        'net.core.default_qdisc = fq' \
        'net.ipv4.tcp_congestion_control = bbr' >"$temp_file"
    install -m 0644 "$temp_file" "$WAT_BBR_SYSCTL_FILE"
    rm -f -- "$temp_file"

    if ! sysctl -w net.core.default_qdisc=fq || \
        ! sysctl -w net.ipv4.tcp_congestion_control=bbr; then
        if [[ -n $backup_file ]]; then
            cp -a -- "$backup_file" "$WAT_BBR_SYSCTL_FILE"
        else
            rm -f -- "$WAT_BBR_SYSCTL_FILE"
        fi
        sysctl -w "net.core.default_qdisc=${previous_qdisc}" >/dev/null || true
        sysctl -w "net.ipv4.tcp_congestion_control=${previous_cc}" >/dev/null || true
        wat_log ERROR 'BBR 应用失败，已回滚'
        wat_ui_error 'BBR 应用失败，已恢复原设置。'
        return 1
    fi
    wat_log INFO "BBR 已启用，原设置：${previous_cc}/${previous_qdisc}"
    wat_ui_success 'BBR 与 fq 已启用，并写入独立持久配置。'
    wat_network_bbr_status
}

wat_network_menu() {
    local choice
    while true; do
        wat_ui_title '网络诊断与 BBR'
        wat_ui_menu \
            '1. 查看网络概况' \
            '2. 连通性与 DNS 测试' \
            '3. 路由质量测试' \
            '4. 安装网络诊断工具' \
            '5. 25 MB 限量下载测速' \
            '6. 查看 BBR 详细状态' \
            '7. 启用 BBR' \
            '0. 返回主菜单'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_network_summary || true; wat_pause ;;
            2) wat_network_connectivity || true; wat_pause ;;
            3) wat_network_route_test || true; wat_pause ;;
            4) wat_network_install_tools || true; wat_pause ;;
            5) wat_network_speed_test || true; wat_pause ;;
            6) wat_network_bbr_status || true; wat_pause ;;
            7) wat_network_bbr_enable || true; wat_pause ;;
            0) return 0 ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}
