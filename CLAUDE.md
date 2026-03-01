# CLAUDE.md

## Project
- TPM plugin: `muslim-prayers`
- Goal: show Islamic prayer status in tmux status line using offline calculations
- Current phase: initial implementation from `PROMPT.md`

## Expected layout
- `muslim-prayers.tmux`: TPM entrypoint, placeholder registration/replacement
- `scripts/helpers.sh`: tmux option helpers + interpolation utilities
- `scripts/prayer_times.sh`: cache + orchestration script called by tmux
- `scripts/prayer_calc.lua`: self-contained offline prayer-time calculator
- `README.md`: install/config docs
- `LICENSE`: MIT

## Conventions
- Shell scripts use `set -euo pipefail`
- tmux options namespaced as `@prayer-times-*`
- Default profile is configurable (do not hardcode one fixed user profile)
- Prefer explicit fallback strings on failure (missing lua, invalid config, calc errors)
- Keep script paths relative to plugin root (`$CURRENT_DIR`)

## Configuration model
- Supported options include latitude, longitude, timezone, utc-offset, method, school, format, interval
- `@prayer-times-utc-offset` can be explicit number or `auto`
- If `auto`, resolve offset from `@prayer-times-timezone` (DST-aware behavior expected)

## Validation commands
- Shell syntax: `bash -n scripts/helpers.sh scripts/prayer_times.sh`
- Lua smoke test: `lua scripts/prayer_calc.lua 32.8140 -96.9489 auto ISNA standard 12H status America/Chicago`
- Optional static checks (if installed): `shellcheck scripts/*.sh`

## Notes
- No external API calls for calculations (offline-first)
- Cache values in tmux options:
  - `@prayer-times-previous-value`
  - `@prayer-times-previous-color`
  - `@prayer-times-previous-update-time`
