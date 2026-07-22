# How the TUG 2026 video cutting was set up (process log)

This document records the **complete, reproducible process** by which the
`TUG2026/` build directory was produced. It mirrors `TUG2025/AUTOGEN.md`, but
the 2026 source material is much simpler, so several 2025 steps disappear.

Companion files:
- `README.md` — the short "how to run it" runbook.
- `TUG Meetings Video Data Sheet - 2026.csv` — the resulting timing data.
- `sheet.sh` — the contact-sheet tool used for boundary detection.

---

## 0. Inputs

- Raw recordings: `/run/media/norbert/…/TUG2026-Videos/`, reached here as `raw/`.
- Conference programme: <https://tug.org/tug2026/program.html>
  (Calgary, Alberta, Canada; Fri 18 – Sun 19 July 2026; Mountain Time = UTC-6).
- Reference pipeline: the existing `TUG2025/` directory.

Tooling: `ffprobe`, `ffmpeg`, ImageMagick (`convert`/`montage`), `node` +
`timesnap` (title cards), `ffmpeg-normalize` (loudness).

---

## 1. First scan — what recordings exist

In contrast to 2025 (three days × three independent capture chains, auto-split
into numbered HyperDeck chunks) 2026 is essentially **one continuous file per
day** — except Day 3, which arrived as two parts (see below):

```
raw/tug2026-07-17.mkv    Day 1 / Friday    30301 s (~8h25m)   23.4 GB
raw/tug2026-07-18.mkv    Day 2 / Saturday  29970 s (~8h19m)   23.2 GB
raw/tug2026-07-19a.mkv   Day 3 / Sunday    21850 s (~6h04m)   16.9 GB  (part 1)
raw/tug2026-07-19b.mkv   Day 3 / Sunday     5451 s (~1h31m)    4.2 GB  (part 2)
raw/tug2026-07-19.mkv    Day 3 concat      27301 s (~7h35m)   21.0 GB  (a+b, built here)
```

**Day 3 was recorded in two files** (the capture was stopped and restarted at
the miller→nice talk transition). Part `a` also had *no duration/index stored*
(unfinalised capture), so nothing could seek or cut it. Both problems were
solved at once by losslessly concatenating the parts into a single, properly
indexed master:

```sh
printf "file '%s/tug2026-07-19a.mkv'\nfile '%s/tug2026-07-19b.mkv'\n" "$RAW" "$RAW" > list.txt
ffmpeg -f concat -safe 0 -i list.txt -map 0:v:0 -map 0:a:0 -c copy raw/tug2026-07-19.mkv
```

The parts share codec parameters (hevc 1080p + aac 48 kHz stereo), so `-c copy`
joins them with no re-encode and no junction warnings; the resulting timeline is
continuous (the b-part offsets simply follow the a-part). The join lands at
≈06:04:10, inside the `nice-3dsimple` title-card→title-slide transition, so that
talk's cut spans the seam transparently. From here Day 3 is timed and cut
exactly like a single-file day.

There is a single program-mix track — no separate camera/recorder/cloud feeds to
choose between.

---

## 2. Technical probe

```sh
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate,sample_rate,channels \
  -of compact=p=1:nk=0 raw/tug2026-07-17.mkv
```

| Stream | Codec | Details |
|---|---|---|
| video | **hevc (H.265)** | 1920x1080, **30 fps** |
| audio | aac | 48 kHz, 2 ch |

A single extracted frame confirmed the content: full-screen slide with a small
speaker picture-in-picture in the **top-right**, plus a slide **header bar that
carries the talk title** — which makes talks trivial to identify from thumbnails.
This is the program mix we want. (2025 was 1080p60 PCM from a HyperDeck; 2026 is
1080p30 HEVC/AAC — lower bitrate but the same composite.)

---

## 3. Choosing the best version

Not applicable in 2026 — there is only one feed. Decision: **use the single
day recording directly.**

---

## 4. Reconstructing the timeline

