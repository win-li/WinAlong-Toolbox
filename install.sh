#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=config/default.conf
. "${SOURCE_DIR}/config/default.conf"
# shellcheck source=lib/common.sh
. "${SOURCE_DIR}/lib/common.sh"

wat_require_root

mkdir -p "$WAT_INSTALL_DIR" "$WAT_LOG_DIR" "$WAT_BACKUP_DIR"

# Copy only distributable project files; runtime data remains outside /opt.
# Running the already-installed script is a safe no-op for the copy phase.
if [[ $SOURCE_DIR != "$WAT_INSTALL_DIR" ]]; then
    for path in toolbox.sh install.sh uninstall.sh update.sh bootstrap.sh README.md CHANGELOG.md LICENSE SECURITY.md CONTRIBUTING.md lib modules docs plugins; do
        if [[ -e ${SOURCE_DIR}/${path} ]]; then
            rm -rf -- "${WAT_INSTALL_DIR:?}/${path}"
            cp -a -- "${SOURCE_DIR}/${path}" "$WAT_INSTALL_DIR/"
        fi
    done

    # Refresh defaults while preserving config/local.conf when it exists.
    mkdir -p "$WAT_INSTALL_DIR/config"
    cp -a -- "${SOURCE_DIR}/config/default.conf" "$WAT_INSTALL_DIR/config/default.conf"
    cp -a -- "${SOURCE_DIR}/config/apps.conf" "$WAT_INSTALL_DIR/config/apps.conf"
    cp -a -- "${SOURCE_DIR}/config/security.conf" "$WAT_INSTALL_DIR/config/security.conf"
    cp -a -- "${SOURCE_DIR}/config/network.conf" "$WAT_INSTALL_DIR/config/network.conf"
    cp -a -- "${SOURCE_DIR}/config/update.conf" "$WAT_INSTALL_DIR/config/update.conf"
    cp -a -- "${SOURCE_DIR}/config/doctor.conf" "$WAT_INSTALL_DIR/config/doctor.conf"
    cp -a -- "${SOURCE_DIR}/config/maintenance.conf" "$WAT_INSTALL_DIR/config/maintenance.conf"
    cp -a -- "${SOURCE_DIR}/config/storage.conf" "$WAT_INSTALL_DIR/config/storage.conf"
fi

# Installed code may run with root privileges, so it must not remain owned by
# the account that cloned the source repository.
chown -R root:root "$WAT_INSTALL_DIR"
chmod +x "$WAT_INSTALL_DIR/toolbox.sh" "$WAT_INSTALL_DIR/install.sh" \
    "$WAT_INSTALL_DIR/uninstall.sh" "$WAT_INSTALL_DIR/update.sh" \
    "$WAT_INSTALL_DIR/bootstrap.sh"
find "$WAT_INSTALL_DIR/lib" "$WAT_INSTALL_DIR/modules" -type f -name '*.sh' -exec chmod 0755 {} +
find "$WAT_INSTALL_DIR/plugins" -type f -name '*.plugin.sh' -exec chmod 0644 {} +
install -o root -g root -m 0755 -d /etc/winalong-toolbox/plugins
ln -sfn "$WAT_INSTALL_DIR/toolbox.sh" "$WAT_BIN_LINK"

printf '安装完成。运行：%s\n' "$WAT_BIN_LINK"
printf '日志目录：%s\n备份目录：%s\n' "$WAT_LOG_DIR" "$WAT_BACKUP_DIR"
