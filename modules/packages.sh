#!/usr/bin/env bash
set -Eeuo pipefail

wat_packages_supported() {
    wat_detect_system
    [[ $WAT_OS_ID == 'ubuntu' || $WAT_OS_ID == 'debian' ]]
}

wat_packages_upgradable_count() {
    local output
    if ! wat_command_exists apt; then
        printf '0'
        return 0
    fi
    if ! output=$(apt list --upgradable 2>/dev/null); then
        printf '0'
        return 0
    fi
    printf '%s\n' "$output" | awk 'NR > 1 {count++} END {print count + 0}'
}

wat_packages_kept_back() {
    if ! wat_command_exists apt-get; then
        return 0
    fi
    LC_ALL=C apt-get -s upgrade 2>/dev/null | awk '
        /^The following packages have been kept back:/ {capture=1; next}
        capture && /^[[:space:]]/ {
            for (field=1; field<=NF; field++) print $field
            next
        }
        capture {capture=0}
    ' || true
}

wat_packages_latest_installed_kernel() {
    find /boot -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\n' 2>/dev/null | \
        sed 's/^vmlinuz-//' | sort -V | tail -n 1 || true
}

wat_packages_maintenance_status() {
    local upgradable kept_back kept_count running_kernel latest_kernel failed_count failed_units
    wat_ui_title '更新后维护状态'
    upgradable=$(wat_packages_upgradable_count)
    kept_back=$(wat_packages_kept_back)
    kept_count=$(printf '%s\n' "$kept_back" | awk 'NF {count++} END {print count + 0}')
    running_kernel=$(uname -r)
    latest_kernel=$(wat_packages_latest_installed_kernel)
    failed_count=0
    if wat_command_exists systemctl; then
        failed_units=$(systemctl --failed --no-legend --no-pager 2>/dev/null || true)
        failed_count=$(printf '%s\n' "$failed_units" | \
            awk 'NF {count++} END {print count + 0}')
    fi

    printf '可升级软件包：%s\n' "$upgradable"
    printf '暂缓软件包：%s\n' "$kept_count"
    if [[ -n $kept_back ]]; then
        printf '%s\n' "$kept_back" | sed 's/^/  - /'
    fi
    printf '运行内核：%s\n' "$running_kernel"
    printf '最新已安装内核：%s\n' "${latest_kernel:-未知}"
    printf '失败的 systemd 单元：%s\n' "$failed_count"
    if [[ -e /var/run/reboot-required ]]; then
        wat_ui_warn '系统标记为需要重启。'
        if [[ -r /var/run/reboot-required.pkgs ]]; then
            printf '%s\n' '触发重启提示的软件包：'
            sed 's/^/  - /' /var/run/reboot-required.pkgs
        fi
    elif [[ -n $latest_kernel && $running_kernel != "$latest_kernel" ]]; then
        wat_ui_warn '运行内核不是最新已安装内核，建议在维护窗口重启。'
    else
        wat_ui_success '当前没有检测到重启要求。'
    fi
    wat_log INFO "查看更新后维护状态：upgradable=${upgradable} kept=${kept_count} failed=${failed_count}"
}

wat_packages_show_updates() {
    wat_ui_title '软件包更新检查'
    if ! wat_packages_supported; then
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    fi
    if ! wat_command_exists apt-get || ! wat_command_exists apt; then
        wat_ui_error '未找到 apt/apt-get。'
        return 1
    fi

    wat_ui_info '正在刷新软件包索引，此操作需要 root 权限。'
    wat_require_root || return 1
    apt-get update
    printf '\n%s\n' '可升级软件包：'
    apt list --upgradable 2>/dev/null || true
    wat_log INFO '刷新软件包索引并列出可升级软件包'
}

wat_packages_upgrade() {
    wat_ui_title '安装软件包更新'
    if ! wat_packages_supported; then
        wat_ui_error "当前系统暂不支持：${WAT_OS_NAME}"
        return 1
    fi
    wat_require_root || return 1
    wat_ui_warn '此操作会更新已安装的软件包，但不会执行发行版升级。'
    if ! wat_confirm '确定刷新索引并安装常规更新吗？'; then
        wat_ui_info '操作已取消。'
        wat_log INFO '用户取消软件包更新'
        return 0
    fi

    wat_log INFO '开始安装软件包更新'
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    wat_log INFO '软件包更新完成'
    wat_ui_success '软件包更新完成。若更新了内核，请择机重启服务器。'
}
