#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCHEDULER_MODULE="${PROJECT_DIR}/modules/scheduler.sh"
BACKUP_MODULE="${PROJECT_DIR}/modules/backup.sh"

for function_name in wat_scheduler_service_path wat_scheduler_timer_path \
    wat_scheduler_validate wat_scheduler_status wat_scheduler_enable \
    wat_scheduler_disable wat_scheduler_menu; do
    if ! grep -Eq "^${function_name}\\(\\)" "$SCHEDULER_MODULE"; then
        printf '自动备份模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done
if ! grep -Fq "WAT_BACKUP_SERVICE == 'winalong-backup.service'" "$SCHEDULER_MODULE" || \
    ! grep -Fq "WAT_BACKUP_TIMER == 'winalong-backup.timer'" "$SCHEDULER_MODULE" || \
    ! grep -Fq "WAT_BIN_LINK == '/usr/local/bin/winalong'" "$SCHEDULER_MODULE"; then
    printf '自动备份单元名称或执行路径没有固定保护。\n' >&2
    exit 1
fi
for required_text in '请输入 ENABLE 确认启用自动备份' \
    '请输入 DISABLE 确认停用自动备份' 'Persistent=true' \
    'UMask=0077' "ExecStart=\${WAT_BIN_LINK} --backup-run"; do
    if ! grep -Fq "$required_text" "$SCHEDULER_MODULE"; then
        printf '自动备份缺少安全要求：%s\n' "$required_text" >&2
        exit 1
    fi
done
if grep -Eq 'rm[[:space:]].*(WAT_BACKUP_DIR|\.tar\.gz)|find.*-delete' \
    "$SCHEDULER_MODULE"; then
    printf '自动备份模块包含历史备份删除操作。\n' >&2
    exit 1
fi
if ! grep -Fq 'config/maintenance.conf' "${PROJECT_DIR}/install.sh"; then
    printf '安装器没有复制自动备份配置。\n' >&2
    exit 1
fi
if ! grep -Fq 'winalong-backup.timer' "${PROJECT_DIR}/uninstall.sh" || \
    ! grep -Fq 'winalong-backup.service' "${PROJECT_DIR}/uninstall.sh"; then
    printf '卸载器没有清理项目拥有的 systemd 单元。\n' >&2
    exit 1
fi
if ! grep -Eq '^wat_backup_run_all\(\)' "$BACKUP_MODULE" || \
    ! grep -Fq 'for app_id in nginx uptime' "$BACKUP_MODULE"; then
    printf '无交互备份入口没有使用固定应用白名单。\n' >&2
    exit 1
fi

printf '自动备份计划静态安全测试通过。\n'
