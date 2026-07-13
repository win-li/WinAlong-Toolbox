#!/usr/bin/env bash
set -Eeuo pipefail

WAT_ROOT_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
# shellcheck source=config/default.conf
. "${WAT_ROOT_DIR}/config/default.conf"
# shellcheck source=config/update.conf
. "${WAT_ROOT_DIR}/config/update.conf"
# shellcheck source=lib/common.sh
. "${WAT_ROOT_DIR}/lib/common.sh"
# shellcheck source=lib/ui.sh
. "${WAT_ROOT_DIR}/lib/ui.sh"
# shellcheck source=modules/update.sh
. "${WAT_ROOT_DIR}/modules/update.sh"

wat_log_init
wat_update_apply
