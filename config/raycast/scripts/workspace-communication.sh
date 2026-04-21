#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Workspace Communication
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Workspace
# @raycast.needsConfirmation false

set -euo pipefail

source "${HOME}/.config/raycast/lib/workspace.sh"

set_space_layout 2 "stack"
launch_app_if_needed "Slack" /usr/bin/open -ga "Slack.app"
launch_app_if_needed "LINE" /usr/bin/open -ga "LINE.app"
launch_app_if_needed "Discord" /usr/bin/open -ga "Discord.app"
focus_space 2
notify_workspace "Workspace Communication" "Space 2" "Slack, LINE, and Discord are ready."
