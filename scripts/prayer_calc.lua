#!/usr/bin/env lua

local Calculator = {
  methods = {
    MWL       = { fajr = 18, isha = 17 },
    ISNA      = { fajr = 15, isha = 15 },
    Egypt     = { fajr = 19.5, isha = 17.5 },
    Makkah    = { fajr = 18.5, isha = "90 min" },
    Karachi   = { fajr = 18, isha = 18 },
    Tehran    = { fajr = 17.7, maghrib = 4.5, midnight = "Jafari" },
    Jafari    = { fajr = 16, maghrib = 4, midnight = "Jafari" },
    France    = { fajr = 12, isha = 12 },
    Russia    = { fajr = 16, isha = 15 },
    Singapore = { fajr = 20, isha = 18 },
    defaults  = { isha = 14, maghrib = "1 min", midnight = "Standard" },
  },
  shadow_factor = {
    standard = 1,
    hanafi = 2,
  },
  labels = { "fajr", "dhuhr", "asr", "maghrib", "isha" },
  roundings = {
    up = "ceil",
    down = "floor",
    nearest = "round",
  },
  config = {
    dhuhr = "0 min",
    asr = "standard",
    high_lats = "night_middle",
    tune = {},
    format = "12H",
    rounding = "nearest",
    utc_offset = 0,
    location = { lat = 0, lng = 0 },
    iterations = 1,
    method = "ISNA",
  },
  adjusted = false,
  utc_time = 0,
}

local SECOND = 1000
local MINUTE = 60 * SECOND
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR

local function dtr(d) return d * math.pi / 180 end
local function rtd(r) return r * 180 / math.pi end
local function sin(d) return math.sin(dtr(d)) end
local function cos(d) return math.cos(dtr(d)) end
local function tan(d) return math.tan(dtr(d)) end
local function arcsin(d) return rtd(math.asin(d)) end
local function arccos(d) return rtd(math.acos(d)) end
local function arctan2(y, x)
  if math.atan2 then
    return rtd(math.atan2(y, x))
  end
  return rtd(math.atan(y, x))
end
local function arccot(x) return rtd(math.atan(1 / x)) end
local function mod(a, b) return ((a % b) + b) % b end

local function value(str)
  local s = tostring(str or "")
  local n = s:match("[-+]?[0-9]*%.?[0-9]+")
  return n and tonumber(n) or 0
end

local function is_min(str)
  return tostring(str or ""):find("min", 1, true) ~= nil
end

local function parse_utc_offset(raw)
  local s = tostring(raw or "")
  if s ~= "" and s ~= "auto" then
    local n = tonumber(s)
    if n then return n end
  end

  local z = os.date("%z") or "+0000"
  local sign = z:sub(1, 1) == "-" and -1 or 1
  local hh = tonumber(z:sub(2, 3)) or 0
  local mm = tonumber(z:sub(4, 5)) or 0
  return sign * (hh + (mm / 60))
end

local function round_time(timestamp)
  local rounding = Calculator.roundings[Calculator.config.rounding]
  if not rounding then return timestamp end

  if rounding == "ceil" then
    return math.ceil(timestamp / MINUTE) * MINUTE
  elseif rounding == "floor" then
    return math.floor(timestamp / MINUTE) * MINUTE
  end

  local x = timestamp / MINUTE
  local rx = (x >= 0) and math.floor(x + 0.5) or math.ceil(x - 0.5)
  return rx * MINUTE
end

local function time_to_string(timestamp, utc_offset_minutes, format)
  local offset_minutes = tonumber(utc_offset_minutes) or 0
  local seconds = math.floor(timestamp / 1000) + (offset_minutes * 60)
  local t = os.date("!*t", seconds)
  local hour = t.hour
  local min = t.min

  if format == "24h" then
    return string.format("%02d:%02d", hour, min)
  end

  local am = hour < 12
  local h12 = hour % 12
  if h12 == 0 then h12 = 12 end
  local suffix = am and " AM" or " PM"
  if format == "12h" then
    return string.format("%d:%02d%s", h12, min, suffix)
  end
  return string.format("%02d:%02d%s", h12, min, suffix)
end

