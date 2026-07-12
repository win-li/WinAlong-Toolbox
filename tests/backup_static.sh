#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BACKUP_MODULE="${PROJECT_DIR}/modules/backup.sh"

required_functions=(
    wat_backup_snapshot wat_backup_create wat_backup_list wat_backup_verify_archive
    wat_backup_extract_archive wat_backup_restore_latest wat_backup_menu
)

for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$BACKUP_MODULE"; then
        printf '备份模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq 'docker[[:space:]]+volume[[:space:]]+rm|docker[[:space:]]+system[[:space:]]+prune' "$BACKUP_MODULE"; then
    printf '备份模块包含未授权的数据卷删除或系统清理。\n' >&2
    exit 1
fi
if ! grep -Fq "请输入 RESTORE 确认恢复" "$BACKUP_MODULE"; then
    printf '恢复操作缺少 RESTORE 确认短语。\n' >&2
    exit 1
fi
if ! grep -Fq '/target/* /target/.[!.]* /target/..?*' "$BACKUP_MODULE"; then
    printf '恢复清理未限制在临时容器的 /target 挂载点。\n' >&2
    exit 1
fi

printf '备份恢复静态安全测试通过。\n'
