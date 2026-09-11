#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/load-config.sh"
pve_load_config

usage() {
  cat <<'EOF'
Usage:
  pve-api.sh [-X METHOD] [-d KEY=VALUE]... /path

Required environment variables or config values:
  PVE_HOST
  PVE_TOKEN_ID
  PVE_TOKEN_SECRET

Default config file:
  ~/.config/proxmox-pve/config.env

Examples:
  pve-api.sh /version
  pve-api.sh /nodes
  pve-api.sh /nodes/pve/lxc/103/status/current
  pve-api.sh -X POST /nodes/pve/lxc/103/status/reboot
  pve-api.sh -X POST -d description='updated by codex' /nodes/pve/lxc/103/config
EOF
}

method="GET"
declare -a data_args=()

while getopts ":X:d:h" opt; do
  case "$opt" in
    X)
      method="$OPTARG"
      ;;
    d)
      data_args+=(-d "$OPTARG")
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      echo "Missing argument for -$OPTARG" >&2
      usage >&2
      exit 2
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage >&2
      exit 2
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

for required in PVE_HOST PVE_TOKEN_ID PVE_TOKEN_SECRET; do
  if [[ -z "${!required:-}" ]]; then
    echo "Missing required environment variable: $required" >&2
    exit 2
  fi
done

path="$1"
if [[ "$path" != /* ]]; then
  echo "Path must start with '/': $path" >&2
  exit 2
fi

curl_args=(
  -ksS
  -X "$method"
  -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}"
)

if ((${#data_args[@]})); then
  curl_args+=("${data_args[@]}")
fi

curl_args+=("https://${PVE_HOST}:8006/api2/json${path}")

curl "${curl_args[@]}"
