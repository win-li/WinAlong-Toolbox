#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR_MODULE="${PROJECT_DIR}/modules/doctor.sh"

required_functions=(
    wat_doctor_reset wat_doctor_result wat_doctor_check_os wat_doctor_check_disk
    wat_doctor_check_memory wat_doctor_check_load wat_doctor_check_time
    wat_doctor_check_updates wat_doctor_check_ufw wat_doctor_check_fail2ban
    wat_doctor_check_bbr wat_doctor_grade wat_doctor_runtime_summary wat_doctor_report
)
for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$DOCTOR_MODULE"; then
        printf '健康体检模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

if grep -Eq '^[[:space:]]*(sudo|rm|reboot|shutdown)[[:space:]]|sysctl[[:space:]]+-w|ufw[[:space:]]+(enable|disable|reset)|systemctl[[:space:]]+(start|stop|restart|enable|disable)' "$DOCTOR_MODULE"; then
    printf '健康体检模块包含禁止的系统写操作。\n' >&2
    exit 1
fi
if ! grep -Fq '综合评分：%d/100' "$DOCTOR_MODULE"; then
    printf '健康体检模块缺少百分制汇总。\n' >&2
    exit 1
fi
if ! grep -Fq 'Docker：未运行或未安装（不计入评分）' "$DOCTOR_MODULE"; then
    printf '健康体检错误地强制要求可选 Docker 功能。\n' >&2
    exit 1
fi

printf '健康体检静态安全测试通过。\n'
