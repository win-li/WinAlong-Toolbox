#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MODULE="${PROJECT_DIR}/modules/storage.sh"
BACKUP_MODULE="${PROJECT_DIR}/modules/backup.sh"

required_functions=(
    wat_storage_validate_config wat_storage_archive_name_valid wat_storage_archive_valid
    wat_storage_backup_space_ok wat_storage_health wat_storage_verify_all
    wat_storage_cleanup_preview wat_storage_cleanup_purge
)
for function_name in "${required_functions[@]}"; do
    grep -Eq "^${function_name}\\(\\)" "$MODULE" || {
        printf '备份生命周期模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    }
done
grep -Fq "请输入 PURGE" "$MODULE" || { printf '旧备份清理缺少完整确认词。\n' >&2; exit 1; }
grep -Fq "! -L \$file" "$MODULE" || { printf '旧备份清理缺少符号链接拒绝检查。\n' >&2; exit 1; }
grep -Fq 'realpath -e' "$MODULE" || { printf '旧备份清理缺少规范路径检查。\n' >&2; exit 1; }
grep -Fq 'wat_storage_backup_space_ok' "$BACKUP_MODULE" || {
    printf '创建备份前缺少磁盘余量检查。\n' >&2
    exit 1
}
if grep -Eq 'find[^;]*(--delete|-delete)|rm[[:space:]]+-rf|wat_storage_cleanup_purge.*scheduled' "$MODULE"; then
    printf '备份生命周期模块包含自动或递归清理风险。\n' >&2
    exit 1
fi

temp_dir=$(mktemp -d)
cleanup() {
    rm -rf -- "$temp_dir"
}
trap cleanup EXIT

# shellcheck source=modules/storage.sh
. "$MODULE"
wat_backup_app_dir() {
    printf '%s/apps' "$temp_dir"
}
WAT_BACKUP_DIR=$temp_dir
WAT_BACKUP_KEEP_COUNT=3
WAT_BACKUP_MIN_KEEP_COUNT=2
WAT_BACKUP_STALE_HOURS=48
WAT_BACKUP_MIN_FREE_PERCENT=1
mkdir -p "$temp_dir/apps/content"
printf 'ok\n' >"$temp_dir/apps/content/index.html"
for sequence in 1 2 3 4 5; do
    archive="${temp_dir}/apps/nginx-2026070${sequence}-120000-manual-${sequence}.tar.gz"
    tar -czf "$archive" -C "$temp_dir/apps/content" .
    touch -t "2026070${sequence}1200.00" "$archive"
done
wat_storage_archive_valid "${temp_dir}/apps/nginx-20260705-120000-manual-5.tar.gz"
printf 'broken\n' >"${temp_dir}/apps/uptime-20260705-120000-manual-9.tar.gz"
if wat_storage_archive_valid "${temp_dir}/apps/uptime-20260705-120000-manual-9.tar.gz"; then
    printf '损坏归档被错误接受。\n' >&2
    exit 1
fi
ln -s "${temp_dir}/apps/nginx-20260705-120000-manual-5.tar.gz" \
    "${temp_dir}/apps/nginx-20260706-120000-manual-6.tar.gz"
if [[ -L ${temp_dir}/apps/nginx-20260706-120000-manual-6.tar.gz ]] && \
    wat_storage_archive_valid "${temp_dir}/apps/nginx-20260706-120000-manual-6.tar.gz"; then
    printf '符号链接归档被错误接受。\n' >&2
    exit 1
fi
if [[ ! -L ${temp_dir}/apps/nginx-20260706-120000-manual-6.tar.gz ]]; then
    rm -f -- "${temp_dir}/apps/nginx-20260706-120000-manual-6.tar.gz"
fi
candidate_count=$(wat_storage_cleanup_candidates nginx 3 | awk 'NF {count++} END {print count+0}')
if [[ $candidate_count != '2' ]]; then
    printf '保留策略候选数量错误：%s\n' "$candidate_count" >&2
    exit 1
fi
printf '备份生命周期静态安全测试通过。\n'
