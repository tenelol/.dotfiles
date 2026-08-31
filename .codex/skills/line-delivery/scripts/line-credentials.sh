#!/bin/sh
set -eu

account="${LINE_KEYCHAIN_ACCOUNT:-${USER:-$(/usr/bin/id -un)}}"
keychain="${LINE_KEYCHAIN_PATH:-${HOME:?HOME is required}/Library/Keychains/login.keychain-db}"
token_service="dev.tenelol.codex.line-bot.channel-access-token"
recipient_service="dev.tenelol.codex.line-bot.destination-user-id"
broker_label="dev.tenelol.codex.line-delivery-broker"

usage() {
  cat <<'EOF'
Usage: line-credentials.sh <set-token|set-recipient|status|delete>

  set-token      Store or rotate the LINE channel access token
  set-recipient  Store or update the destination LINE user ID
  status         Report whether both Keychain items exist
  delete         Delete both Keychain items
EOF
}

present() {
  /usr/bin/security find-generic-password \
    -a "$account" \
    -s "$1" \
    "$keychain" \
    >/dev/null 2>&1
}

readable() {
  /usr/bin/security find-generic-password \
    -a "$account" \
    -s "$1" \
    -w \
    "$keychain" \
    >/dev/null 2>&1
}

store() {
  service="$1"
  label="$2"
  echo "Store $label in macOS Keychain. Input is hidden." >&2
  /usr/bin/security add-generic-password \
    -U \
    -a "$account" \
    -s "$service" \
    -l "$label" \
    -D "application password" \
    -T /usr/bin/security \
    -w
}

refresh_broker() {
  uid=$(/usr/bin/id -u)
  if /bin/launchctl print "gui/$uid/$broker_label" >/dev/null 2>&1; then
    if ! /bin/launchctl kickstart -k "gui/$uid/$broker_label" >/dev/null 2>&1; then
      echo "Failed to refresh the LINE delivery broker" >&2
      return 1
    fi
  fi
}

case "${1:-status}" in
  set-token)
    store "$token_service" "Codex LINE channel access token"
    refresh_broker
    ;;
  set-recipient)
    store "$recipient_service" "Codex LINE destination user ID"
    refresh_broker
    ;;
  status)
    if present "$token_service"; then
      if readable "$token_service"; then
        echo "Channel access token: present and readable"
      else
        echo "Channel access token: present but temporarily unreadable"
      fi
    else
      echo "Channel access token: missing"
    fi
    if present "$recipient_service"; then
      if readable "$recipient_service"; then
        echo "Destination user ID: present and readable"
      else
        echo "Destination user ID: present but temporarily unreadable"
      fi
    else
      echo "Destination user ID: missing"
    fi
    ;;
  delete)
    /usr/bin/security delete-generic-password \
      -a "$account" -s "$token_service" "$keychain" >/dev/null 2>&1 || true
    /usr/bin/security delete-generic-password \
      -a "$account" -s "$recipient_service" "$keychain" >/dev/null 2>&1 || true
    refresh_broker
    echo "LINE credentials removed from macOS Keychain"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
