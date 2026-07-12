#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DOCKER_MODULE="${PROJECT_DIR}/modules/docker.sh"

required_functions=(
    wat_docker_status wat_docker_versions wat_docker_install_engine
    wat_docker_install_compose wat_docker_service_action
    wat_docker_list_containers wat_docker_list_images wat_docker_disk_usage
    wat_docker_menu
)

for function_name in "${required_functions[@]}"; do
    if ! grep -Eq "^${function_name}\\(\\)" "$DOCKER_MODULE"; then
        printf 'Docker 模块缺少函数：%s\n' "$function_name" >&2
        exit 1
    fi
done

# v0.3.0 intentionally excludes destructive Docker data operations.
if grep -Eq 'docker[[:space:]]+(container|image|volume|system)[[:space:]]+(rm|prune)' "$DOCKER_MODULE"; then
    printf 'Docker 模块包含未授权的数据删除操作。\n' >&2
    exit 1
fi

printf 'Docker 静态安全测试通过。\n'
