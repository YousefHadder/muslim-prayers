# muslim-prayers

Offline-first TPM plugin that shows Islamic prayer status in tmux status bar.

## Screenshots

<img width="586" height="28" alt="Screenshot 2026-03-01 at 12 15 29 AM" src="https://github.com/user-attachments/assets/bb10bfee-82e6-47b6-bde6-44f1fd96d5af" />

## Requirements

- `tmux`
- A Lua interpreter (`lua`, `lua5.4`, `lua5.3`, `lua5.2`, or `luajit`)

## Features

- Fully offline prayer-time calculation (ported from `muslim.nvim` logic)
- Configurable location/method/school/time format via tmux options
- DST-safe mode with timezone-aware auto UTC offset
- Next-prayer-focused status text (for example: `Fajr at: 05:49 AM`)
- Displayed schedule is limited to the five daily prayers (no sunrise/sunset in output)
- Cached output via tmux options for low overhead, auto-refreshing one minute after next prayer starts
- Status + static color + icon placeholders

## Installation (TPM)

Add to your `.tmux.conf`:

```tmux
set -g @plugin 'yousefhadder/muslim-prayers'
```

Then reload tmux and install with TPM.

## Placeholders

- `#{prayer_times}`: prayer status text
- `#{prayer_times_color}`: configured static color (default `#89b4fa`)
- `#{prayer_times_icon}`: icon text (default `🕌 `)

Example:

```tmux
set -g status-right '#[fg=#{prayer_times_color}]#[fg=#11111b,bg=#{prayer_times_color}]#{prayer_times_icon}▐#[fg=#cdd6f4,bg=#181825]#{prayer_times}#[default] | %H:%M'
```

## Theme compatibility

This plugin is theme-agnostic. You can use it with any tmux theme by placing `#{prayer_times}`, `#{prayer_times_color}`, and `#{prayer_times_icon}` in `status-left` or `status-right`.

## Configuration

All settings are tmux options (`set -g @prayer-times-*`):

| Option | Default | Description |
| --- | --- | --- |
| `@prayer-times-latitude` | `32.8140` | Latitude |
| `@prayer-times-longitude` | `-96.9489` | Longitude |
| `@prayer-times-timezone` | `America/Chicago` | IANA timezone for local wall-clock + DST |
| `@prayer-times-utc-offset` | `auto` | UTC offset in hours (`auto` uses timezone) |
| `@prayer-times-method` | `ISNA` | Method: ISNA, MWL, Egypt, Makkah, Karachi, Tehran, Jafari, France, Russia, Singapore |
| `@prayer-times-school` | `standard` | `standard` or `hanafi` |
| `@prayer-times-format` | `12H` | `12H`, `12h`, or `24h` |
| `@prayer-times-interval` | `1` | Refresh interval in minutes |
| `@prayer-times-icon` | `🕌 ` | Icon placeholder value |
| `@prayer-times-color` | `#89b4fa` | Static color used by `#{prayer_times_color}` |

Example config:

```tmux
set -g @prayer-times-latitude '32.8140'
set -g @prayer-times-longitude '-96.9489'
set -g @prayer-times-timezone 'America/Chicago'
set -g @prayer-times-utc-offset 'auto'
set -g @prayer-times-method 'ISNA'
set -g @prayer-times-school 'standard'
set -g @prayer-times-format '12H'
set -g @prayer-times-interval '1'
set -g @prayer-times-color '#89b4fa'
```

## Catppuccin module sample

You can source `catppuccin_prayer_times.conf` from this repo, or copy:

```tmux
# vim:set ft=tmux:
%hidden MODULE_NAME='ctp_prayer_times'

set-option -ogq "@catppuccin_${MODULE_NAME}_icon" '🕌 '
set-option -ogq "@catppuccin_${MODULE_NAME}_color" '#{l:#{prayer_times_color}}'
set-option -ogq "@catppuccin_${MODULE_NAME}_text" '#{l:#{prayer_times}}'

source-file -F '#{TMUX_PLUGIN_MANAGER_PATH}/tmux/utils/status_module.conf'
```

## Manual script checks

```bash
bash -n scripts/helpers.sh scripts/prayer_times.sh
lua scripts/prayer_calc.lua 32.8140 -96.9489 auto ISNA standard 12H status America/Chicago
```


## License

MIT
