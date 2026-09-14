#!/bin/sh
set -eu

target=$1
declared=$2
directory=${target%/*}
mkdir -p "$directory"
temporary=$(mktemp "$directory/.pi-config.XXXXXX")
trap 'rm -f "$temporary"' EXIT

if [ -f "$target" ] && jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
  jq -s '.[0] * .[1]' "$target" "$declared" > "$temporary"
else
  cp "$declared" "$temporary"
fi

chmod 600 "$temporary"
mv "$temporary" "$target"
trap - EXIT
