#!/bin/bash
#
# Unattended end-to-end build of all TUG 2025 talk videos.
# Idempotent / resumable: re-running skips masters, leader cards and talks
# that are already complete. Logs to runall.log.
#
#   bash runall.sh
#
set -u
cd "$(dirname "$0")"
LOG="runall.log"
exec >>"$LOG" 2>&1
say(){ echo "[$(date '+%F %T')] $*"; }

EXPECT_D1=22618; EXPECT_D2=21198; EXPECT_D3=16550

dur(){ ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null; }
master_ok(){ # $1=file $2=expected_seconds
  local f="$1" exp="$2" d; [ -s "$f" ] || return 1
  d=$(dur "$f"); [ -n "$d" ] || return 1
  awk -v a="$d" -v b="$exp" 'BEGIN{x=a-b;if(x<0)x=-x; exit !(x<=3)}'
}

say "================ runall starting ================"

# --- 1. Day-1 master in the background (long; resumable two-stage transcode) --
if master_ok "Zoom/TUG2025-DAY1.mp4" "$EXPECT_D1"; then
  say "Day-1 master already complete, skipping build."
  D1PID=""
else
  say "Starting Day-1 master build in background (concat-sources.sh 1)..."
  bash concat-sources.sh 1 >"concat-day1.log" 2>&1 &
  D1PID=$!
  say "Day-1 build PID=$D1PID"
fi

# --- 2. Day-2 / Day-3 masters (should already exist; build if missing) --------
for d in 2 3; do
  eval exp=\$EXPECT_D$d
  if master_ok "Zoom/TUG2025-DAY$d.mp4" "$exp"; then
    say "Day-$d master OK ($(dur Zoom/TUG2025-DAY$d.mp4)s)."
  else
    say "Day-$d master missing/invalid -> building..."
    bash concat-sources.sh "$d" >>"concat-day$d.log" 2>&1
  fi
  rm -f "Zoom/TUG2025-DAY$d.clean.mp4"
done

# --- 3. Title cards (render any missing) --------------------------------------
say "Rendering leader cards (skips existing)..."
bash create-leaders-mp4.sh >>"leaders.log" 2>&1
say "Leader cards present: $(ls leaders/*.mp4 2>/dev/null | wc -l)/27"

# --- helpers for cutting ------------------------------------------------------
day_slugs(){ for c in runners/*/config; do grep -q "TUG2025-DAY$1.mp4" "$c" && basename "$(dirname "$c")"; done; }

cut_pool(){ # $1=parallelism ; rest=slugs
  local N="$1"; shift
  local running=0 slug final
  for slug in "$@"; do
    final="runners/$slug/$slug-final.mp4"
    if [ -s "$final" ] && [ "$(dur "$final")" != "" ]; then say "[skip] $slug (final exists)"; continue; fi
    [ -s "leaders/$slug.mp4" ] || { say "[WARN] missing leader for $slug, skipping"; continue; }
    say "[cut ] $slug"
    ( cd "runners/$slug" && bash doit.sh >doit.log 2>&1 && echo "ok" >.status || echo "FAIL" >.status ) &
    running=$((running+1))
    if [ "$running" -ge "$N" ]; then wait -n 2>/dev/null || wait; running=$((running-1)); fi
  done
  wait
}

# --- 4. Cut Day-2 and Day-3 talks now (their masters are ready) ---------------
say "Cutting Day-2 and Day-3 talks (parallel=2 while Day-1 still encoding)..."
cut_pool 2 $(day_slugs 2) $(day_slugs 3)
say "Day-2/3 cutting pass complete."

# --- 5. Wait for Day-1 master, then cut Day-1 talks --------------------------
if [ -n "${D1PID:-}" ]; then say "Waiting for Day-1 master build (PID $D1PID)..."; wait "$D1PID"; fi
if master_ok "Zoom/TUG2025-DAY1.mp4" "$EXPECT_D1"; then
  say "Day-1 master OK ($(dur Zoom/TUG2025-DAY1.mp4)s). Cutting Day-1 talks (parallel=4)..."
  cut_pool 4 $(day_slugs 1)
else
  say "[ERROR] Day-1 master did not build correctly; see concat-day1.log. Day-1 talks NOT cut."
fi

# --- 6. Summary --------------------------------------------------------------
say "---------------- summary ----------------"
ok=0; miss=0
for c in runners/*/config; do
  slug=$(basename "$(dirname "$c")")
  if [ -s "runners/$slug/$slug-final.mp4" ]; then
    say "  DONE  $slug ($(dur runners/$slug/$slug-final.mp4)s)"; ok=$((ok+1))
  else
    say "  MISS  $slug"; miss=$((miss+1))
  fi
done
say "Finished: $ok done, $miss missing, out of 27."
say "================ runall complete ================"
