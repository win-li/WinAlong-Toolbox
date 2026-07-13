#!/usr/bin/env bash
set -Eeuo pipefail

# Metadata is consumed by the plugin loader after this file is sourced.
# shellcheck disable=SC2034
WAT_PLUGIN_ID="system-summary"
# shellcheck disable=SC2034
WAT_PLUGIN_NAME="只读系统摘要"
# shellcheck disable=SC2034
WAT_PLUGIN_VERSION="1.0.0"

wat_plugin_run() {
    wat_system_info
}
