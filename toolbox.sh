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
# shellcheck source=config/maintenance.conf
. "${WAT_ROOT_DIR}/config/maintenance.conf"
# shellcheck source=config/storage.conf
. "${WAT_ROOT_DIR}/config/storage.conf"
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
# shellcheck source=modules/storage.sh
. "${WAT_ROOT_DIR}/modules/storage.sh"
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
# shellcheck source=modules/scheduler.sh
. "${WAT_ROOT_DIR}/modules/scheduler.sh"
# shellcheck source=modules/report.sh
. "${WAT_ROOT_DIR}/modules/report.sh"
# shellcheck source=modules/config_snapshot.sh
. "${WAT_ROOT_DIR}/modules/config_snapshot.sh"
# shellcheck source=modules/support.sh
. "${WAT_ROOT_DIR}/modules/support.sh"
# shellcheck source=modules/logs.sh
. "${WAT_ROOT_DIR}/modules/logs.sh"

wat_usage() {
    printf '%s\n' "${WAT_PROJECT_NAME} v${WAT_VERSION}"
    printf '%s\n' '用法：winalong [--doctor|--maintenance|--report|--backup-run|--backup-schedule|--backup-health|--backup-verify|--config-snapshot|--support-bundle|--version|--help]'
    printf '%s\n' '  --doctor   运行只读 VPS 健康体检'
    printf '%s\n' '  --maintenance  查看只读更新后维护状态'
    printf '%s\n' '  --report   生成脱敏诊断报告（需要 root）'
    printf '%s\n' '  --backup-run  立即执行已部署应用备份（需要 root）'
    printf '%s\n' '  --backup-schedule  管理自动备份计划'
    printf '%s\n' '  --backup-health  查看备份健康与磁盘余量（需要 root）'
    printf '%s\n' '  --backup-verify  校验全部标准备份并生成 SHA-256 清单（需要 root）'
    printf '%s\n' '  --config-snapshot  创建固定允许清单的托管配置快照（需要 root）'
    printf '%s\n' '  --support-bundle  生成脱敏诊断支持包（需要 root）'
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
        --report) wat_report_generate || return 1; return 0 ;;
        --backup-run) wat_backup_run_all || return 1; return 0 ;;
        --backup-schedule) wat_scheduler_menu; return 0 ;;
        --backup-health) wat_storage_health || return 1; return 0 ;;
        --backup-verify) wat_storage_verify_all || return 1; return 0 ;;
        --config-snapshot) wat_config_snapshot_create || return 1; return 0 ;;
        --support-bundle) wat_support_bundle_create || return 1; return 0 ;;
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
            '11. 日志与诊断' \
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
            11) wat_logs_menu ;;
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
