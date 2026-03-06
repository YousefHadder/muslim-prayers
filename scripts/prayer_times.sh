#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

MODE="${1:-status}"

LATITUDE="$(get_tmux_option "@prayer-times-latitude" "32.8140")"
LONGITUDE="$(get_tmux_option "@prayer-times-longitude" "-96.9489")"
TIMEZONE="$(get_tmux_option "@prayer-times-timezone" "America/Chicago")"
UTC_OFFSET="$(get_tmux_option "@prayer-times-utc-offset" "auto")"
METHOD="$(get_tmux_option "@prayer-times-method" "ISNA")"
SCHOOL="$(get_tmux_option "@prayer-times-school" "standard")"
TIME_FORMAT="$(get_tmux_option "@prayer-times-format" "12H")"
INTERVAL_MINUTES="$(get_tmux_option "@prayer-times-interval" "1")"
ICON_TEXT="$(get_tmux_option "@prayer-times-icon" "🕌 ")"
PRAYER_COLOR="$(get_tmux_option "@prayer-times-color" "#89b4fa")"

detect_lua_bin() {
  local candidate
  for candidate in lua lua5.4 lua5.3 lua5.2 luajit; do
    if command -v "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  echo ""
}

LUA_BIN="$(detect_lua_bin)"

CACHE_VALUE_OPTION="@prayer-times-previous-value"
CACHE_COLOR_OPTION="@prayer-times-previous-color"
CACHE_TIME_OPTION="@prayer-times-previous-update-time"
CACHE_NEXT_REFRESH_OPTION="@prayer-times-next-refresh-time"

if ! [[ "$INTERVAL_MINUTES" =~ ^[0-9]+$ ]]; then
  INTERVAL_MINUTES="1"
fi

if [ "$MODE" = "icon" ]; then
  echo "$ICON_TEXT"
  exit 0
fi

if [ "$MODE" = "color" ]; then
  echo "$PRAYER_COLOR"
  exit 0
fi

run_lua_mode() {
  local lua_mode="$1"
  local script_path="$CURRENT_DIR/scripts/prayer_calc.lua"
  local output=""

  if [ -n "$TIMEZONE" ]; then
    output="$(TZ="$TIMEZONE" "$LUA_BIN" "$script_path" \
      "$LATITUDE" "$LONGITUDE" "$UTC_OFFSET" "$METHOD" "$SCHOOL" "$TIME_FORMAT" "$lua_mode" "$TIMEZONE" \
      2>/dev/null || true)"
  else
    output="$("$LUA_BIN" "$script_path" \
      "$LATITUDE" "$LONGITUDE" "$UTC_OFFSET" "$METHOD" "$SCHOOL" "$TIME_FORMAT" "$lua_mode" \
      2>/dev/null || true)"
  fi

  printf '%s' "$output"
}

emit_fallback() {
  local status="Prayer: unavailable"
  local color="$PRAYER_COLOR"
  local now
  now="$(date +%s)"
  set_tmux_option "$CACHE_VALUE_OPTION" "$status"
  set_tmux_option "$CACHE_COLOR_OPTION" "$color"
  set_tmux_option "$CACHE_TIME_OPTION" "$now"
  set_tmux_option "$CACHE_NEXT_REFRESH_OPTION" "$((now + INTERVAL_SECONDS))"

  if [ "$MODE" = "color" ]; then
    echo "$color"
  else
    echo "$status"
  fi
}

if [ "$MODE" = "times" ] || [ "$MODE" = "json" ]; then
  if [ -z "$LUA_BIN" ]; then
    if [ "$MODE" = "json" ]; then
      echo '{"error":"lua not found"}'
    else
      echo "Prayer: lua not found"
    fi
    exit 0
  fi

  direct_output="$(run_lua_mode "$MODE")"
  if [ -z "$direct_output" ]; then
    if [ "$MODE" = "json" ]; then
      echo '{"error":"calculation failure"}'
    else
      echo "Prayer: calculation failure"
    fi
  else
    echo "$direct_output"
  fi
  exit 0
