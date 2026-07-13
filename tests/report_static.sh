#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REPORT_MODULE="${PROJECT_DIR}/modules/report.sh"

for function_name in wat_report_package_counts wat_report_docker_status \
    wat_report_security_status wat_report_failed_units wat_report_log_summary \
    wat_report_generate; do
    if ! grep -Eq "^${function_name}\\(\\)" "$REPORT_MODULE"; then
        printf '诊断报告模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done
if ! grep -Fq 'install -o root -g root -m 0600' "$REPORT_MODULE"; then
    printf '诊断报告没有强制使用 0600 权限。\n' >&2
    exit 1
fi
if grep -Eq '(^|[[:space:]])(env|printenv|hostname|ifconfig)([[:space:]]|$)|ip[[:space:]]+(addr|address)|/etc/(shadow|ssh)|\.env' \
    "$REPORT_MODULE"; then
    printf '诊断报告包含禁止采集的敏感来源。\n' >&2
    exit 1
fi
if grep -Eq 'docker[[:space:]]+(inspect|logs)|ufw[[:space:]]+status[[:space:]]+verbose' "$REPORT_MODULE"; then
    printf '诊断报告包含可能泄露配置或原始日志的命令。\n' >&2
    exit 1
fi

printf '诊断报告静态安全测试通过。\n'
