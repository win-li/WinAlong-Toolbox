#!/usr/bin/env bash
set -Eeuo pipefail

wat_doctor_reset() {
    WAT_DOCTOR_SCORE=0
    WAT_DOCTOR_MAX_SCORE=0
    WAT_DOCTOR_RECOMMENDATIONS=()
}

wat_doctor_result() {
    local label=$1 state=$2 score=$3 maximum=$4 recommendation=${5:-}
    WAT_DOCTOR_SCORE=$((WAT_DOCTOR_SCORE + score))
    WAT_DOCTOR_MAX_SCORE=$((WAT_DOCTOR_MAX_SCORE + maximum))
    printf '%-20s  %-8s  %2d/%2d\n' "$label" "$state" "$score" "$maximum"
    if [[ -n $recommendation ]]; then
        WAT_DOCTOR_RECOMMENDATIONS+=("$recommendation")
    fi
}

wat_doctor_check_os() {
    wat_detect_system
    case "${WAT_OS_ID}:${WAT_OS_VERSION}" in
        ubuntu:22.04|ubuntu:24.04|debian:12)
            wat_doctor_result '支持系统' '正常' 10 10
            ;;
        *)
            wat_doctor_result '支持系统' '注意' 0 10 \
                "当前 ${WAT_OS_NAME} 未列入正式支持范围。"
            ;;
    esac
}

wat_doctor_check_disk() {
    local used
    used=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
    if [[ $used =~ ^[0-9]+$ ]] && ((used < WAT_DOCTOR_DISK_WARN_PERCENT)); then
        wat_doctor_result "根磁盘 ${used}%" '正常' 15 15
    else
        wat_doctor_result "根磁盘 ${used:-未知}%" '警告' 0 15 \
            "清理磁盘并将根分区使用率降到 ${WAT_DOCTOR_DISK_WARN_PERCENT}% 以下。"
    fi
}

wat_doctor_check_memory() {
    local total available percent
    total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    if [[ $total =~ ^[0-9]+$ && $available =~ ^[0-9]+$ && $total -gt 0 ]]; then
        percent=$((available * 100 / total))
    else
        percent=0
    fi
    if ((percent >= WAT_DOCTOR_MEMORY_WARN_PERCENT)); then
        wat_doctor_result "可用内存 ${percent}%" '正常' 15 15
    else
        wat_doctor_result "可用内存 ${percent}%" '警告' 0 15 \
            "检查高内存进程；建议保持至少 ${WAT_DOCTOR_MEMORY_WARN_PERCENT}% 可用内存。"
    fi
}

wat_doctor_check_load() {
    local load cpu percent
    read -r load _ </proc/loadavg
    cpu=$(nproc 2>/dev/null || printf '1')
    percent=$(awk -v load_value="$load" -v cpu_count="$cpu" \
        'BEGIN {printf "%d", (load_value * 100) / cpu_count}')
    if ((percent < WAT_DOCTOR_LOAD_WARN_PERCENT)); then
        wat_doctor_result "1m 负载 ${load}" '正常' 10 10
    else
        wat_doctor_result "1m 负载 ${load}" '警告' 0 10 \
            "持续观察 CPU 负载；当前已达到约 ${percent}% 的 CPU 容量。"
    fi
}

wat_doctor_check_time() {
    local synchronized='no'
    if wat_command_exists timedatectl; then
        synchronized=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || printf 'no')
    fi
    if [[ $synchronized == 'yes' ]]; then
        wat_doctor_result '时间同步' '正常' 10 10
    else
        wat_doctor_result '时间同步' '警告' 0 10 '在系统管理中启用并确认时间同步。'
    fi
}

wat_doctor_check_updates() {
    local count kept_back kept_count
    count=$(wat_packages_upgradable_count)
    kept_back=$(wat_packages_kept_back)
    kept_count=$(printf '%s\n' "$kept_back" | awk 'NF {count++} END {print count + 0}')
    if ((kept_count > 0)); then
        wat_doctor_result "更新 ${count}/暂缓 ${kept_count}" '注意' 2 5 \
            '存在暂缓软件包；请先查看更新后维护状态，不要直接执行发行版升级。'
    elif ((count == 0)); then
        wat_doctor_result '待更新 0' '正常' 5 5
    elif ((count <= WAT_DOCTOR_UPDATES_WARN_COUNT)); then
        wat_doctor_result "待更新 ${count}" '注意' 4 5 \
            '存在少量常规更新，可在备份后择机处理。'
    else
        wat_doctor_result "待更新 ${count}" '注意' 2 5 \
            '先备份重要数据，再通过系统管理安装软件包更新。'
    fi
}

