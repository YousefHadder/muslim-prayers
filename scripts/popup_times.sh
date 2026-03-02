#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

PRAYER_SCRIPT="$CURRENT_DIR/scripts/prayer_times.sh"
TIMES_OUTPUT="$("$PRAYER_SCRIPT" times 2>/dev/null || true)"

if [ -z "$TIMES_OUTPUT" ]; then
  tmux display-message "prayer-times: unable to load today's prayer times"
  exit 0
fi

TMPFILE="$(mktemp)"
TMPSCRIPT_EARLY=""
trap 'rm -f "$TMPFILE" "$TMPSCRIPT_EARLY"' EXIT

{
  echo ""
  echo "  Today's Prayer Times"
  echo "  ===================="
  echo ""
  while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line"
  done <<EOF
$TIMES_OUTPUT
EOF
  echo ""
  echo "  Press any key to close"
  echo ""
} > "$TMPFILE"

TMPSCRIPT="$(mktemp)"
TMPSCRIPT_EARLY="$TMPSCRIPT"
cat > "$TMPSCRIPT" <<SCRIPT
#!/usr/bin/env bash
cat '$TMPFILE'
read -rsn1
rm -f '$TMPFILE' '$TMPSCRIPT'
SCRIPT
chmod +x "$TMPSCRIPT"

if supports_popup; then
  tmux display-popup -E -w 50 -h 14 "$TMPSCRIPT"
else
  tmux split-window -v -l 14 "$TMPSCRIPT"
fi
