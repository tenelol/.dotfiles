#!/usr/bin/env bash
set -euo pipefail

pve_load_config() {
  local config_path="${PVE_CONFIG:-$HOME/.config/proxmox-pve/config.env}"

  if [[ -f "$config_path" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$config_path"
    set +a
  fi
}
