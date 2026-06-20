#!/bin/bash
#
# Build the per-day "master" recordings used as the cutting source.
#
# The HyperDeck recorder auto-split each session into numbered chunks, and a
# talk can span a chunk boundary. We therefore concatenate, per day, all the
# chunks of that day (in recording order, with the break gaps simply dropped
# because recording was stopped during breaks) into a single continuous file
# Zoom/TUG2025-DAYn.mp4.  All per-talk timestamps in the CSV are offsets into
# these concatenated masters.
#
# IMPORTANT: the chunk order below MUST match the order the timestamps were
# measured against (see the day?.tl timeline files).  Do not reorder.
#
# Day 1 mixes ProRes (.mov, folders 01-03) and H.264 (.mp4, folders 04-06),
# so its video must be re-encoded.  Days 2 and 3 are uniform H.264 and are
# stream-copied (lossless, fast); only the PCM audio is converted to AAC.

set -u
ffmpeg="ffmpeg -hide_banner -loglevel error -stats -y"
RAW="raw"            # symlink to the raw recordings tree
OUT="Zoom"           # symlink to /mnt/disk/.../Zoom (where masters are written)
mkdir -p "$OUT"

# --- chunk lists (recording order) ----------------------------------------
day1=(
  "$RAW/TUG25-day1/Recorder out/01/HyperDeck_0001.mov"
  "$RAW/TUG25-day1/Recorder out/02/HyperDeck_0002.mov"
  "$RAW/TUG25-day1/Recorder out/02/HyperDeck_0003.mov"
  "$RAW/TUG25-day1/Recorder out/03/HyperDeck_0004.mov"
  "$RAW/TUG25-day1/Recorder out/03/HyperDeck_0005.mov"
  "$RAW/TUG25-day1/Recorder out/04/HyperDeck_0007.mp4"
  "$RAW/TUG25-day1/Recorder out/04/HyperDeck_0008.mp4"
  "$RAW/TUG25-day1/Recorder out/05/HyperDeck_0001.mp4"
  "$RAW/TUG25-day1/Recorder out/05/HyperDeck_0002.mp4"
  "$RAW/TUG25-day1/Recorder out/06/HyperDeck_0001.mp4"
  "$RAW/TUG25-day1/Recorder out/06/HyperDeck_0002.mp4"
)
day2=(
  "$RAW/TUG25-day2/Recorder/01/HyperDeck_0001.mp4"
  "$RAW/TUG25-day2/Recorder/02/HyperDeck_0001.mp4"
  "$RAW/TUG25-day2/Recorder/02/HyperDeck_0002.mp4"
  "$RAW/TUG25-day2/Recorder/03/HyperDeck_0001.mp4"
  "$RAW/TUG25-day2/Recorder/03/HyperDeck_0002.mp4"
  "$RAW/TUG25-day2/Recorder/03/HyperDeck_0003.mp4"
  "$RAW/TUG25-day2/Recorder/04/HyperDeck_0001.mp4"
  "$RAW/TUG25-day2/Recorder/04/HyperDeck_0002.mp4"
)
day3=(
  "$RAW/TUG25-day3/Recorder/01/HyperDeck_0001.mp4"
  "$RAW/TUG25-day3/Recorder/02/HyperDeck_0001.mp4"
  "$RAW/TUG25-day3/Recorder/02/HyperDeck_0002.mp4"
  "$RAW/TUG25-day3/Recorder/03/HyperDeck_0001.mp4"
  "$RAW/TUG25-day3/Recorder/03/HyperDeck_0002.mp4"
  "$RAW/TUG25-day3/Recorder/03/HyperDeck_0003.mp4"
)

# write a concat-demuxer list file for an array of chunks
write_list() {
  local listfile="$1"; shift
  : > "$listfile"
  for f in "$@" ; do
    # absolute path so the list is location-independent
    printf "file '%s'\n" "$(readlink -f "$f")" >> "$listfile"
  done
}

build_twostage() {   # day1: ProRes+H.264 mix.
  # The concat DEMUXER cannot switch codecs mid-stream (it would feed the later
  # H.264 packets to the ProRes decoder set up from the first input -> "invalid
  # frame header"). So transcode each chunk separately to a uniform H.264
  # intermediate (each decoded with its OWN correct decoder), then concat the
  # now-identical intermediates with stream copy. Intermediates are kept so the
  # job is resumable; delete "$partsdir" afterwards if you want the space back.
  local out="$1"; shift
  local partsdir="$OUT/parts-day1"
  local list="/tmp/tug25-d1.list"
  mkdir -p "$partsdir"
  : > "$list"
  local i=0
  for f in "$@" ; do
    local p; p=$(printf '%s/%02d.mp4' "$partsdir" "$i")
    # Skip only if the intermediate exists AND its duration matches the source
    # chunk (within 1s) -- guards against a half-written chunk from an
    # interrupted run being wrongly accepted.
    local sdur idur ok=0
    if [ -s "$p" ] ; then
      sdur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" 2>/dev/null)
      idur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$p" 2>/dev/null)
      if [ -n "$sdur" ] && [ -n "$idur" ] && \
         awk -v a="$sdur" -v b="$idur" 'BEGIN{d=a-b; if(d<0)d=-d; exit !(d<=1.0)}' ; then
        ok=1
      fi
    fi
    if [ "$ok" = 1 ] ; then
      echo "  chunk $i already transcoded ($idur s): $p"
    else
      [ -s "$p" ] && echo "  chunk $i incomplete, rebuilding: $p"
      echo "  transcoding chunk $i: $f"
      $ffmpeg -fflags +genpts -i "$f" \
        -map 0:v:0 -map 0:a:0 -dn \
        -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -r 50 \
        -c:a aac -ar 48000 -ac 2 \
        "$p" || { echo "FAILED transcoding $f" >&2; return 1; }
    fi
    printf "file '%s'\n" "$(readlink -f "$p")" >> "$list"
    i=$((i+1))
  done
  echo "Joining $i intermediates -> $out (stream copy)..."
  $ffmpeg -f concat -safe 0 -i "$list" -map 0:v:0 -map 0:a:0 -dn -c copy "$out"
}

build_copy() {       # day2/day3: uniform H.264; copy video, transcode audio to AAC
  local out="$1" list="$2"
  echo "Building $out (stream-copy video, AAC audio)..."
  $ffmpeg -f concat -safe 0 -i "$list" \
    -map 0:v:0 -map 0:a:0 -dn -c:v copy -c:a aac -ar 48000 -ac 2 \
    "$out"
}

do_day() {
  local which="$1"
  case "$which" in
    1) build_twostage "$OUT/TUG2025-DAY1.mp4" "${day1[@]}" ;;
    2) write_list /tmp/tug25-d2.list "${day2[@]}"; build_copy "$OUT/TUG2025-DAY2.mp4" /tmp/tug25-d2.list ;;
    3) write_list /tmp/tug25-d3.list "${day3[@]}"; build_copy "$OUT/TUG2025-DAY3.mp4" /tmp/tug25-d3.list ;;
    *) echo "unknown day $which" >&2; return 1 ;;
  esac
}

if [ $# -eq 0 ] ; then
  do_day 1; do_day 2; do_day 3
else
  for d in "$@" ; do do_day "$d" ; done
fi

echo "Done. Masters:"
ls -la "$OUT"/TUG2025-DAY*.mp4 2>/dev/null
