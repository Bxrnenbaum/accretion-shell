#!/usr/bin/env bash

LAT=48.21
LON=16.37
METRIC=1
MAX_AGE=900

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock"
CACHE="$CACHE_DIR/weather.json"
mkdir -p "$CACHE_DIR"

URL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON"
URL+="&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
URL+="&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto"
[ "$METRIC" = 0 ] && URL+="&temperature_unit=fahrenheit&wind_speed_unit=mph"

age=$MAX_AGE
[ -f "$CACHE" ] && age=$(($(date +%s) - $(stat -c %Y "$CACHE")))

if [ "$age" -ge "$MAX_AGE" ]; then
  tmp=$(mktemp)
  if curl -sf --max-time 8 "$URL" -o "$tmp" && jq -e .current "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$CACHE"
  else
    rm -f "$tmp"
    [ -f "$CACHE" ] && touch "$CACHE"
  fi
fi

[ -f "$CACHE" ] || {
  [ "$1" = desc ] && echo "Weather unavailable"
  exit 0
}

read -r code day temp feels hum wind hi lo < <(jq -r '
  [.current.weather_code, .current.is_day, .current.temperature_2m,
   .current.apparent_temperature, .current.relative_humidity_2m,
   .current.wind_speed_10m, .daily.temperature_2m_max[0], .daily.temperature_2m_min[0]] | @tsv' "$CACHE")

[ "$METRIC" = 1 ] && U="°C" W="km/h" || U="°F" W="mph"
r() { printf '%.0f' "$1"; }

case "$code" in
0)
  i=$([ "$day" = 1 ] && printf '\ue30d' || printf '\ue32b')
  t="Clear"
  ;;
1)
  i=$([ "$day" = 1 ] && printf '\ue30c' || printf '\ue32b')
  t="Mostly clear"
  ;;
2)
  i=$([ "$day" = 1 ] && printf '\ue302' || printf '\ue37e')
  t="Partly cloudy"
  ;;
3)
  i=$(printf '\ue312')
  t="Overcast"
  ;;
45 | 48)
  i=$(printf '\ue313')
  t="Fog"
  ;;
51 | 53 | 55)
  i=$(printf '\ue31b')
  t="Drizzle"
  ;;
56 | 57)
  i=$(printf '\ue3ad')
  t="Freezing drizzle"
  ;;
61)
  i=$(printf '\ue31b')
  t="Light rain"
  ;;
63)
  i=$(printf '\ue318')
  t="Rain"
  ;;
65)
  i=$(printf '\ue318')
  t="Heavy rain"
  ;;
66 | 67)
  i=$(printf '\ue3ad')
  t="Freezing rain"
  ;;
71 | 73 | 75 | 77)
  i=$(printf '\ue31a')
  t="Snow"
  ;;
80 | 81 | 82)
  i=$(printf '\ue319')
  t="Showers"
  ;;
85 | 86)
  i=$(printf '\ue31a')
  t="Snow showers"
  ;;
95)
  i=$(printf '\ue31d')
  t="Thunderstorm"
  ;;
96 | 99)
  i=$(printf '\ue314')
  t="Thunderstorm, hail"
  ;;
*)
  i=$(printf '\ue374')
  t="Unknown"
  ;;
esac

case "$1" in
icon) echo "$i" ;;
temp) echo "$(r "$temp")$U" ;;
head) echo "<span font_family='Symbols Nerd Font'>$i</span>  $(r "$temp")$U" ;;
desc) echo "$t" ;;
extra) echo "feels $(r "$feels")°  ·  ↑$(r "$hi")° ↓$(r "$lo")°  ·  $hum%  ·  $(r "$wind") $W" ;;
esac