local function format_time(timestamp, utc_offset_minutes, format)
  if type(timestamp) ~= "number" or timestamp ~= timestamp then
    return "-----"
  end
  return time_to_string(timestamp, utc_offset_minutes, format)
end

local function update_method()
  local method_adjustments = Calculator.methods[Calculator.config.method] or Calculator.methods.ISNA
  for k, v in pairs(method_adjustments) do
    Calculator.config[k] = v
  end

  for k, v in pairs(Calculator.methods.defaults) do
    if Calculator.config[k] == nil then
      Calculator.config[k] = is_min(v) and value(v) or v
    end
  end
end

local function sun_position(time)
  local lng = Calculator.config.location.lng
  local D = Calculator.utc_time / 86400000 - 10957.5 + value(time) / 24 - lng / 360

  local g = mod(357.529 + 0.98560028 * D, 360)
  local q = mod(280.459 + 0.98564736 * D, 360)
  local L = mod(q + 1.915 * sin(g) + 0.020 * sin(2 * g), 360)
  local e = 23.439 - 0.00000036 * D

  local RA = mod(arctan2(cos(e) * sin(L), cos(L)) / 15, 24)
  return {
    declination = arcsin(sin(e) * sin(L)),
    equation = q / 15 - RA,
  }
end

local function mid_day(time)
  local EqT = sun_position(time).equation
  return mod(12 - EqT, 24)
end

local function asr_angle(school, time)
  local shadow_factor = Calculator.shadow_factor[school] or Calculator.shadow_factor.standard
  local lat = Calculator.config.location.lat
  local decl = sun_position(time).declination
  return -arccot(shadow_factor + tan(math.abs(lat - decl)))
end

local function angle_time(angle, time, direction)
  direction = direction or 1
  local lat = Calculator.config.location.lat
  local decl = sun_position(time).declination
  local numerator = -sin(angle) - sin(lat) * sin(decl)
  local diff = arccos(numerator / (cos(lat) * cos(decl))) / 15
  return mid_day(time) + diff * direction
end

local function adjust_time(time, base, angle, night, direction)
  direction = direction or 1
  local factors = {
    night_middle = 1 / 2,
    one_seventh = 1 / 7,
    angle_based = (1 / 60) * value(angle),
  }
  local portion = (factors[Calculator.config.high_lats] or factors.night_middle) * night
  local time_diff = (time - base) * direction

  if (type(time) ~= "number") or (time_diff > portion) then
    time = base + portion * direction
    Calculator.adjusted = true
  end
  return time
end

local function process_time(times)
  local horizon = 0.833
  local fajr = angle_time(Calculator.config.fajr, times.fajr, -1)
  local sunrise = angle_time(horizon, times.sunrise, -1)
  local dhuhr = mid_day(times.dhuhr)
  local asr = angle_time(asr_angle(Calculator.config.asr, times.asr), times.asr)
  local sunset = angle_time(horizon, times.sunset)
  local maghrib = angle_time(Calculator.config.maghrib, times.maghrib)
  local isha = angle_time(Calculator.config.isha, times.isha)
  local midnight = mid_day(times.midnight) + 12

  return {
    fajr = fajr,
    sunrise = sunrise,
    dhuhr = dhuhr,
    asr = asr,
    sunset = sunset,
    maghrib = maghrib,
    isha = isha,
    midnight = midnight,
  }
end

local function adjust_high_lats(times)
  if Calculator.config.high_lats == "none" then
    return times
  end

  Calculator.adjusted = false
  local night = 24 + times.sunrise - times.sunset

  return {
    fajr = adjust_time(times.fajr, times.sunrise, Calculator.config.fajr, night, -1),
    sunrise = times.sunrise,
    dhuhr = times.dhuhr,
    asr = times.asr,
    sunset = times.sunset,
    maghrib = adjust_time(times.maghrib, times.sunset, Calculator.config.maghrib, night),
    isha = adjust_time(times.isha, times.sunset, Calculator.config.isha, night),
    midnight = times.midnight,
  }
end

