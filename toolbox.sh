#!/usr/bin/env bash
set -Eeuo pipefail

WAT_ENTRYPOINT=$(readlink -f -- "${BASH_SOURCE[0]}")
WAT_ROOT_DIR=$(cd -- "$(dirname -- "$WAT_ENTRYPOINT")" && pwd)
readonly WAT_ENTRYPOINT WAT_ROOT_DIR

# shellcheck source=config/default.conf
. "${WAT_ROOT_DIR}/config/default.conf"
# shellcheck source=config/apps.conf
. "${WAT_ROOT_DIR}/config/apps.conf"
# shellcheck source=config/security.conf
. "${WAT_ROOT_DIR}/config/security.conf"
# shellcheck source=config/network.conf
. "${WAT_ROOT_DIR}/config/network.conf"
# shellcheck source=config/update.conf
. "${WAT_ROOT_DIR}/config/update.conf"
# shellcheck source=config/doctor.conf
. "${WAT_ROOT_DIR}/config/doctor.conf"
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
# shellcheck source=modules/apps.sh
. "${WAT_ROOT_DIR}/modules/apps.sh"
# shellcheck source=modules/backup.sh
. "${WAT_ROOT_DIR}/modules/backup.sh"
# shellcheck source=modules/security.sh
. "${WAT_ROOT_DIR}/modules/security.sh"
# shellcheck source=modules/network.sh
. "${WAT_ROOT_DIR}/modules/network.sh"
# shellcheck source=modules/update.sh
. "${WAT_ROOT_DIR}/modules/update.sh"
# shellcheck source=modules/plugins.sh
. "${WAT_ROOT_DIR}/modules/plugins.sh"
# shellcheck source=modules/doctor.sh
. "${WAT_ROOT_DIR}/modules/doctor.sh"

wat_usage() {
    printf '%s\n' "${WAT_PROJECT_NAME} v${WAT_VERSION}"
    printf '%s\n' '用法：winalong [--doctor|--maintenance|--version|--help]'
    printf '%s\n' '  --doctor   运行只读 VPS 健康体检'
    printf '%s\n' '  --maintenance  查看只读更新后维护状态'
    printf '%s\n' '  --version  显示版本号'
    printf '%s\n' '  --help     显示帮助'
}

wat_main() {
    local choice
    wat_log_init
    wat_log INFO "启动 ${WAT_PROJECT_NAME} v${WAT_VERSION}"

    case "${1:-}" in
        '') ;;
        --doctor) wat_doctor_report; return 0 ;;
        --maintenance) wat_packages_maintenance_status; return 0 ;;
        --version) printf '%s\n' "$WAT_VERSION"; return 0 ;;
        --help|-h) wat_usage; return 0 ;;
        *) wat_ui_error "未知参数：$1"; wat_usage >&2; return 2 ;;
    esac

    while true; do
        wat_ui_title
        wat_ui_menu \
            '1. 系统管理' \
            '2. Docker 管理' \
            '3. Portainer 管理' \
            '4. Docker 应用中心' \
            '5. 应用网络与备份' \
            '6. 安全中心' \
            '7. 网络诊断与 BBR' \
            '8. 在线更新' \
            '9. 插件中心' \
            '10. VPS 健康体检' \
            '0. 退出'
        read -r -p '请输入菜单编号：' choice
        case "$choice" in
            1) wat_system_menu ;;
            2) wat_docker_menu ;;
            3) wat_portainer_menu ;;
            4) wat_apps_menu ;;
            5) wat_backup_menu ;;
            6) wat_security_menu ;;
            7) wat_network_menu ;;
            8) wat_update_menu ;;
            9) wat_plugins_menu ;;
            10) wat_doctor_report; wat_pause ;;
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
