#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Workspace Assistants
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Workspace
# @raycast.needsConfirmation false

set -euo pipefail

source "${HOME}/.config/raycast/lib/workspace.sh"

set_space_layout 3 "stack"
launch_app_if_needed "ChatGPT" /usr/bin/open -ga "ChatGPT.app"
launch_app_if_needed "Claude" /usr/bin/open -ga "Claude.app"
launch_app_if_needed "Codex" /usr/bin/open -ga "Codex.app"
focus_space 3
notify_workspace "Workspace Assistants" "Space 3" "ChatGPT, Claude, and Codex are ready."
