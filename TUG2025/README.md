# TUG 2025 video cutting

Same pipeline as `TUG2024/`, adapted for the 2025 source material.

## Source: which version is used

For every talk the **HyperDeck "Recorder" feed** is used (the program mix:
full-screen slides with a small speaker picture-in-picture, 1920x1080, 60 fps,
24-bit PCM audio). This is the highest-quality source and the only program-mix
source for days 2 and 3.

The other recordings are **not** used as the primary source:
- *Video out / Camera / Cam* (Canon EOS R) — speaker only, no slides.
- *TUG Day 01 Cloud Recording* (Zoom, day 1 only) — same composite but lower
  quality (30 fps / AAC). Kept only as a fallback if a recorder gap is found.

The raw recordings live on `/mnt/disk/TUG2025-Videos` and are reachable here
through the `raw` symlink. The cutting masters are written to `Zoom/` (also a
symlink onto that disk).

## The per-day "master" files

The recorder auto-split each session into numbered chunks, and a talk can span
a chunk boundary, so we first concatenate, per day, all chunks of that day in
recording order into one continuous file `Zoom/TUG2025-DAYn.mp4`. Break gaps
are simply dropped (recording was stopped during breaks). **All timestamps in
the CSV are offsets into these concatenated masters.**

Day 1 mixes ProRes and H.264 chunks, so its master is re-encoded to H.264;
days 2 and 3 are uniform H.264 and are stream-copied (only audio -> AAC).

## Run order

```sh
cd TUG2025

# 1. Build the per-day master recordings (writes to Zoom/ on /mnt/disk).
#    Day 1 is a long re-encode (~hours, ProRes input); days 2-3 are fast copies.
bash concat-sources.sh           # or: bash concat-sources.sh 2 3   (single days)

# 2. Generate the title-card HTML pages from the CSV.
bash create-leaders-html.sh

# 3. Render the title cards to mp4 (needs ../timesnap + node + chromium).
bash create-leaders-mp4.sh

# 4. Create one runner directory per talk (config + symlink to sources/doit.sh).
bash create-runners.sh

# 5. Cut every talk: title card + watermarked talk segment, audio-normalized.
for d in runners/*/ ; do ( cd "$d" && bash doit.sh ) ; done
#    Each produces runners/<token>/<token>-final.mp4
#    Re-run a single talk:   cd runners/<token> && bash doit.sh
#    "bash doit.sh missing"  only (re)builds parts that are absent.
```

## Timestamps

`TUG Meetings Video Data Sheet - 2025.csv` (fields `#`-separated):

    token # lecturer # title # master # logopos # part1start # part1end #
    prerec # part3start # part3end # comment # timingby # doublechecked

`part1start`/`part1end` are the in/out points of the talk inside the day master.
They were located automatically by scrubbing each talk-to-talk transition
(title slide in / applause out) to within a few seconds. **They should be
spot-checked** before publishing (the `Double checked by` column is empty).

There are no pre-recorded talks in 2025 (the three remote talks — Moore, Gray,
Osborne — were streamed live), so `prerec` / `part3*` are empty for all entries.
