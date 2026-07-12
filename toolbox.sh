#!/usr/bin/env bash
set -Eeuo pipefail

WAT_ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=config/default.conf
. "${WAT_ROOT_DIR}/config/default.conf"
if [[ -r ${WAT_ROOT_DIR}/config/local.conf ]]; then
    # shellcheck source=/dev/null
    . "${WAT_ROOT_DIR}/config/local.conf"
fi
# shellcheck source=lib/common.sh
. "${WAT_ROOT_DIR}/lib/common.sh"
# shellcheck source=lib/ui.sh
. "${WAT_ROOT_DIR}/lib/ui.sh"
# shellcheck source=modules/system.sh
. "${WAT_ROOT_DIR}/modules/system.sh"

wat_main() {
    local choice
    wat_log_init
    wat_log INFO "启动 ${WAT_PROJECT_NAME} v${WAT_VERSION}"

    while true; do
        wat_ui_title
        wat_ui_menu \
            '1. 系统检查' \
            '0. 退出'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_system_menu ;;
            0)
                wat_log INFO '正常退出'
                wat_ui_success '已退出。'
                return 0
                ;;
            *) wat_ui_warn '无效选项，请重新输入。'; sleep 1 ;;
        esac
    done
}

wat_main "$@"
