# How the TUG 2025 video cutting was set up (process log)

This document records the **complete, reproducible process** by which the
`TUG2025/` build directory was produced: from the first scan of the raw
recordings, through choosing the best source and detecting every talk's
in/out points, to generating the scripts, CSV and runner directories.

It is written so that the same procedure can be repeated or audited for a
future conference. Where a concrete command is given, it was actually run;
where a helper script was used, its logic is reproduced.

Companion files:
- `README.md` — the short "how to run it" runbook.
- `TUG Meetings Video Data Sheet - 2025.csv` — the resulting timing data.

---

## 0. Inputs

- Raw recordings: `/mnt/disk/TUG2025-Videos/`, reachable here as `raw/`.
- Conference programme: <https://tug.org/tug2025/program.html>
  (Thiruvananthapuram, India; Fri 18 – Sun 20 July 2025; timezone IST = UTC+5:30).
- Reference pipeline: the existing `TUG2024/` directory.

Tooling used throughout: `ffprobe`, `ffmpeg`, ImageMagick (`montage`/`convert`),
`node` + `timesnap` (title cards), `ffmpeg-normalize` (loudness).

---

## 1. First scan — what recordings exist

`find` over the three day folders revealed **three independent capture chains**,
not one:

```
raw/TUG25-day1/
    TUG Day 01 Cloud Recording/   3 files   (Zoom cloud recording)
    Recorder out/                 folders 01-06, .mov + .mp4 (HyperDeck)
    Video out/                    folders 01-04, 100EOS_R/*.MP4 (Canon EOS R)
raw/TUG25-day2/
    Camera/                       folders 01-03 (Canon EOS R)
    Recorder/                     folders 01-04 (HyperDeck)
raw/TUG25-day3/
    Cam/                          folders 1-4   (Canon EOS R)
    Recorder/                     folders 01-03 (HyperDeck)
```

So "multiple versions" = **Zoom cloud** (day 1 only) vs **HyperDeck recorder**
(the broadcast/program output) vs **Canon camera** (raw room camera).

---

## 2. Technical probe of every file

For each file we recorded resolution, duration, fps, and codecs:

```sh
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate \
  -show_entries format=duration -of default=nw=1:nk=1 "$f"
ffprobe -v error -show_entries stream=codec_type,codec_name,sample_rate,channels \
  -of compact=p=1:nk=0 "$f"
```

Findings:

| Source | Resolution | fps | Video codec | Audio |
|---|---|---|---|---|
| Recorder (HyperDeck) | 1920x1080 | **60** | ProRes (day1 folders 01-03) / H.264 | **pcm_s24le** 48 kHz |
| Cloud (Zoom, day 1) | 1920x1080 | 30 | H.264 | AAC 48 kHz |
| Camera (Canon) | 1920x1080 | 30/50 | H.264 | AAC |

All sources are 1080p, but the recorder is 60 fps with uncompressed 24-bit
audio (broadcast quality) and is the **only** program-mix source on days 2-3.

---

## 3. Choosing the best version (visual confirmation)

Resolution alone doesn't say what is *in* the frame. We extracted one
representative frame from each source type and looked at it:

```sh
ffmpeg -ss 00:10:00 -i "<file>" -frames:v 1 -q:v 4 frame.jpg
```

- **Recorder** → full-screen slide with a small speaker picture-in-picture in
  the bottom-right. ← the program mix we want.
- **Cloud** → same composite, but 30 fps / AAC (lower quality).
- **Camera** → speaker only, **no slides**. Not usable as a primary source.

**Decision: use the HyperDeck recorder feed for all talks, all three days.**
The Zoom cloud copy is kept only as a day-1 fallback in case a recorder gap is
found.

---

## 4. Reconstructing each day's timeline

The HyperDeck splits a recording session into numbered chunks, and it **stops**
when recording is paused for a break. Two facts made the timeline recoverable:

1. Each chunk carries an accurate, mutually-consistent creation timestamp:

   ```sh
   ffprobe -v error -select_streams v:0 \
     -show_entries stream_tags=creation_time -of default=nw=1:nk=1 "$f"
   ```

2. `chunk_start + duration` of one chunk equals the `chunk_start` of the next
   **within a session** (seamless auto-split), but there is a multi-minute
   **gap** wherever recording was stopped for a break.

