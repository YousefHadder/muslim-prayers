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

replace_placeholder_in_option() {
  local placeholder="$1"
  local command="$2"
  local option_name="$3"
  local option_value
  local updated_value
  local direct_placeholder
  local literal_placeholder
  local direct_command
  local literal_command
  local marker
  local double_literal_command

  option_value="$(tmux show-option -gqv "$option_name" 2>/dev/null || true)"
  [ -z "$option_value" ] && return 0

  direct_placeholder="#{$placeholder}"
  literal_placeholder="#{l:#{$placeholder}}"
  direct_command="#($command)"
  literal_command="#{l:#($command)}"

  updated_value="$option_value"
  updated_value="${updated_value//$literal_placeholder/$literal_command}"
  updated_value="${updated_value//$direct_placeholder/$direct_command}"

  # Keep command substitutions literal in Catppuccin options because they are
  # consumed through #{E:@...} and often attached with set-option -F.
  if [[ "$option_name" == @catppuccin_* ]]; then
    marker="__MUSLIM_PRAYERS_LITERAL_CMD__"
    double_literal_command="#{l:$literal_command}"

    while [[ "$updated_value" == *"$double_literal_command"* ]]; do
      updated_value="${updated_value//$double_literal_command/$literal_command}"
    done

    updated_value="${updated_value//$literal_command/$marker}"
    updated_value="${updated_value//$direct_command/$literal_command}"
    updated_value="${updated_value//$marker/$literal_command}"
  fi

  [ "$updated_value" = "$option_value" ] && return 0
  tmux set-option -gq "$option_name" "$updated_value" >/dev/null 2>&1 || true
}

replace_placeholder_in_status_line() {
  replace_placeholder_in_option "$@"
}

replace_placeholder_in_all_options() {
  local placeholder="$1"
  local command="$2"
  local line
  local option_name

  while IFS= read -r line; do
    case "$line" in
      *"#{$placeholder}"*|*"#{l:#{$placeholder}}"*) ;;
      *) continue ;;
    esac

    option_name="${line%% *}"
    [ -z "$option_name" ] && continue
    replace_placeholder_in_option "$placeholder" "$command" "$option_name"
  done < <(tmux show-options -g 2>/dev/null || true)
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
