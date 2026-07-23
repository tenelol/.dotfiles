#!/bin/bash

set -euo pipefail
set +x

readonly SERVICE="dev.tener.codex.crd.Tener.pin"
readonly ACCOUNT="${USER:-$(/usr/bin/id -un)}"
readonly CLIPBOARD_TTL_SECONDS="${CRD_PIN_CLIPBOARD_TTL_SECONDS:-30}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 {status|store|enter|copy|clear}" >&2
  exit 2
}

has_pin() {
  /usr/bin/security find-generic-password \
    -s "$SERVICE" \
    -a "$ACCOUNT" \
    >/dev/null 2>&1
}

status_pin() {
  if has_pin; then
    echo "configured"
    return 0
  fi

  echo "missing"
  return 1
}

store_pin() {
  /usr/bin/osascript <<'APPLESCRIPT' |
on containsOnlyDigits(valueText)
  if valueText is "" then return false
  repeat with characterIndex from 1 to (count characters of valueText)
    if character characterIndex of valueText is not in "0123456789" then return false
  end repeat
  return true
end containsOnlyDigits

repeat
  set dialogResult to display dialog "Tener用Chrome Remote Desktop PINを入力してください。PINはmacOSキーチェーンにだけ保存され、画面には表示されません。" default answer "" with hidden answer buttons {"キャンセル", "保存"} default button "保存" cancel button "キャンセル" with title "Chrome Remote Desktop PIN"
  set pinText to text returned of dialogResult
  if (count characters of pinText) is greater than or equal to 6 and my containsOnlyDigits(pinText) then return pinText
  display alert "PINは6桁以上の数字で入力してください。" as warning
end repeat
APPLESCRIPT
  /usr/bin/xcrun swift "$SCRIPT_DIR/store-keychain.swift"

  echo "configured"
}

copy_pin() {
  if ! has_pin; then
    echo "missing: run '$0 store' first" >&2
    exit 1
  fi

  /usr/bin/security find-generic-password \
    -w \
    -s "$SERVICE" \
    -a "$ACCOUNT" |
    /usr/bin/pbcopy

  /usr/bin/nohup /bin/bash -c '
    /bin/sleep "$1"
    /usr/bin/pbcopy </dev/null
  ' _ "$CLIPBOARD_TTL_SECONDS" </dev/null >/dev/null 2>&1 &

  echo "copied; clipboard will auto-clear in ${CLIPBOARD_TTL_SECONDS}s"
}

enter_pin_in_dia() {
  if ! has_pin; then
    echo "missing: run '$0 store' first" >&2
    exit 1
  fi

  CRD_KEYCHAIN_SERVICE="$SERVICE" \
    CRD_KEYCHAIN_ACCOUNT="$ACCOUNT" \
    /usr/bin/osascript <<'APPLESCRIPT'
set matchingTabs to {}

tell application "Dia"
  repeat with currentWindow in windows
    repeat with currentTab in tabs of currentWindow
      set tabUrl to URL of currentTab as text
      if tabUrl contains "remotedesktop.google.com" and tabUrl contains "/access/session/" then
        set end of matchingTabs to currentTab
      end if
    end repeat
  end repeat

  if (count of matchingTabs) is not 1 then
    error "Expected exactly one active Chrome Remote Desktop session tab."
  end if

  focus (item 1 of matchingTabs)
  activate
end tell

delay 0.3

tell application "System Events"
  tell process "Dia"
    set focusedElement to value of attribute "AXFocusedUIElement"
    if role of focusedElement is not "AXTextField" then error "Focused element is not a text field."
    if subrole of focusedElement is not "AXSecureTextField" then error "Focused element is not a secure text field."
    if description of focusedElement is not "PIN を入力" then error "Focused secure field is not the CRD PIN field."
  end tell
end tell

set keychainService to system attribute "CRD_KEYCHAIN_SERVICE"
set accountName to system attribute "CRD_KEYCHAIN_ACCOUNT"
set pinText to do shell script "/usr/bin/security find-generic-password -w -s " & quoted form of keychainService & " -a " & quoted form of accountName

if (count characters of pinText) is less than 6 then error "Stored PIN is invalid."
repeat with characterIndex from 1 to (count characters of pinText)
  if character characterIndex of pinText is not in "0123456789" then error "Stored PIN is invalid."
end repeat

tell application "System Events"
  tell process "Dia"
    set focusedElement to value of attribute "AXFocusedUIElement"
    if role of focusedElement is not "AXTextField" then error "Focused element changed."
    if subrole of focusedElement is not "AXSecureTextField" then error "Focused element changed."
    if description of focusedElement is not "PIN を入力" then error "Focused element changed."
    set value of focusedElement to pinText
  end tell
end tell

set pinText to ""
return "entered"
APPLESCRIPT
}

clear_pin() {
  /usr/bin/pbcopy </dev/null
  echo "cleared"
}

case "${1:-}" in
  status)
    status_pin
    ;;
  store)
    store_pin
    ;;
  enter)
    enter_pin_in_dia
    ;;
  copy)
    copy_pin
    ;;
  clear)
    clear_pin
    ;;
  *)
    usage
    ;;
esac