Plotting start-time + duration per chunk, the gaps fell exactly on the
programme's coffee/lunch breaks, which both (a) confirmed the chunk ordering and
(b) grouped the chunks into **session blocks** that map 1:1 onto the programme.

### Concatenated-timeline offset tables

The masters are built by concatenating the chunks **back-to-back with the break
gaps dropped** (nothing happens during a break — recording was off). Therefore
the offset of any moment in a master is the running sum of preceding chunk
durations. These tables (seconds) are the ground truth for every timestamp and
live in `../*.tl`-style form; reproduced here:

**Day 1** (master length 06:16:58)

| concat start | chunk |
|---|---|
| 0:00:00 | Recorder out/01/HyperDeck_0001.mov |
| 0:29:05 | Recorder out/02/HyperDeck_0002.mov |
| 1:05:28 | Recorder out/02/HyperDeck_0003.mov |
| 1:26:22 | Recorder out/03/HyperDeck_0004.mov |
| 1:37:44 | Recorder out/03/HyperDeck_0005.mov |
| 1:43:11 | Recorder out/04/HyperDeck_0007.mp4 |
| 2:20:13 | Recorder out/04/HyperDeck_0008.mp4 |
| 2:52:34 | Recorder out/05/HyperDeck_0001.mp4 |
| 2:56:39 | Recorder out/05/HyperDeck_0002.mp4 |
| 4:58:12 | Recorder out/06/HyperDeck_0001.mp4 |
| 5:38:23 | Recorder out/06/HyperDeck_0002.mp4 |

**Day 2** (master length 05:53:18)

| concat start | chunk |
|---|---|
| 0:00:00 | Recorder/01/HyperDeck_0001.mp4 |
| 1:23:32 | Recorder/02/HyperDeck_0001.mp4 |
| 2:02:39 | Recorder/02/HyperDeck_0002.mp4 |
| 2:47:51 | Recorder/03/HyperDeck_0001.mp4 |
| 3:29:19 | Recorder/03/HyperDeck_0002.mp4 |
| 4:03:33 | Recorder/03/HyperDeck_0003.mp4 |
| 4:46:39 | Recorder/04/HyperDeck_0001.mp4 |
| 5:21:20 | Recorder/04/HyperDeck_0002.mp4 |

**Day 3** (master length 04:35:50)

| concat start | chunk |
|---|---|
| 0:00:00 | Recorder/01/HyperDeck_0001.mp4 |
| 1:05:46 | Recorder/02/HyperDeck_0001.mp4 |
| 1:44:47 | Recorder/02/HyperDeck_0002.mp4 |
| 2:14:54 | Recorder/03/HyperDeck_0001.mp4 |
| 3:17:35 | Recorder/03/HyperDeck_0002.mp4 |
| 3:48:29 | Recorder/03/HyperDeck_0003.mp4 |

(Two negligible artefact chunks — a 4 s `day1 03/HyperDeck_0006.mp4` and a 3 s
`day3 01/HyperDeck_0002.mp4` recorded during breaks — were excluded.)

### Session → programme mapping (sanity check)

Every session block's total content length matched its scheduled span, e.g.
Day 1 block A (Opening + Keynote + CTAN) = 1:43:11 of content vs 08:55-10:40
scheduled. All blocks matched, confirming nothing was mis-ordered or lost.

---

## 5. Detecting the talk borders (the core step)

Within a session the talks run back-to-back. We needed, per talk, the precise
**start** (the talk's title slide appears / speaker begins, after trimming the
chair intro and the holding card) and **end** (final applause, before the next
intro). Target precision: a few seconds.

### 5a. The contact-sheet tool

A helper script (`sheet.sh`, kept in the scratchpad) renders a window of the
**concatenated** timeline as a tiled contact sheet, one frame every *N* seconds,
with the concat-timecode **burned into each frame** in yellow. Its logic:

```sh
# for each time t in [START, END) stepping by INTERVAL:
#   - find which chunk contains concat-time t and the in-chunk offset
#       (using the offset table of section 4)
#   - grab a frame:   ffmpeg -ss <offset> -i <chunk> -frames:v 1 -vf scale=480:-1
#   - label it:       convert ... -annotate "HH:MM:SS"   # the concat time
# then tile them:     montage f_*.jpg -tile 6x -geometry +2+2 sheet.jpg
```

