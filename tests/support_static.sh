#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MODULE="${PROJECT_DIR}/modules/support.sh"

grep -Eq '^wat_support_bundle_create\(\)' "$MODULE" || { printf '缺少支持包入口。\n' >&2; exit 1; }
for required in diagnostic-report.txt backup-health.txt manifest.txt SHA256SUMS; do
    grep -Fq "$required" "$MODULE" || { printf '支持包缺少内容：%s\n' "$required" >&2; exit 1; }
done
grep -Fq "chmod 0600 \"\$archive\"" "$MODULE" || { printf '支持包权限不明确。\n' >&2; exit 1; }
if grep -Eq 'docker[[:space:]]+(inspect|logs)|cat[[:space:]].*WAT_LOG_FILE|/etc/ssh|config/local\.conf|printenv|env[[:space:]]*>' "$MODULE"; then
    printf '支持包模块包含敏感数据采集命令。\n' >&2
    exit 1
fi
printf '脱敏支持包静态安全测试通过。\n'
