# TUG 2026 video cutting

Same pipeline as `TUG2025/`, adapted for the 2026 source material.

## Source: which version is used

TUG 2026 was recorded in Calgary (Mountain Time), Fri 17 – Sun 19 July 2026, one
session track in the Indigo Room. Unlike 2025 there is a **single continuous
program-mix recording per day** (full-screen slides with a small speaker
picture-in-picture in the top-right, 1920x1080, 30 fps, HEVC/H.265 video, AAC
audio). There are no alternate camera/recorder feeds to choose between and no
per-session chunking, so there is nothing to concatenate.

Raw day recordings live on the big disk and are reached through the `raw`
symlink:

    raw/tug2026-07-17.mkv   Day 1 / Friday 17 July   (~8h25m)
    raw/tug2026-07-18.mkv   Day 2 / Saturday 18 July
    raw/tug2026-07-19.mkv   Day 3 / Sunday 19 July

## The per-day "master" files

Because each day is already one continuous file, the masters are just symlinks
(no re-encode, no concat) in `Zoom/`:

    Zoom/TUG2026-DAY1.mkv -> raw/tug2026-07-17.mkv
    Zoom/TUG2026-DAY2.mkv -> raw/tug2026-07-18.mkv
    Zoom/TUG2026-DAY3.mkv -> raw/tug2026-07-19.mkv

**All timestamps in the CSV are plain offsets into these day recordings** (the
recording ran continuously through the breaks, so the file time == wall-clock
time from the recording start; the break dead-time simply sits between talks and
is trimmed out by the per-talk in/out points). `doit.sh` extracts and re-encodes
each cut segment, so cutting straight from the HEVC master is fine — there is no
separate master-build step to run.

## Run order

```sh
cd TUG2026

# 1. (no concat-sources.sh needed — masters are direct symlinks to the day .mkv)

# 2. Generate the title-card HTML pages from the CSV.
bash create-leaders-html.sh

# 3. Render the title cards to mp4 (needs ../timesnap + node + a chromium that
#    puppeteer can drive; the template pulls anime.js from cdnjs, so this step
#    needs network).
bash create-leaders-mp4.sh

# 4. Create one runner directory per talk (config + symlink to sources/doit.sh).
bash create-runners.sh

# 5. Cut every talk: title card + watermarked talk segment, audio-normalized.
for d in runners/*/ ; do ( cd "$d" && bash doit.sh ) ; done
#    Each produces runners/<token>/<token>-final.mp4
#    Re-run a single talk:   cd runners/<token> && bash doit.sh
#    "bash doit.sh missing"  only (re)builds parts that are absent.
```

Steps 2 and 4 skip any CSV row whose `part1start` is still empty, so they are
safe to run now (only Day 1 is timed) and again later once Days 2–3 are added.

## Locating the talk in/out points

`sheet.sh` renders a window of a day master as a tiled contact sheet, one frame
every N seconds, with the master timecode burned into each tile in yellow — so
whatever you read off a sheet is directly the CSV value. Coarse pass at 300 s to
map the day, then a fine pass at 10 s around each boundary. See `AUTOGEN.md` for
the full procedure and the Day-1 result.

    bash sheet.sh Zoom/TUG2026-DAY1.mkv 0 30301 300 sheets/d1-coarse.jpg   # coarse
    bash sheet.sh Zoom/TUG2026-DAY1.mkv 02:00:00 02:07:00 10 sheets/fine.jpg

## Timestamps

`TUG Meetings Video Data Sheet - 2026.csv` (fields `#`-separated):

    token # lecturer # title # master # logopos # part1start # part1end #
    prerec # part3start # part3end # comment # timingby # doublechecked

`part1start`/`part1end` are the in/out points of the talk inside the day master.
They were located automatically by scrubbing each talk-to-talk transition
(stream title-card in / last content or applause before the next agenda card).
**They should be spot-checked** before publishing (the `Double checked by`
column is empty).

Status: **Day 1 (Friday) is fully timed** (12 talks). **Days 2 and 3 rows are
present as a skeleton with empty timestamps** — fill them once those recordings
are on disk (Day 3 was not yet present when this was set up; the Day-2 file was
still copying). The remote talks are streamed live and captured in the recording,
so `prerec`/`part3*` are empty everywhere (no separate pre-recorded files).