Because the label *is* the concat-timeline time, whatever is read off a sheet is
directly the value that goes into the CSV — no manual arithmetic.

### 5b. Coarse → fine scrubbing

For each session:

1. **Coarse pass** — one sheet at **60 s** interval over the whole session.
   Reading it locates every title slide / transition card / applause to within
   ~1 minute. (The recurring "TUG 2025 / Day n" tandem-bicycle holding card is a
   reliable transition marker.)
2. **Fine pass** — for each boundary, one sheet at **5 s** (sometimes 2 s)
   interval over a ~120 s window around it, to pin the exact second.

Several boundaries moved by 30 s – 4 min between the coarse guess and the fine
result (transition cards happen to land near round-minute marks), so the fine
pass is not optional.

### 5c. Parallelisation

The boundary detection was run as **three parallel agents, one per day**, each
given: the day's offset table, the `sheet.sh` tool, and the day's programme talk
list. Each agent produced the coarse and fine sheets, read them, and returned a
table of start/end concat-timecodes plus notes on anomalies. Day 1 was run twice
and the two passes agreed to within ~2 s, confirming the method is stable.

### 5d. Conventions applied

- **start** = first frame of the talk's title slide, or the speaker clearly
  beginning when there is no distinct title slide; preceding applause, chair
  introduction and holding cards are trimmed.
- **end** = just after the talk/applause, before the next intro. Q&A is kept
  when it flows on with no clean cut.
- Anomalies were recorded in the CSV `Comment` column, e.g. Moore's long remote
  connection setup, Venkatesan's mid-talk screen-share glitch (recovers — not a
  cut), Bhattathiri's slide-less overhead calligraphy demo, and the talks with
  no title slide.

The result is the `part1start`/`part1end` columns of the CSV. The
`Double checked by` column is intentionally left empty for a human spot-check.

---

## 6. Generating the `TUG2025/` build directory

The layout mirrors `TUG2024/`. The supplied `TUG2025` was a symlink to the
videos on `/mnt/disk`; it was converted into a **real directory under the repo**
(necessary so the pipeline's relative symlinks `../../../sources/doit.sh`,
`../common-video-settings.sh` resolve into the repo), with the raw footage kept
on the big disk and reached through symlinks:

```sh
rm TUG2025                                   # removes the symlink only
mkdir TUG2025 && cd TUG2025
ln -s /mnt/disk/TUG2025-Videos raw          # raw recordings
mkdir -p /mnt/disk/TUG2025-Videos/Zoom
ln -s /mnt/disk/TUG2025-Videos/Zoom Zoom    # masters live on the big disk
ln -s ../common-video-settings.sh common-video-settings.sh
ln -s ../TUG-33.png TUG-33.png
mkdir -p sources LB/img leaders prerecorded runners
cp ../TUG2024/LB/leader-board.css LB/
cp ../TUG2024/LB/img/logo-tug-user-group-wh.png LB/img/
```

Files then created:

- **`TUG Meetings Video Data Sheet - 2025.csv`** — one `#`-separated row per
  talk: `token # lecturer # title # master # logopos # part1start # part1end #
  prerec # part3start # part3end # comment # timingby # doublechecked`.
  `master` is `TUG2025-DAYn.mp4`; the timestamps are from section 5. There are
  no pre-recorded talks (the three remote talks were streamed live), so
  `prerec`/`part3*` are empty everywhere.
- **`sources/leader-board.html`** — title-card template (copied from 2024 with
  "TUG 2025").
- **`create-leaders-html.sh`** — fills the template per talk; the date is chosen
  from the `DAY1/DAY2/DAY3` substring of the master name → 18/19/20 July 2025.
- **`create-leaders-mp4.sh`** — renders each card to a 10 s 1080p50 mp4 via
  `timesnap` + `ffmpeg` (unchanged from 2024).
- **`create-runners.sh`** — writes `runners/<token>/config` and symlinks
  `runners/<token>/doit.sh -> ../../../sources/doit.sh` (the shared cutter).
- **`concat-sources.sh`** — **new**: builds the per-day masters (section 7).
- **`.gitignore`** — ignores the `raw` and `Zoom` symlinks.
- **`README.md`**, this **`AUTOGEN.md`**.

Then run (cheap steps executed immediately):

```sh
bash create-leaders-html.sh    # 27 LB/*.html
bash create-runners.sh         # 27 runners/*/{config,doit.sh}
bash create-leaders-mp4.sh     # 27 leaders/*.mp4  (title cards)
```