local function update_times(times)
  if is_min(Calculator.config.maghrib) then
    times.maghrib = times.sunset + value(Calculator.config.maghrib) / 60
  end

  if is_min(Calculator.config.isha) then
    times.isha = times.maghrib + value(Calculator.config.isha) / 60
  end

  if Calculator.config.midnight == "Jafari" then
    local next_fajr = angle_time(Calculator.config.fajr, 29, -1) / 24
    times.midnight = (times.sunset + (Calculator.adjusted and times.fajr + 24 or next_fajr)) / 2
  end

  times.dhuhr = times.dhuhr + value(Calculator.config.dhuhr) / 60
  return times
end

local function tune_times(times)
  local mins = Calculator.config.tune or {}
  for k, v in pairs(times) do
    if mins[k] then
      times[k] = v + (mins[k] / 60)
    end
  end
  return times
end

local function set_utc_time_for_date(date)
  local local_midnight = os.time({
    year = date.year,
    month = date.month,
    day = date.day,
    hour = 0,
    min = 0,
    sec = 0,
  })
  Calculator.utc_time = (local_midnight + (Calculator.config.utc_offset * 3600)) * 1000
end

local function convert_times(times)
  local lng = Calculator.config.location.lng
  for k, v in pairs(times) do
    local time = v - lng / 15
    local ts = Calculator.utc_time + math.floor(time * 3600000)
    times[k] = round_time(ts)
  end
  return times
end

local function compute_times()
  local times = {
    fajr = 5,
    sunrise = 6,
    dhuhr = 12,
    asr = 13,
    sunset = 18,
    maghrib = 18,
    isha = 18,
    midnight = 24,
  }

  for _ = 1, Calculator.config.iterations do
    times = process_time(times)
  end
  times = adjust_high_lats(times)
  times = update_times(times)
  times = tune_times(times)
  times = convert_times(times)
  return times
end

local function label_for(waqt)
  local labels = {
    fajr = "Fajr",
    sunrise = "Sunrise",
    dhuhr = "Dhuhr",
    asr = "Asr",
    sunset = "Sunset",
    maghrib = "Maghrib",
    isha = "Isha",
    midnight = "Midnight",
  }
  return labels[waqt] or waqt
end

