#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Workspace Coding
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Workspace
# @raycast.needsConfirmation false

set -euo pipefail

source "${HOME}/.config/raycast/lib/workspace.sh"

set_space_layout 1 "bsp"
launch_app_if_needed "Ghostty" /usr/bin/open -ga "Ghostty.app"
launch_app_if_needed "Zen" /usr/bin/open -ga "Zen.app"
focus_space 1
notify_workspace "Workspace Coding" "Space 1" "Ghostty and Zen are ready."
