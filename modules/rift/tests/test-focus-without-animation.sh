#!/bin/sh
set -eu

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
HELPER="$TEST_DIR/../files/focus-without-animation"
TMP_ROOT="$(mktemp -d)"
trap "rm -rf \"$TMP_ROOT\"" 0 1 2 15

MOCK_CLI="$TMP_ROOT/rift-cli"
LOG_FILE="$TMP_ROOT/calls.log"
LOCK_FILE="$TMP_ROOT/focus.lock"

cat >"$MOCK_CLI" <<'EOF'
#!/bin/sh
set -eu

case "$*" in
  "execute config get")
    printf '%s\n' '{"settings":{"animation_duration":2.0}}'
    ;;
  "execute config set-animation-duration "*)
    printf "duration=%s\n" "$4" >>"$LOG_FILE"
    ;;
  "execute window focus "*)
    printf "focus=%s\n" "$4" >>"$LOG_FILE"
    if [ -n "${MOCK_FOCUS_DELAY:-}" ]; then
      /bin/sleep "$MOCK_FOCUS_DELAY"
    fi
    [ "${FAIL_FOCUS:-0}" -eq 0 ]
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$MOCK_CLI"

RIFT_CLI="$MOCK_CLI" \
  LOG_FILE="$LOG_FILE" \
  RIFT_FOCUS_LOCK_FILE="$LOCK_FILE" \
  /bin/sh "$HELPER" left

expected="$(printf "duration=0\nfocus=left\nduration=2.0")"
actual="$(cat "$LOG_FILE")"
[ "$actual" = "$expected" ]

: >"$LOG_FILE"
RIFT_CLI="$MOCK_CLI" \
  LOG_FILE="$LOG_FILE" \
  RIFT_FOCUS_LOCK_FILE="$LOCK_FILE" \
  MOCK_FOCUS_DELAY=0.05 \
  /bin/sh "$HELPER" left &
first_pid=$!
RIFT_CLI="$MOCK_CLI" \
  LOG_FILE="$LOG_FILE" \
  RIFT_FOCUS_LOCK_FILE="$LOCK_FILE" \
  MOCK_FOCUS_DELAY=0.05 \
  /bin/sh "$HELPER" right &
second_pid=$!
wait "$first_pid"
wait "$second_pid"

awk '
  NR % 3 == 1 && $0 != "duration=0" { bad = 1 }
  NR % 3 == 2 && $0 !~ /^focus=(left|right)$/ { bad = 1 }
  NR % 3 == 0 && $0 != "duration=2.0" { bad = 1 }
  END { exit bad || NR != 6 }
' "$LOG_FILE"

: >"$LOG_FILE"
if RIFT_CLI="$MOCK_CLI" \
  LOG_FILE="$LOG_FILE" \
  RIFT_FOCUS_LOCK_FILE="$LOCK_FILE" \
  FAIL_FOCUS=1 \
  /bin/sh "$HELPER" right; then
  echo "focus failure unexpectedly succeeded" >&2
  exit 1
fi

expected="$(printf "duration=0\nfocus=right\nduration=2.0")"
actual="$(cat "$LOG_FILE")"
[ "$actual" = "$expected" ]

if RIFT_CLI="$MOCK_CLI" \
  LOG_FILE="$LOG_FILE" \
  RIFT_FOCUS_LOCK_FILE="$LOCK_FILE" \
  /bin/sh "$HELPER" diagonal 2>/dev/null; then
  echo "invalid direction unexpectedly succeeded" >&2
  exit 1
fi
