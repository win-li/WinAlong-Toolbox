#!/usr/bin/env bash
set -Eeuo pipefail

WAT_ENTRYPOINT=$(readlink -f -- "${BASH_SOURCE[0]}")
WAT_ROOT_DIR=$(cd -- "$(dirname -- "$WAT_ENTRYPOINT")" && pwd)
readonly WAT_ENTRYPOINT WAT_ROOT_DIR

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
# shellcheck source=modules/packages.sh
. "${WAT_ROOT_DIR}/modules/packages.sh"
# shellcheck source=modules/time.sh
. "${WAT_ROOT_DIR}/modules/time.sh"
# shellcheck source=modules/swap.sh
. "${WAT_ROOT_DIR}/modules/swap.sh"
# shellcheck source=modules/docker.sh
. "${WAT_ROOT_DIR}/modules/docker.sh"
# shellcheck source=modules/portainer.sh
. "${WAT_ROOT_DIR}/modules/portainer.sh"

wat_main() {
    local choice
    wat_log_init
    wat_log INFO "启动 ${WAT_PROJECT_NAME} v${WAT_VERSION}"

    while true; do
        wat_ui_title
        wat_ui_menu \
            '1. 系统管理' \
            '2. Docker 管理' \
            '3. Portainer 管理' \
            '0. 退出'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_system_menu ;;
            2) wat_docker_menu ;;
            3) wat_portainer_menu ;;
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