Also much simpler than 2025. The recording ran **continuously through the
breaks** (the file is ~8h25m, spanning the whole ~08:00–16:30 day), so the file
timeline *is* the master timeline: a CSV timestamp is a plain offset into the
day `.mkv`. The break/lunch dead-time simply sits between talks and is trimmed
out by each talk's in/out points. There is **no concatenation and no offset
table** — hence no `concat-sources.sh`.

Consequently the "masters" are just symlinks (no re-encode):

```sh
ln -s raw/tug2026-07-17.mkv Zoom/TUG2026-DAY1.mkv
ln -s raw/tug2026-07-18.mkv Zoom/TUG2026-DAY2.mkv
ln -s raw/tug2026-07-19.mkv Zoom/TUG2026-DAY3.mkv   # once present
```

---

## 5. Detecting the talk borders (the core step)

Same contact-sheet method as 2025, adapted to a single file (`sheet.sh`): render
a window of the day master as a tiled sheet, one frame every *N* seconds, with
the **master timecode burned into each tile in yellow**. Because the label *is*
the master time, whatever is read off a sheet is directly the CSV value.

Two features of the 2026 stream make boundaries easy to read:

1. Between talks the stream shows a **dark agenda/schedule card** (the day's
   programme with times) — the reliable transition marker (the equivalent of
   2025's tandem-bicycle holding card).
2. Each talk is introduced by a **generated dark "Title / Speaker" title card**
   (hexagon background, "TUG2026", the date), and every content slide carries
   the **talk title in its header bar**.

Procedure per day:

1. **Coarse pass** — sheets at **300 s** over the whole day (here, 0…30301 s in
   2 h blocks). Reading them maps every talk (by header-bar title) and locates
   each talk↔talk / talk↔break transition to within one 5-min cell.
2. **Fine pass** — for each boundary, a sheet at **10 s** over a ~6–11 min
   window straddling it, to pin the exact second.

Conventions applied (as in 2025):

- **start** = first frame of the talk's title card / title slide (the preceding
  agenda card and applause are trimmed).
- **end** = just after the talk/applause, before the next agenda card. Q&A is
  kept when it flows on with no clean cut (e.g. speaker-only or a static
  "Thank you"/"Connect with us" slide during discussion).
- Anomalies noted in the CSV `Comment` column.

### Day 1 result (Friday 17 July 2026, master `TUG2026-DAY1.mkv`)

| token | start | end | note |
|---|---|---|---|
| nijenhuis-opening | 00:23:15 | 00:25:18 | |
| krishnan-tables | 00:25:25 | 00:45:35 | remote (Zoom PiP) |
| beeton-history | 00:46:25 | 01:17:55 | |
| asakura-jptex | 01:18:25 | 02:01:25 | |
| fischer-tagging26 | 02:27:15 | 02:57:45 | Q&A over teddy "thank you" slide kept |
| nijenhuis-accessiblelists | 02:57:55 | 03:15:55 | |
| erickson-accessibility | 03:16:25 | 04:14:45 | long Q&A on closing slide before lunch |
| mittelbach-accessibleclasses | 05:13:35 | 05:59:55 | |
| prescott-book-accessibility | 06:00:05 | 06:34:12 | back-to-back same speaker; ~6 min discussion before next |
| prescott-ltx-talk | 06:34:12 | 07:02:05 | |
| preining-math-accessibility | 07:26:25 | 08:02:45 | |
| nijenhuis-travels | 08:03:05 | 08:24:20 | last talk; "End" card at 08:24:30 |

Breaks fell exactly where expected: 10:30 break at ≈02:01–02:27, lunch at
≈04:15–05:13, 15:30 break at ≈07:02–07:26 — confirming nothing was mis-ordered.

### Day 2 result (Saturday 18 July 2026, master `TUG2026-DAY2.mkv`)

Timed once the file finished copying (29970 s ≈ 8h19m). Each talk is introduced
by a generated dark "Title / Speaker" card; starts are taken from that card.

