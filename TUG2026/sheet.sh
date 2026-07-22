#!/bin/bash
#
# Contact-sheet tool for locating talk borders in a TUG2026 day master.
#
# Unlike 2025 (many HyperDeck chunks + an offset table), each 2026 day is a
# SINGLE continuous recording, so the sheet time == the master's own time.
# The timecode burned into each tile is therefore exactly the value that goes
# into the CSV part1start/part1end columns.
#
# Usage:  bash sheet.sh MASTER START END INTERVAL [OUT.jpg] [COLS]
#   MASTER    path to the day .mkv (e.g. Zoom/TUG2026-DAY1.mkv)
#   START/END times in seconds or HH:MM:SS
#   INTERVAL  seconds between sampled frames
# Example (coarse): bash sheet.sh Zoom/TUG2026-DAY1.mkv 0 30301 300 sheets/d1-coarse.jpg
# Example (fine):   bash sheet.sh Zoom/TUG2026-DAY1.mkv 03:20:00 03:24:00 5 sheets/fine.jpg

set -u
MASTER="$1"; START="$2"; END="$3"; INTERVAL="$4"
OUT="${5:-sheet.jpg}"; COLS="${6:-6}"

to_sec() { case "$1" in *:*) awk -F: '{n=NF; s=0; for(i=1;i<=n;i++) s=s*60+$i; print s}' <<<"$1";; *) echo "$1";; esac; }
hms() { printf '%02d:%02d:%02d' $(( $1/3600 )) $(( ($1%3600)/60 )) $(( $1%60 )); }

s=$(to_sec "$START"); e=$(to_sec "$END")
tmp=$(mktemp -d)
i=0
t=$s
while [ "$t" -lt "$e" ]; do
  lbl=$(hms "$t")
  f=$(printf '%s/f_%05d.jpg' "$tmp" "$i")
  ffmpeg -hide_banner -loglevel error -ss "$t" -i "$MASTER" -frames:v 1 -vf "scale=480:-1" -q:v 4 "$f" 2>/dev/null
  # burn the master timecode in yellow, top-left
  convert "$f" -gravity NorthWest -pointsize 26 -fill yellow -stroke black -strokewidth 1 \
    -annotate +6+6 "$lbl" "$f" 2>/dev/null
  i=$((i+1)); t=$((t+INTERVAL))
done
mkdir -p "$(dirname "$OUT")"
montage "$tmp"/f_*.jpg -tile "${COLS}x" -geometry +2+2 "$OUT"
echo "wrote $OUT  ($i frames, ${START}..${END} step ${INTERVAL}s)"
rm -rf "$tmp"
