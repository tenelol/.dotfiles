#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/load-config.sh"
pve_load_config

usage() {
  cat <<'EOF'
Usage:
  pve-node-ssh.sh command [args...]

Required environment variables or config values:
  PVE_SSH_HOST

Default config file:
  ~/.config/proxmox-pve/config.env

Optional environment variables:
  PVE_SSH_USER      default: root
  PVE_SSH_PORT      default: 22
  PVE_SSH_OPTS      extra ssh options, split by shell words

Examples:
  pve-node-ssh.sh hostname
  pve-node-ssh.sh pct list
  PVE_SSH_HOST=100.122.252.38 PVE_SSH_USER=root pve-node-ssh.sh pct config 103
EOF
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

if [[ -z "${PVE_SSH_HOST:-}" ]]; then
  echo "Missing required environment variable: PVE_SSH_HOST" >&2
  exit 2
fi

ssh_user="${PVE_SSH_USER:-root}"
ssh_port="${PVE_SSH_PORT:-22}"

declare -a ssh_opts=()
if [[ -n "${PVE_SSH_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  ssh_opts=(${PVE_SSH_OPTS})
fi

ssh_cmd=(
  ssh
  -p "$ssh_port"
  "${ssh_opts[@]}"
  "${ssh_user}@${PVE_SSH_HOST}"
  "$@"
)

exec "${ssh_cmd[@]}"
