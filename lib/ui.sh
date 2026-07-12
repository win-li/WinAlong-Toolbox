#!/usr/bin/env bash
set -Eeuo pipefail

wat_ui_title() {
    local title=${1:-${WAT_PROJECT_NAME:-WinAlong Toolbox}}
    printf '\033[2J\033[H'
    printf '%s\n' '=========================================='
    printf '  %s  v%s\n' "$title" "${WAT_VERSION:-unknown}"
    printf '%s\n\n' '=========================================='
}

wat_ui_menu() {
    local item
    for item in "$@"; do
        printf '%s\n' "$item"
    done
    printf '\n'
}

wat_ui_info() {
    printf '[信息] %s\n' "$*"
}

wat_ui_success() {
    printf '[完成] %s\n' "$*"
}

wat_ui_warn() {
    printf '[警告] %s\n' "$*" >&2
}

wat_ui_error() {
    printf '[错误] %s\n' "$*" >&2
}
