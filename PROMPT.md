# Muslim Prayers — Tmux Plugin Planning Prompt

You are building a TPM (Tmux Plugin Manager) plugin called **muslim-prayers** that displays Islamic prayer times in the tmux status bar. The working directory is `~/github/muslim-prayers/`.

## Goal

Create a well-structured, **configurable**, offline-first tmux plugin that shows the current prayer waqt status (e.g., "Asr ends in 1:23 | Maghrib at: 06:17 PM") in the tmux status bar, with color-coded urgency.

## Default Profile (override-able)

- Location: Irving, TX (32.8140, -96.9489, UTC-6 CST / UTC-5 CDT)
- Method: ISNA (Islamic Society of North America)
- School: Standard (Shafi'i shadow factor)
- Theme context: catppuccin tmux with custom modules

All defaults above must be configurable via tmux options. The plugin should not be hardcoded to one location/method/school profile.

## Architecture

### Plugin Structure

```
muslim-prayers/
├── muslim-prayers.tmux        # TPM entry point — registers interpolation placeholders
├── scripts/
│   ├── helpers.sh             # get/set tmux option helpers (standard TPM pattern)
│   ├── prayer_times.sh        # Main script — called by tmux interpolation, handles caching
│   └── prayer_calc.lua        # Offline calculation engine (ported from muslim.nvim)
├── README.md
└── LICENSE
```

### Calculation Engine (`scripts/prayer_calc.lua`)

Port the offline calculation from the `muslim.nvim` Neovim plugin. The relevant source files to reference are:

- `~/.local/share/nvim/lazy/muslim.nvim/lua/muslim/prayer_calc.lua` — core trig math (sun position, mid-day, angle time, asr angle, high-lat adjustments, method configs for ISNA/MWL/Egypt/Makkah/etc.)
- `~/.local/share/nvim/lazy/muslim.nvim/lua/muslim/utils.lua` — time formatting, waqt label helpers, warning level logic
- `~/.local/share/nvim/lazy/muslim.nvim/lua/muslim/math.lua` — trig wrappers (sin/cos/tan/arctan2 in degrees)

The Lua script should be **self-contained** (no require statements, no Neovim APIs). It takes config via command-line args or environment variables and prints the status string to stdout.

Usage: `lua scripts/prayer_calc.lua <lat> <lng> <utc_offset|auto> <method> <school> <format> [mode] [timezone]`

Output modes:
- `status` — single-line status string for tmux: `"Asr ends in 1:23 | Maghrib at: 06:17 PM"`
- `times` — all prayer times, one per line: `"Fajr 05:59 AM\nSunrise 07:07 AM\n..."`
- `json` — JSON object of all times (for scripting)

### TPM Entry Point (`muslim-prayers.tmux`)

Follow the standard TPM pattern used by tmux-weather, tmux-battery, tmux-cpu:

1. Source `scripts/helpers.sh`
2. Define interpolation placeholders:
   - `#{prayer_times}` — the status text (e.g., "Asr ends in 1:23 | Maghrib at: 06:17 PM")
   - `#{prayer_times_color}` — color hex based on urgency (green >1hr, orange <1hr, red <30min)
   - `#{prayer_times_icon}` — mosque/prayer icon
3. Replace placeholders in both `status-left` and `status-right` (search both sides)

### Caching (`scripts/prayer_times.sh`)

Follow the tmux-weather caching pattern:
- Store last result and timestamp in tmux options (`@prayer-times-previous-value`, `@prayer-times-previous-update-time`)
- Default refresh interval: 1 minute (configurable via `@prayer-times-interval`)
- On cache miss or expiry, call `prayer_calc.lua` and cache the result

### Configuration (tmux options)

All configurable via `set -g @prayer-times-*` in `.tmux.conf`:

| Option | Default | Description |
|--------|---------|-------------|
| `@prayer-times-latitude` | `32.8140` | Latitude |
| `@prayer-times-longitude` | `-96.9489` | Longitude |
| `@prayer-times-timezone` | `America/Chicago` | IANA timezone (used for DST-aware offset when utc-offset is `auto`) |
| `@prayer-times-utc-offset` | `auto` | UTC offset in hours (`auto` resolves from timezone, explicit value overrides) |
| `@prayer-times-method` | `ISNA` | Calculation method (ISNA, MWL, Egypt, Makkah, Karachi, Tehran, Jafari, France, Russia, Singapore) |
| `@prayer-times-school` | `standard` | School of thought (`standard` or `hanafi`) |
| `@prayer-times-format` | `12H` | Time format (`12H`, `12h`, `24h`) |
| `@prayer-times-interval` | `1` | Refresh interval in minutes |

### Color Coding

The `#{prayer_times_color}` interpolation should return:
- `#008000` (green) when >1 hour until next waqt
- `#ffa500` (orange) when <1 hour
- `#ff2c2c` (red) when <30 minutes

### Catppuccin Integration

Create a sample catppuccin custom module config that users can source:

```tmux
# vim:set ft=tmux:
%hidden MODULE_NAME='ctp_prayer_times'

set-option -ogq "@catppuccin_${MODULE_NAME}_icon" '🕌 '
set-option -ogq "@catppuccin_${MODULE_NAME}_color" '#{l:#{prayer_times_color}}'
set-option -ogq "@catppuccin_${MODULE_NAME}_text" '#{l:#{prayer_times}}'

source-file -F '#{TMUX_PLUGIN_MANAGER_PATH}/tmux/utils/status_module.conf'
```

## Reference: Existing TPM Plugin Patterns

### tmux-weather (xamut/tmux-weather) — simplest reference

**Entry point** (`tmux-weather.tmux`):
- Sources `scripts/helpers.sh`
- Calls `replace_placeholder_in_status_line "weather" "$weather_script" "status-right"`
- The replace function does string substitution: `#{weather}` → `#(/path/to/weather.sh)`

**Caching** (`scripts/weather.sh`):
- Reads `@tmux-weather-interval` (default 15 min)
- Stores `@weather-previous-update-time` and `@weather-previous-value` as tmux options
- On each call: check if delta >= interval, if so re-fetch, otherwise return cached value

**Helpers** (`scripts/helpers.sh`):
- `get_tmux_option "$name" "$default"` — reads tmux option with fallback
- `set_tmux_option "$name" "$value"` — writes tmux option

### tmux-cpu — more advanced (color theming, multiple placeholders)

- Registers multiple interpolations: `#{cpu_percentage}`, `#{cpu_bg_color}`, `#{cpu_fg_color}`, etc.
- Uses `/tmp/tmux-$EUID-cpu/` for file-based caching with configurable TTL
- Color thresholds configurable via `@cpu_low/medium/high_*_color` options

## Quality Checklist

- [ ] `set -euo pipefail` in all bash scripts
- [ ] Works without internet (fully offline calculation)
- [ ] Graceful fallback if `lua` is not found (show error message in status bar)
- [ ] No hardcoded paths — use `$CURRENT_DIR` relative paths
- [ ] No hardcoded prayer profile — every location/method/school/time setting is override-able via tmux options
- [ ] DST-safe behavior when timezone is provided (or explicit documented behavior when using fixed utc-offset)
- [ ] Works on macOS and Linux
- [ ] README with installation, configuration, screenshots placeholder
- [ ] MIT License