wat_doctor_check_reboot() {
    local running_kernel latest_kernel
    running_kernel=$(uname -r)
    latest_kernel=$(wat_packages_latest_installed_kernel)
    if [[ -e /var/run/reboot-required ]]; then
        wat_doctor_result '需要重启' '注意' 0 5 '在维护窗口重启，并验证 SSH、Docker 和安全服务。'
    elif [[ -n $latest_kernel && $running_kernel != "$latest_kernel" ]]; then
        wat_doctor_result '内核待切换' '注意' 0 5 \
            "当前 ${running_kernel}，最新已安装 ${latest_kernel}；建议维护窗口重启。"
    else
        wat_doctor_result '重启状态' '正常' 5 5
    fi
}

wat_doctor_check_ufw() {
    local status='inactive'
    if wat_command_exists ufw; then
        status=$(ufw status 2>/dev/null | \
            awk 'NR == 1 {print tolower($2)}' || printf 'inactive')
    fi
    if [[ $status == 'active' ]]; then
        wat_doctor_result 'UFW 防火墙' '正常' 10 10
    else
        wat_doctor_result 'UFW 防火墙' '注意' 0 10 \
            '确认云防火墙与 SSH 连接后，可在安全中心谨慎启用 UFW。'
    fi
}

wat_doctor_check_fail2ban() {
    if wat_command_exists systemctl && systemctl is-active --quiet fail2ban; then
        wat_doctor_result 'Fail2ban' '正常' 10 10
    else
        wat_doctor_result 'Fail2ban' '注意' 0 10 '可在安全中心安装 Fail2ban SSH 防护。'
    fi
}

wat_doctor_check_bbr() {
    local congestion='unknown'
    if wat_command_exists sysctl; then
        congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')
    fi
    if [[ $congestion == 'bbr' ]]; then
        wat_doctor_result 'BBR/fq' '正常' 10 10
    else
        wat_doctor_result "拥塞控制 ${congestion}" '注意' 0 10 \
            '可在网络中心查看 BBR 支持情况，再决定是否启用。'
    fi
}

wat_doctor_grade() {
    local score=$1
    if ((score >= 90)); then
        printf '优秀'
    elif ((score >= 75)); then
        printf '良好'
    elif ((score >= 60)); then
        printf '一般'
    else
        printf '需改进'
    fi
}

wat_doctor_runtime_summary() {
    local running_count unhealthy_count running_ids unhealthy_ids
    printf '\n%s\n' '运行状态：'
    if wat_command_exists docker && systemctl is-active --quiet docker 2>/dev/null; then
        if running_ids=$(docker ps -q 2>/dev/null) && \
            unhealthy_ids=$(docker ps --filter health=unhealthy -q 2>/dev/null); then
            running_count=$(printf '%s\n' "$running_ids" | \
                awk 'NF {count++} END {print count + 0}')
            unhealthy_count=$(printf '%s\n' "$unhealthy_ids" | \
                awk 'NF {count++} END {print count + 0}')
        else
            running_count='未知'
            unhealthy_count='未知'
        fi
        printf 'Docker：运行中；容器：%s 个，异常健康状态：%s 个\n' \
            "$running_count" "$unhealthy_count"
    else
        printf '%s\n' 'Docker：未运行或未安装（不计入评分）'
    fi
    printf '工具版本：%s；日志：%s\n' "$WAT_VERSION" "${WAT_LOG_FILE:-未初始化}"
}

wat_doctor_report() {
    local final_score grade recommendation
    wat_ui_title 'VPS 健康体检'
    wat_doctor_reset
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        wat_ui_warn '普通用户可能无法读取 UFW 和 Docker 的完整状态；建议使用 sudo winalong --doctor。'
    fi
    printf '%-20s  %-8s  %s\n' '检查项' '状态' '得分'
    printf '%s\n' '------------------------------------------------'
    wat_doctor_check_os
    wat_doctor_check_disk
    wat_doctor_check_memory
    wat_doctor_check_load
    wat_doctor_check_time
    wat_doctor_check_updates
    wat_doctor_check_reboot
    wat_doctor_check_ufw
    wat_doctor_check_fail2ban
    wat_doctor_check_bbr
    final_score=$((WAT_DOCTOR_SCORE * 100 / WAT_DOCTOR_MAX_SCORE))
    grade=$(wat_doctor_grade "$final_score")
    printf '\n综合评分：%d/100（%s）\n' "$final_score" "$grade"
    wat_doctor_runtime_summary
    if ((${#WAT_DOCTOR_RECOMMENDATIONS[@]} > 0)); then
        printf '\n%s\n' '建议：'
        for recommendation in "${WAT_DOCTOR_RECOMMENDATIONS[@]}"; do
            printf -- '- %s\n' "$recommendation"
        done
    else
        wat_ui_success '未发现需要处理的项目。'
    fi
    wat_log INFO "健康体检完成：${final_score}/100 ${grade}"
}
