#!/usr/bin/env bash
set -Eeuo pipefail

wat_swap_size_valid() {
    [[ $1 =~ ^[1-9][0-9]*[MG]$ ]]
}

wat_swap_create() {
    local swap_file=${WAT_SWAP_FILE:-/swapfile}
    local swap_size=${WAT_SWAP_SIZE:-2G}

    wat_ui_title '创建 Swap'
    wat_require_root || return 1

    if ! wat_swap_size_valid "$swap_size"; then
        wat_ui_error "Swap 大小格式无效：${swap_size}（示例：512M、2G）"
        return 1
    fi
    if swapon --show=NAME --noheadings 2>/dev/null | awk '{$1=$1};1' | grep -Fxq -- "$swap_file"; then
        wat_ui_info "${swap_file} 已经启用，无需重复创建。"
        return 0
    fi
    if [[ -e $swap_file ]]; then
        wat_ui_error "${swap_file} 已存在但未启用。为避免覆盖，请人工检查。"
        return 1
    fi

    wat_ui_warn "将创建 ${swap_size} Swap 文件：${swap_file}"
    if ! wat_confirm '确定创建并设置为开机自动启用吗？'; then
        wat_ui_info '操作已取消。'
        return 0
    fi

    wat_log INFO "开始创建 Swap：${swap_file} ${swap_size}"
    if wat_command_exists fallocate; then
        fallocate -l "$swap_size" "$swap_file"
    else
        wat_ui_error '未找到 fallocate，未对磁盘进行修改。'
        return 1
    fi

    chmod 600 "$swap_file"
    if ! mkswap "$swap_file" || ! swapon "$swap_file"; then
        swapoff "$swap_file" 2>/dev/null || true
        rm -f -- "$swap_file"
        wat_log ERROR 'Swap 创建失败，已清理未完成文件'
        wat_ui_error 'Swap 创建失败，未完成文件已清理。'
        return 1
    fi

    if ! grep -Fqs -- "${swap_file} none swap sw 0 0" /etc/fstab; then
        if ! printf '%s none swap sw 0 0\n' "$swap_file" >>/etc/fstab; then
            swapoff "$swap_file" 2>/dev/null || true
            rm -f -- "$swap_file"
            wat_log ERROR '无法写入 /etc/fstab，已回滚 Swap 文件'
            wat_ui_error '无法设置开机自动启用，已回滚本次操作。'
            return 1
        fi
    fi
    wat_log INFO "Swap 创建完成：${swap_file} ${swap_size}"
    wat_ui_success 'Swap 创建并启用成功。'
    swapon --show
}
