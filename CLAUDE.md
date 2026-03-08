# CLAUDE.md

## Project
- TPM plugin: `muslim-prayers`
- Goal: show Islamic prayer status in tmux status line using offline calculations
- Current phase: initial implementation from `PROMPT.md`

## Layout
- `muslim-prayers.tmux`: TPM entrypoint — placeholder registration, key binding, cache warmup
- `scripts/helpers.sh`: tmux option get/set helpers + placeholder interpolation utilities
- `scripts/prayer_times.sh`: cache + orchestration (modes: status, color, icon, times, json, cache)
- `scripts/prayer_calc.lua`: self-contained offline prayer calculator (512 lines, 10 methods)
- `scripts/popup_times.sh`: popup/split-window display of all five daily prayers
- `catppuccin_prayer_times.conf`: Catppuccin theme module integration
- `.github/workflows/ci.yml`: CI smoke tests on Ubuntu + macOS
- `README.md`, `PROMPT.md`, `LICENSE` (MIT)

## Conventions
- Shell scripts use `#!/usr/bin/env bash` + `set -euo pipefail`
- Functions/vars: `snake_case`; constants: `UPPER_SNAKE_CASE`; tmux opts: `@prayer-times-*`
- Default profile is configurable (do not hardcode one fixed user profile)
- Prefer explicit fallback strings on failure (missing lua, invalid config, calc errors)
- Keep script paths relative to plugin root (`$CURRENT_DIR`)
- Catppuccin options use `#{l:#(...)}` literal wrapping to avoid early empty expansion

## Configuration model
- Supported options: latitude, longitude, timezone, utc-offset, method, school, format, interval, icon, color, popup-key
- `@prayer-times-utc-offset` can be explicit number or `auto`
- If `auto`, resolve offset from `@prayer-times-timezone` via `TZ` env var (DST-aware)
- Lua detects interpreter in order: lua, lua5.4, lua5.3, lua5.2, luajit

## Validation commands
- Shell syntax: `bash -n muslim-prayers.tmux scripts/helpers.sh scripts/prayer_times.sh scripts/popup_times.sh`
- Lua smoke test: `lua scripts/prayer_calc.lua 32.8140 -96.9489 auto ISNA standard 12H status America/Chicago`
- Optional static checks (if installed): `shellcheck scripts/*.sh`

## Cache keys (tmux options)
- `@prayer-times-previous-value` — cached status text
- `@prayer-times-previous-color` — cached color hex
- `@prayer-times-previous-update-time` — unix timestamp of last calculation
- `@prayer-times-next-refresh-time` — unix timestamp for next required calculation
- `@prayer-times-previous-tz-offset` — TZ offset (e.g. -0500) used to detect DST transitions

## Notes
- No external API calls for calculations (offline-first)
- Popup requires tmux ≥ 3.2; falls back to split-window on older versions
- CI validates: bash syntax, status output pattern, hex color format, JSON with next_refresh_epoch
