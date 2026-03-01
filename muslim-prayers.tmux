#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

main() {
  local prayer_script="$CURRENT_DIR/scripts/prayer_times.sh"

  for side in status-left status-right; do
    replace_placeholder_in_status_line "prayer_times" "$prayer_script status" "$side"
    replace_placeholder_in_status_line "prayer_times_color" "$prayer_script color" "$side"
    replace_placeholder_in_status_line "prayer_times_icon" "$prayer_script icon" "$side"
  done
}

main "$@"
