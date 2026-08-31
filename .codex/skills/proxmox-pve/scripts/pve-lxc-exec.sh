#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pve-lxc-exec.sh <vmid> [--node <node>] -- command [args...]

Required environment variables or config values:
  PVE_SSH_HOST

Default config file:
  ~/.config/proxmox-pve/config.env

Optional environment variables:
  PVE_SSH_USER      default: root
  PVE_SSH_PORT      default: 22
  PVE_SSH_OPTS      extra ssh options, split by shell words

Examples:
  pve-lxc-exec.sh 103 -- uname -a
  pve-lxc-exec.sh 103 -- sh -lc 'id && hostname'
  pve-lxc-exec.sh 103 --node pve -- systemctl status nginx --no-pager
EOF
}

if [[ $# -lt 3 ]]; then
  usage >&2
  exit 2
fi

vmid="$1"
shift

node=""
if [[ "${1:-}" == "--node" ]]; then
  if [[ $# -lt 3 ]]; then
    usage >&2
    exit 2
  fi
  node="$2"
  shift 2
fi

if [[ "${1:-}" != "--" ]]; then
  usage >&2
  exit 2
fi
shift

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -a remote_cmd=(pct exec "$vmid")
if [[ -n "$node" ]]; then
  remote_cmd+=(--node "$node")
fi
remote_cmd+=(-- "$@")

"$script_dir/pve-node-ssh.sh" "${remote_cmd[@]}"