---

## 7. The per-day master build (`concat-sources.sh`)

Dropping the break gaps means the master's timeline equals the section-4 offset
table, so the CSV timestamps address it directly. Output: `Zoom/TUG2025-DAYn.mp4`.

- **Days 2-3** are uniform H.264, so the chunks are concatenated with the ffmpeg
  concat **demuxer** and the video is **stream-copied** (lossless, fast); only
  the PCM audio is converted to AAC, and the timecode data stream is dropped:
  `-map 0:v:0 -map 0:a:0 -dn -c:v copy -c:a aac -ar 48000 -ac 2`.

- **Day 1** mixes ProRes (.mov, folders 01-03) and H.264 (.mp4, folders 04-06).

  > **Gotcha (learned the hard way).** Do **not** feed mixed codecs to the
  > concat *demuxer*, even when re-encoding. The demuxer assumes one set of
  > stream parameters for the whole virtual file: it sets up a ProRes decoder
  > from the first input, then feeds the later H.264 packets to that ProRes
  > decoder, which dies with `invalid frame header` /
  > `Error submitting packet to decoder: Invalid data found`. The container
  > duration still looks correct, but everything after the ProRes-&gt;H.264
  > boundary (~01:43 into day 1) is corrupt/frozen — i.e. the video looks
  > "cut short".

  Fix — a **two-stage** build (`build_twostage` in `concat-sources.sh`):

  1. Transcode **each chunk separately** to a uniform H.264 intermediate
     `Zoom/parts-day1/NN.mp4`, so each is decoded by its own correct decoder:
     `-fflags +genpts -i CHUNK -map 0:v:0 -map 0:a:0 -dn
      -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -r 50
      -c:a aac -ar 48000 -ac 2`.
     Identical settings give identical SPS/PPS so the parts join cleanly.
  2. Concat the now-uniform intermediates with stream copy:
     `-f concat -safe 0 -i list -map 0:v:0 -map 0:a:0 -dn -c copy`.

  The intermediates are kept, so a failed/interrupted run resumes (already-built
  parts are skipped); delete `Zoom/parts-day1/` to reclaim the space afterwards.

  The fix was verified before the full run by transcoding a 30 s slice of a
  ProRes chunk and a 30 s slice of an H.264 chunk, joining them, and
  decode-checking the result (`ffmpeg -v error -i join.mp4 -f null -`) — zero
  errors across the boundary.

  (An alternative one-command approach is the concat *filter*
  `-i a -i b ... -filter_complex concat=n=N:v=1:a=1`, which gives each input its
  own decoder; the two-stage form was chosen because it is resumable and
  isolates any single bad chunk.)

This is the only long step (Day 1 transcodes ~200 GB of ProRes input).

---

## 8. Cutting a talk (`sources/doit.sh`, unchanged from 2024)

For each `runners/<token>/`, `doit.sh`:

1. adds a silent stereo audio track to the title card → `part0.mp4`;
2. extracts `[part1start, part1end]` from the day master with `-ss/-to`, scales
   if needed, overlays the `TUG-33.png` watermark bottom-right, forces 50 fps;
3. loudness-normalises that segment with `ffmpeg-normalize`;
4. concatenates `part0 + part1` → `<token>-final.mp4`.

(`prerec`/`part3` steps exist in the script but are unused in 2025.)

---

## 9. End-to-end validation

Before committing to the multi-hour Day-1 encode, the whole chain was proven on
one talk: a short 190 s stand-in master was built from the first Day-1 chunk and
`runners/veytsman-opening` was run through `doit.sh`. Result:
`veytsman-opening-final.mp4`, **187.06 s** = 10 s title card + the 2:57 Opening,
1080p H.264 + AAC, TUG watermark correctly overlaid, audio normalised. The
stand-in and test artefacts were then deleted.

---

## 10. What remains for a human

1. Run `bash concat-sources.sh` to build the three masters (Day 1 is slow).
2. Cut all talks: `for d in runners/*/; do (cd "$d" && bash doit.sh); done`.
3. **Spot-check the timestamps** (the `Double checked by` column is empty) —
   they were auto-detected to a few seconds and may want a frame of trimming,
   especially the no-title-slide and remote talks flagged in the CSV `Comment`s.
