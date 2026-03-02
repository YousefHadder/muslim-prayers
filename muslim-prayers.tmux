#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

main() {
  local prayer_script="$CURRENT_DIR/scripts/prayer_times.sh"
  local popup_script="$CURRENT_DIR/scripts/popup_times.sh"
  local popup_key
  popup_key="$(get_tmux_option "@prayer-times-popup-key" "m")"

  tmux bind-key "$popup_key" run-shell -b "$popup_script"

  # Export plugin path so #() shell commands in catppuccin conf can find scripts
  tmux set-environment -g MUSLIM_PRAYERS_DIR "$CURRENT_DIR"

  for side in status-left status-right; do
    replace_placeholder_in_status_line "prayer_times" "$prayer_script status" "$side"
    replace_placeholder_in_status_line "prayer_times_color" "$prayer_script color" "$side"
    replace_placeholder_in_status_line "prayer_times_icon" "$prayer_script icon" "$side"
  done
}

main "$@"