function Calculator.setup(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    if k == "location" then
      Calculator.config.location = {
        lat = tonumber(v.lat) or 0,
        lng = tonumber(v.lng) or 0,
      }
    else
      Calculator.config[k] = v
    end
  end
  update_method()
end

function Calculator.get_times(date)
  if type(date) ~= "table" or not date.year or not date.month or not date.day then
    date = os.date("*t")
  end
  set_utc_time_for_date(date)
  return compute_times()
end

function Calculator.get_current_waqt(now_ms)
  local cur_time = now_ms or (os.time() * 1000)
  local date = os.date("*t", math.floor(cur_time / 1000))
  local waqt_times = Calculator.get_times(date)
  local waqt_order = { "fajr", "dhuhr", "asr", "maghrib", "isha" }
  local cur_waqt_info = {}

  for i = 1, #waqt_order do
    local j = i + 1
    if j > #waqt_order then j = 1 end
    local waqt_start = waqt_times[waqt_order[i]]
    local next_waqt_start = waqt_times[waqt_order[j]]

    if i == #waqt_order then
      next_waqt_start = next_waqt_start + DAY
    end
    local next_waqt_end = next_waqt_start - SECOND

    if cur_time >= waqt_start and cur_time <= next_waqt_end then
      cur_waqt_info = {
        waqt_name = waqt_order[i],
        time_left = next_waqt_end - cur_time,
        next_waqt_start = next_waqt_start,
        next_waqt_name = waqt_order[j],
      }
      break
    end
  end

  if next(cur_waqt_info) == nil then
    for i = 1, #waqt_order do
      local next_waqt_start = waqt_times[waqt_order[i]]
      if cur_time < next_waqt_start then
        cur_waqt_info = {
          next_waqt_start = next_waqt_start,
          next_waqt_name = waqt_order[i],
        }
        break
      end
    end
  end

  if next(cur_waqt_info) == nil then
    cur_waqt_info = {
      next_waqt_start = waqt_times.fajr + DAY,
      next_waqt_name = "fajr",
    }
  end

  return cur_waqt_info
end

function Calculator.format_waqt(waqt_info)
  local offset_minutes = Calculator.config.utc_offset * 60
  local next_start = format_time(waqt_info.next_waqt_start, offset_minutes, Calculator.config.format)
  local next_waqt = waqt_info.next_waqt_name

  return string.format("%s at: %s", label_for(next_waqt), next_start)
end

function Calculator.get_next_refresh_epoch(waqt_info)
  local next_start_ms = tonumber(waqt_info.next_waqt_start) or (os.time() * 1000)
  return math.floor(next_start_ms / 1000) + 60
end

function Calculator.get_warning_color(waqt_info)
  return "#008000"
end

local function formatted_times_for(date)
  local raw = Calculator.get_times(date)
  local formatted = {}
  local offset_minutes = Calculator.config.utc_offset * 60
  for _, label in ipairs(Calculator.labels) do
    formatted[label] = format_time(raw[label], offset_minutes, Calculator.config.format)
  end
  return formatted
end

local function json_escape(s)
  local escaped = tostring(s or "")
  escaped = escaped:gsub("\\", "\\\\")
  escaped = escaped:gsub("\"", "\\\"")
  escaped = escaped:gsub("\n", "\\n")
  return escaped
end

local function print_times(date)
  local formatted = formatted_times_for(date)
  for _, label in ipairs(Calculator.labels) do
    print(string.format("%s %s", label_for(label), formatted[label]))
  end
end

local function print_json(date)
  local times = formatted_times_for(date)
  local waqt = Calculator.get_current_waqt()
  local status = Calculator.format_waqt(waqt)
  local color = Calculator.get_warning_color(waqt)
  local next_refresh_epoch = Calculator.get_next_refresh_epoch(waqt)
  local next_waqt_start = math.floor((waqt.next_waqt_start or 0) / 1000)
  local next_waqt_name = waqt.next_waqt_name or "fajr"

  local parts = {}
  table.insert(parts, "{")
  table.insert(parts, "\"status\":\"" .. json_escape(status) .. "\",")
  table.insert(parts, "\"color\":\"" .. json_escape(color) .. "\",")
  table.insert(parts, "\"utc_offset\":" .. tostring(Calculator.config.utc_offset) .. ",")
  table.insert(parts, "\"next_waqt_name\":\"" .. json_escape(next_waqt_name) .. "\",")
  table.insert(parts, "\"next_waqt_start\":" .. tostring(next_waqt_start) .. ",")
  table.insert(parts, "\"next_refresh_epoch\":" .. tostring(next_refresh_epoch) .. ",")
  table.insert(parts, "\"times\":{")
  for i, label in ipairs(Calculator.labels) do
    local suffix = (i < #Calculator.labels) and "," or ""
    table.insert(parts, string.format("\"%s\":\"%s\"%s", label, json_escape(times[label]), suffix))
  end
  table.insert(parts, "}")
  table.insert(parts, "}")
  print(table.concat(parts))
end

local latitude = tonumber(arg[1] or "32.8140") or 32.8140
local longitude = tonumber(arg[2] or "-96.9489") or -96.9489
local utc_offset = parse_utc_offset(arg[3] or "auto")
local method = arg[4] or "ISNA"
local school = arg[5] or "standard"
local time_format = arg[6] or "12H"
local mode = arg[7] or "status"

Calculator.setup({
  location = { lat = latitude, lng = longitude },
  utc_offset = utc_offset,
  asr = school,
  method = method,
  format = time_format,
})

local today = os.date("*t")

if mode == "times" then
  print_times(today)
  os.exit(0)
end

if mode == "json" then
  print_json(today)
  os.exit(0)
end

if mode == "cache" then
  local current_waqt = Calculator.get_current_waqt()
  print(Calculator.format_waqt(current_waqt))
  print(Calculator.get_warning_color(current_waqt))
  print(Calculator.get_next_refresh_epoch(current_waqt))
  os.exit(0)
end

local current_waqt = Calculator.get_current_waqt()
if mode == "color" then
  print(Calculator.get_warning_color(current_waqt))
else
  print(Calculator.format_waqt(current_waqt))
end
