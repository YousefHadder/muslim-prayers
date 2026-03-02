#!/usr/bin/env bash
set -euo pipefail

get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value
  option_value="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

set_tmux_option() {
  local option="$1"
  local value="$2"
  tmux set-option -gq "$option" "$value" >/dev/null 2>&1 || true
}

replace_placeholder_in_status_line() {
  local placeholder="$1"
  local command="$2"
  local option_name="$3"
  local option_value

  option_value="$(tmux show-option -gqv "$option_name" 2>/dev/null || true)"
  [ -z "$option_value" ] && return 0

  option_value="${option_value//\#\{$placeholder\}/#($command)}"
  tmux set-option -gq "$option_name" "$option_value" >/dev/null 2>&1 || true
}

get_tmux_version() {
  local version_string
  local major
  local minor
  version_string="$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || true)"
  if [ -z "$version_string" ]; then
    echo "0"
    return
  fi

  major="${version_string%%.*}"
  minor="${version_string##*.}"
  echo "$((major * 100 + minor))"
}

supports_popup() {
  local version
  version="$(get_tmux_version)"
  [ "$version" -ge 302 ]
}
