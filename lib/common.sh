#!/usr/bin/env bash
set -Eeuo pipefail

# Return success when running as root; optionally print a helpful error.
wat_require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        printf '错误：此操作需要 root 权限，请使用 sudo。\n' >&2
        return 1
    fi
}

wat_pause() {
    printf '\n'
    read -r -p '按 Enter 键返回...' _wat_unused
}

wat_confirm() {
    local prompt=${1:-'确定继续吗？'}
    local answer
    read -r -p "${prompt} [y/N] " answer
    [[ ${answer,,} == 'y' || ${answer,,} == 'yes' ]]
}

wat_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Populate stable OS variables from os-release.
wat_detect_system() {
    WAT_OS_ID='unknown'
    WAT_OS_VERSION='unknown'
    WAT_OS_NAME='Unknown Linux'

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        WAT_OS_ID=${ID:-unknown}
        WAT_OS_VERSION=${VERSION_ID:-unknown}
        WAT_OS_NAME=${PRETTY_NAME:-${NAME:-Unknown Linux}}
    fi

    export WAT_OS_ID WAT_OS_VERSION WAT_OS_NAME
}

# Initialize logging. If the configured system directory is not writable,
# use a per-user state directory so read-only checks still work without sudo.
wat_log_init() {
    local preferred_dir=${WAT_LOG_DIR:-/var/log/winalong-toolbox}
    local fallback_dir=${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/winalong-toolbox

    if mkdir -p "$preferred_dir" 2>/dev/null && [[ -w $preferred_dir ]]; then
        WAT_ACTIVE_LOG_DIR=$preferred_dir
    else
        mkdir -p "$fallback_dir"
        WAT_ACTIVE_LOG_DIR=$fallback_dir
    fi

    WAT_LOG_FILE="${WAT_ACTIVE_LOG_DIR}/winalong.log"
    touch "$WAT_LOG_FILE"
    export WAT_ACTIVE_LOG_DIR WAT_LOG_FILE
}

wat_log() {
    local level=${1:-INFO}
    shift || true
    local message=${*:-}
    [[ -n ${WAT_LOG_FILE:-} ]] || wat_log_init
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >>"$WAT_LOG_FILE"
}
