#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LOGS_MODULE="${PROJECT_DIR}/modules/logs.sh"

for function_name in wat_logs_validate_limit wat_logs_toolbox wat_logs_recent_errors \
    wat_logs_container_name wat_logs_container wat_logs_latest_report wat_logs_menu; do
    if ! grep -Eq "^${function_name}\\(\\)" "$LOGS_MODULE"; then
        printf '日志模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done
if ! grep -Fq 'WAT_LOG_TAIL_LINES <= 500' "$LOGS_MODULE"; then
    printf '日志查看缺少最大行数限制。\n' >&2
    exit 1
fi
if ! grep -Fq "wat_logs_container_name \"\$choice\"" "$LOGS_MODULE"; then
    printf '容器日志没有使用固定白名单选择。\n' >&2
    exit 1
fi
if grep -Eq 'truncate|rm[[:space:]].*WAT_LOG|docker[[:space:]]+logs[[:space:]]+--follow' "$LOGS_MODULE"; then
    printf '日志模块包含清空或无限跟随操作。\n' >&2
    exit 1
fi

printf '日志中心静态安全测试通过。\n'