fi

CURRENT_TIME="$(date +%s)"
LAST_UPDATE_TIME="$(get_tmux_option "$CACHE_TIME_OPTION" "0")"
NEXT_REFRESH_TIME="$(get_tmux_option "$CACHE_NEXT_REFRESH_OPTION" "0")"
CACHED_STATUS="$(get_tmux_option "$CACHE_VALUE_OPTION" "")"
CACHED_COLOR="$(get_tmux_option "$CACHE_COLOR_OPTION" "$PRAYER_COLOR")"
INTERVAL_SECONDS="$((INTERVAL_MINUTES * 60))"
CLOCK_ROLLED_BACK="false"

if [[ "$LAST_UPDATE_TIME" =~ ^[0-9]+$ ]] && [ "$CURRENT_TIME" -lt "$LAST_UPDATE_TIME" ]; then
  CLOCK_ROLLED_BACK="true"
fi

USE_CACHE="false"
NEXT_REFRESH_VALID="false"
if [[ "$NEXT_REFRESH_TIME" =~ ^[0-9]+$ ]] && [ "$NEXT_REFRESH_TIME" -gt 0 ]; then
  NEXT_REFRESH_VALID="true"
fi

if [ -n "$CACHED_STATUS" ] && [ "$CLOCK_ROLLED_BACK" = "false" ]; then
  if [ "$NEXT_REFRESH_VALID" = "true" ]; then
    if [ "$NEXT_REFRESH_TIME" -gt "$CURRENT_TIME" ]; then
      USE_CACHE="true"
    fi
  elif [[ "$LAST_UPDATE_TIME" =~ ^[0-9]+$ ]] && [ "$((CURRENT_TIME - LAST_UPDATE_TIME))" -lt "$INTERVAL_SECONDS" ]; then
    USE_CACHE="true"
  fi
fi

if [ "$USE_CACHE" = "true" ]; then
  echo "$CACHED_STATUS"
  exit 0
fi

if [ -z "$LUA_BIN" ]; then
  emit_fallback
  exit 0
fi

CACHE_PAYLOAD="$(run_lua_mode "cache")"
STATUS_TEXT=""
COLOR_TEXT=""
NEXT_REFRESH_TIME=""
if [ -n "$CACHE_PAYLOAD" ]; then
  line_index=0
  while IFS= read -r line; do
    if [ "$line_index" -eq 0 ]; then
      STATUS_TEXT="$line"
    elif [ "$line_index" -eq 1 ]; then
      COLOR_TEXT="$line"
    elif [ "$line_index" -eq 2 ]; then
      NEXT_REFRESH_TIME="$line"
      break
    fi
    line_index="$((line_index + 1))"
  done <<EOF
$CACHE_PAYLOAD
EOF
fi

if [ -z "$STATUS_TEXT" ]; then
  STATUS_TEXT="Prayer: calculation failure"
fi
COLOR_TEXT="$PRAYER_COLOR"
if ! [[ "$NEXT_REFRESH_TIME" =~ ^[0-9]+$ ]]; then
  NEXT_REFRESH_TIME="$((CURRENT_TIME + INTERVAL_SECONDS))"
fi
if [ "$NEXT_REFRESH_TIME" -le "$CURRENT_TIME" ]; then
  NEXT_REFRESH_TIME="$((CURRENT_TIME + INTERVAL_SECONDS))"
fi

set_tmux_option "$CACHE_VALUE_OPTION" "$STATUS_TEXT"
set_tmux_option "$CACHE_COLOR_OPTION" "$COLOR_TEXT"
set_tmux_option "$CACHE_TIME_OPTION" "$CURRENT_TIME"
set_tmux_option "$CACHE_NEXT_REFRESH_OPTION" "$NEXT_REFRESH_TIME"

if [ "$MODE" = "color" ]; then
  echo "$COLOR_TEXT"
else
  echo "$STATUS_TEXT"
fi