| token | start | end | note |
|---|---|---|---|
| rishi-speed | 00:51:30 | 01:18:35 | remote (Zoom); on-camera Q&A kept; follows an "Announcements" card |
| starynovotny-expl3tools | 01:19:50 | 01:52:05 | brief false "thank you" mid-talk, then more content |
| arora-engdoc | 01:52:10 | 02:35:15 | |
| lode-realtime | 02:53:00 | 03:26:25 | remote; long on-camera Q&A kept; Nelson-Beebe session card trimmed |
| adhiyaman-structure | 03:26:50 | 03:51:15 | |
| preining-arxiv-process | 03:51:20 | 04:26:35 | ends just before the "Lunch" card |
| starynovotny-markdown-abbrev | 05:50:10 | 06:13:15 | first afternoon talk (after lunch + group photo) |
| nijenhuis-exectemplates | 06:13:40 | 06:30:55 | |
| lienhard-mitthesis | 06:31:00 | 07:16:15 | |
| bonnetsmueller-dante | 07:49:20 | 07:55:25 | short talk; ends on "Karl Berry honorary member" slide |
| gerrard-literate | 07:56:20 | 08:19:20 | last recorded talk; file ends on its closing thanks |
| berry-agm | — | — | **not in the recording** — the file ends (~08:19:30) as the AGM begins |

Breaks: 10:30 break at ≈02:35–02:53, lunch + participant group photo at
≈04:27–05:50, 15:30 break at ≈07:16–07:49. The `berry-agm` row is kept in the
CSV with empty timestamps (so `create-runners.sh` skips it) and a comment noting
the recording stops before the AGM.

### Day 3 result (Sunday 19 July 2026, master `TUG2026-DAY3.mkv` = a+b concat)

Timed on the concatenated master (27301 s ≈ 7h35m). Talk order matches the CSV
skeleton; starts are on each talk's generated dark title card (or, where none
was generated, the talk's own title slide).

| token | start | end | note |
|---|---|---|---|
| rajeesh-malayalam-archiving | 00:09:30 | 00:32:25 | remote; on-camera Q&A kept; follows an "Announcements" card |
| metelka-utfpatgen | 00:40:00 | 01:04:15 | remote (both presenters); title card flashed at 00:33:40 then ~6 min setup before the real start |
| verna-lastline | 01:06:50 | 01:54:55 | long in-person Q&A (speaker + slides) kept |
| goulet-ctansubmit | 02:10:10 | 02:47:35 | |
| desouza-detex | 02:48:00 | 03:22:05 | remote; on-camera Q&A kept |
| stephan-humanities | 03:23:00 | 04:00:55 | ends just before the "Lunch" card |
| temple-nasa | 04:58:20 | 05:20:05 | remote; on-camera Q&A kept; first afternoon talk |
| miller-sshrc | 05:25:00 | 06:03:55 | |
| nice-3dsimple | 06:04:00 | 06:33:15 | spans the a/b file join (≈06:04:10) — seamless in the concat |
| bowman-asymptote26 | 06:37:50 | 07:34:05 | last full talk |
| nijenhuis-closing | — | — | **not usable** — only the ~10 s title card (07:34:50); the recording ends 07:35:00 |

Breaks: 10:30 break at ≈01:55–02:10, lunch at ≈04:01–04:58, afternoon break at
≈06:33–06:38. Like `berry-agm` on Day 2, `nijenhuis-closing` keeps its CSV row
with empty timestamps (so `create-runners.sh` skips it) and a comment noting the
recording stops at its title card.

---

## 6. Generating the `TUG2026/` build directory

Layout mirrors `TUG2025/`:

```sh
mkdir TUG2026 && cd TUG2026
ln -s /run/media/…/TUG2026-Videos raw
ln -s ../common-video-settings.sh common-video-settings.sh
ln -s ../TUG-33.png TUG-33.png
mkdir -p sources LB/img leaders prerecorded runners Zoom
ln -s raw/tug2026-07-17.mkv Zoom/TUG2026-DAY1.mkv        # + DAY2, DAY3
cp ../TUG2025/LB/leader-board.css LB/
cp ../TUG2025/LB/img/logo-tug-user-group-wh.png LB/img/
```

