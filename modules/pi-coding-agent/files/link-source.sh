#!/bin/sh
set -eu

source=$1
target=$2
mkdir -p "${target%/*}"

if [ -e "$target" ] || [ -L "$target" ]; then
  if [ ! -L "$target" ]; then
    echo "error: refusing to replace non-symlink $target" >&2
    exit 1
  fi
  [ "$(readlink "$target")" = "$source" ] && exit 0
  rm "$target"
fi

ln -s "$source" "$target"
