#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MODULE="${PROJECT_DIR}/modules/config_snapshot.sh"

grep -Eq '^wat_config_snapshot_create\(\)' "$MODULE" || {
    printf '缺少托管配置快照入口。\n' >&2
    exit 1
}
for allowed in 99-winalong-bbr.conf winalong-sshd.local winalong-backup.service storage.conf; do
    grep -Fq "$allowed" "$MODULE" || { printf '配置快照缺少允许项：%s\n' "$allowed" >&2; exit 1; }
done
if grep -Eq '/etc/ssh|/etc/ufw|config/local\.conf|\.env|id_ed25519|/root/\.ssh' "$MODULE"; then
    printf '配置快照允许清单包含敏感配置。\n' >&2
    exit 1
fi
if grep -Eq 'wat_.*restore|tar[[:space:]]+-x' "$MODULE"; then
    printf '配置快照模块不应提供自动恢复。\n' >&2
    exit 1
fi
grep -Fq "chmod 0600 \"\$archive\"" "$MODULE" || { printf '配置快照归档权限不明确。\n' >&2; exit 1; }
printf '托管配置快照静态安全测试通过。\n'