Files created/adapted from 2025:

- **`TUG Meetings Video Data Sheet - 2026.csv`** — one `#`-separated row per
  talk (35 rows: 12 Day-1 timed, plus Days 2–3 skeleton). `master` is
  `TUG2026-DAYn.mkv`. Tokens are the website's abstract slugs (e.g.
  `beeton-history`, `verna-lastline`). No pre-recorded talks (remote speakers
  are streamed live and captured in the recording), so `prerec`/`part3*` are
  empty everywhere.
- **`sources/leader-board.html`** — title-card template ("TUG 2026").
- **`create-leaders-html.sh`** — fills the template per talk; date from the
  `DAYn` substring of the master name → 17/18/19 July 2026.
- **`create-leaders-mp4.sh`** — renders each card to a 10 s 1080p50 mp4 via
  `timesnap` + `ffmpeg` (unchanged from 2025).
- **`create-runners.sh`** — writes `runners/<token>/config` and symlinks
  `doit.sh -> ../../../sources/doit.sh` (the shared cutter, unchanged).
- **`sheet.sh`** — the contact-sheet tool (new; single-file variant).
- **`.gitignore`**, **`README.md`**, this **`AUTOGEN.md`**.

There is deliberately **no `concat-sources.sh`** (nothing to concatenate).

Cheap steps run at setup (they skip rows with empty `part1start`, so only Day 1
was materialised):

```sh
bash create-leaders-html.sh    # 12 LB/*.html (Day 1)
bash create-runners.sh         # 12 runners/*/{config,doit.sh} (Day 1)
```

---

## 7. Cutting a talk (`sources/doit.sh`, unchanged from 2025)

For each `runners/<token>/`, `doit.sh`:

1. adds a silent stereo track to the title card → `part0.mp4`;
2. extracts `[part1start, part1end]` from the day master with `-ss/-to`, scales
   if needed, overlays the `TUG-33.png` watermark bottom-right, forces 50 fps
   → `part1-pre.mp4`;
3. loudness-normalises that segment with `ffmpeg-normalize`;
4. concatenates `part0 + part1` → `<token>-final.mp4`.

Cutting straight from the HEVC `.mkv` works fine — ffmpeg decodes H.265 and
re-encodes each segment to H.264/50 fps.

---

## 8. End-to-end validation

The chain was proven on `runners/nijenhuis-opening` (the 2:03 Opening,
00:23:15–00:25:18 of Day 1). The extract/scale/watermark step produced a correct
**1920x1080 H.264 50 fps** segment (123.0 s) with the TUG watermark overlaid
bottom-right and the right content (Nijenhuis at the podium). Only the audio
loudness step could not run in the setup environment — see below.

---

## 9. What remains for a human

1. `ffmpeg-normalize` (`doit.sh` step 3) — **installed**. Verified working.
2. **Title cards** — `bash create-leaders-mp4.sh`. Verified working: `node` +
   the puppeteer-bundled Chromium (`timesnap/node_modules/puppeteer/.local-chromium`)
   render each card fine, and the template's anime.js loads from cdnjs (needs
   network). Budget ~70–90 s per card (500 frames), ~15 min for all 12; the
   script skips any card already built. (The Fontconfig lines it prints are
   harmless system-config warnings, not errors.)
3. Cut all Day-1 talks: `for d in runners/*/; do (cd "$d" && bash doit.sh); done`.
4. **Spot-check the Day-1 timestamps** (the `Double checked by` column is empty)
   — auto-detected to a few seconds; watch the flagged rows (erickson long Q&A,
   the two back-to-back Prescott talks, the remote krishnan talk).
5. When the **Day 2 and Day 3** recordings are complete on disk, add the
   `Zoom/TUG2026-DAY{2,3}.mkv` symlinks (already created for Day 2), run the
   coarse+fine `sheet.sh` procedure to fill their CSV timestamps, then re-run
   `create-leaders-html.sh` / `create-runners.sh` and cut.
