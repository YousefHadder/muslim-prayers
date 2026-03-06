#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

main() {
  local prayer_script="$CURRENT_DIR/scripts/prayer_times.sh"
  local popup_script="$CURRENT_DIR/scripts/popup_times.sh"
  local popup_key
  local warmup_cmd
  popup_key="$(get_tmux_option "@prayer-times-popup-key" "m")"

  tmux bind-key "$popup_key" run-shell -b "$popup_script"

  # Export plugin path so #() shell commands in catppuccin conf can find scripts
  tmux set-environment -g MUSLIM_PRAYERS_DIR "$CURRENT_DIR"

  replace_placeholder_in_all_options "prayer_times" "$prayer_script status"
  replace_placeholder_in_all_options "prayer_times_color" "$prayer_script color"
  replace_placeholder_in_all_options "prayer_times_icon" "$prayer_script icon"

  # Prime status cache asynchronously to avoid blocking tmux startup.
  warmup_cmd="'$prayer_script' status >/dev/null 2>&1; tmux refresh-client -S >/dev/null 2>&1 || true"
  tmux run-shell -b "$warmup_cmd"
}

main "$@"
