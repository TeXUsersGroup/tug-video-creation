#!/bin/bash
#
# Idempotent end-to-end build of all TUG 2026 talk videos.
#
# Re-running is safe: it SKIPS every talk whose final video is already complete
# and only (re)builds the missing or broken ones. "Complete" means the final is
# longer than the 10 s title card alone (a final at ~10 s is just the card, i.e.
# the talk segment failed to build).
#
# Only talks that have a runner directory are processed. Runner dirs are created
# by create-runners.sh only for CSV rows that have timestamps, so untimed Day-2 /
# Day-3 rows are ignored until you scrub them and re-run create-runners.sh — at
# which point this script cuts the new talks and leaves the finished ones alone.
#
#   bash runall.sh          # cut sequentially
#   bash runall.sh 4        # cut up to 4 talks in parallel
#
set -u
cd "$(dirname "$0")"
PAR="${1:-1}"
LOG="runall.log"
LEADER_MAX=11     # a final <= this many seconds is "title card only" -> rebuild

dur(){ ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null; }
complete(){ local f="$1" d; d=$(dur "$f"); [ -n "$d" ] && awk -v x="$d" -v m="$LEADER_MAX" 'BEGIN{exit !(x>m)}'; }
say(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

say "================ runall start (parallel=$PAR) ================"

# 1. Title cards (create-leaders-mp4.sh already skips ones that exist).
say "rendering leader cards (skips existing)..."
bash create-leaders-mp4.sh >>"$LOG" 2>&1
say "leader cards present: $(ls leaders/*.mp4 2>/dev/null | wc -l)"

# 2. Cut talks, skipping any whose final is already complete.
running=0
for d in runners/*/ ; do
  slug=$(basename "$d")
  final="$d/$slug-final.mp4"
  if complete "$final"; then say "[skip] $slug (final $(dur "$final")s)"; continue; fi
  if [ ! -s "leaders/$slug.mp4" ]; then say "[warn] no leader for $slug, skipping"; continue; fi
  say "[cut ] $slug"
  ( cd "$d" && bash doit.sh >doit.log 2>&1 ) &
  running=$((running+1))
  if [ "$running" -ge "$PAR" ]; then wait -n 2>/dev/null || wait; running=$((running-1)); fi
done
wait

# 3. Summary.
say "---------------- summary ----------------"
ok=0; miss=0
for d in runners/*/ ; do
  slug=$(basename "$d")
  if complete "$d/$slug-final.mp4"; then say "  DONE  $slug ($(dur "$d/$slug-final.mp4")s)"; ok=$((ok+1))
  else say "  MISS  $slug"; miss=$((miss+1)); fi
done
say "================ finished: $ok done, $miss missing ================"
