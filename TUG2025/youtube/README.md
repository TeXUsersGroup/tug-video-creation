# Uploading the TUG 2025 talks to YouTube

Scripts to publish the finished videos in `../runners/<token>/<token>-final.mp4`
to the [TeX Users Group channel](https://www.youtube.com/@TeXUsersGroup),
matching the TUG 2024 convention:

- **Title:** `TUG 2025 — <speaker> — <title>` (em-dash separators; trimmed to
  YouTube's 100-character limit).
- **Description:** the talk's abstract, taken from
  `https://tug.org/tug2025/abstracts/<name>.txt` and cleaned to plain text.

## Files

| file | purpose |
|------|---------|
| `talks.tsv` | maps each runner `token` to its abstract name on tug.org |
| `build-descriptions.py` | downloads + cleans abstracts → `desc/<token>.txt` |
| `desc/<token>.txt` | the cleaned description for each talk (review/edit these) |
| `abstracts-raw/` | verbatim downloaded abstracts (reference) |
| `upload.py` | uploads each final video via the API, with title + description |
| `set-metadata.py` | sets title + description on videos uploaded **in the browser** |
| `make-playlist.py` | adds all the talks to a playlist **in program order** |
| `ytcommon.py` | shared helpers (titles, descriptions, auth, matching, playlists) |
| `titles.tsv` | *optional* per-token title overrides (one `token<TAB>title` per line) |
| `matches.tsv` | *optional* manual `token<TAB>videoId` pins (matching) |
| `uploaded.json` | written by `upload.py`: `token → videoId` (resume state) |

## One-time setup

1. **Python deps**

   ```sh
   pip install -r requirements.txt
   ```

2. **YouTube API credentials** (so the scripts may act on your channel)
   - In the [Google Cloud Console](https://console.cloud.google.com/): create a
     project, then **APIs & Services → Enable APIs → YouTube Data API v3**.
   - **OAuth consent screen** (newer console: **Audience**): user type
     *External*. **Keep the publishing status on _Testing_** (do **not** click
     "Publish app"), and under **Test users** add the Google account that
     manages the TUG channel.
   - **Credentials → Create credentials → OAuth client ID → Desktop app**.
     Download the JSON and save it here as **`client_secret.json`**.
   - (`client_secret.json` and the generated `token.json` are git-ignored — never
     commit them.)

   **OAuth consent — getting past the warnings**
   - *"Access blocked: … has not completed the Google verification process"* means
     the app is in **production**. Fix: OAuth consent screen → **Back to testing**,
     and make sure your account is a **Test user**. Verification is only needed for
     public apps; Testing mode is the right setting for uploading your own videos
     (up to 100 test users).
   - On the consent screen you then get *"Google hasn't verified this app"* —
     click **Advanced → Go to … (unsafe)** → **Continue**. "Unsafe" just means
     unverified; it is your own app.
   - **Grant the "Manage your YouTube account" permission.** The narrower
     "Manage your YouTube videos" only allows *uploading* — it is **not** enough
     to edit titles/descriptions (`videos.update`) or manage playlists. If you
     already authorized with only the narrow scope, delete `token.json` and
     re-run to re-authorize.
   - Token note: in Testing mode with these scopes the cached `token.json`
     **expires after 7 days**. Fine for a one-off batch — if it stops working,
     delete `token.json` and re-run. The first run opens a browser to authorize.

## Two ways to publish

### A. Recommended — upload in the browser, set metadata by script

Manual uploads through [YouTube Studio](https://studio.youtube.com) cost **no API
quota** (the quota only applies to API uploads — see below). YouTube uses each
**file name as the initial title**, so after drag-dropping the files they are
titled `schrauwen-keynote-final`, etc. — which `set-metadata.py` uses to match
each video back to its talk and then set the real title + description (a cheap
`videos.update`, ~50 units each).

**Full command sequence, in order**, after the one-time setup above:

```sh
# 0. Upload all 27 files in the browser:
#    drag ../runners/<token>/<token>-final.mp4 into studio.youtube.com
#    (leave the titles as the default file names — the scripts match on them)

cd TUG2025/youtube

# 1. (re)build the descriptions from tug.org   -> desc/<token>.txt
python3 build-descriptions.py

# 2. preview: which uploaded video matched which talk, and the planned text
python3 set-metadata.py --dry-run

# 3. apply the titles + descriptions
python3 set-metadata.py
#    (or, to also publish at the same time:  python3 set-metadata.py --privacy public)

# 4. preview the playlist order (conference-program order)
python3 make-playlist.py --title "TUG 2025" --dry-run

# 5. create the "TUG 2025" playlist and add every talk in program order
python3 make-playlist.py --title "TUG 2025"
```

That's the whole workflow. If a video was renamed and step 2/4 reports it as
*unmatched* or *ambiguous*, pin it by hand in `matches.tsv`
(`<token><TAB><videoId>`) and re-run that step. Every step here is well under the
daily quota, so all 27 can be done in one sitting. The steps are idempotent —
re-running skips/repairs rather than duplicating.

### B. Upload via the API

```sh
python3 build-descriptions.py        # (re)build desc/*.txt from tug.org
python3 upload.py --dry-run          # review every planned title + description
# optionally edit desc/*.txt, or add overrides to titles.tsv
python3 upload.py                    # upload (privacy: private by default)
```

Both paths share the same OAuth setup; the first real run opens a browser to
authorize and caches the token in `token.json`.

### Playlist (in program order)

After the videos exist (either path), collect them into a playlist ordered the
same as the conference program:

```sh
python3 make-playlist.py --title "TUG 2025" --dry-run   # preview the order
python3 make-playlist.py --title "TUG 2025"             # find-or-create + fill
python3 make-playlist.py --playlist-id PLxxxx           # use a specific playlist
```

It matches videos to talks the same way `set-metadata.py` does (file-name title
or already-set title), then adds them in the data-sheet order — which is the
program order — and repositions any that are already present but out of order,
so it is safe to re-run as more videos go up. Playlist edits cost ~50 units
each, well within the daily quota.

### Options

Common flags (see each script's `--help`):

- `--dry-run` — show what would happen, change nothing (all four scripts).
- `--privacy {private,unlisted,public}` — `upload.py` defaults to **private** so
  you can review first; `set-metadata.py` leaves privacy unchanged unless given.
- `--only <token>` — act on a single talk (`upload.py`, `set-metadata.py`).
- `--force` — `upload.py`: re-upload even if already in `uploaded.json`.
- `--category` — YouTube category id (default `28` Science & Technology; `27` Education).
- `make-playlist.py`: `--title "TUG 2025"` (find-or-create) or `--playlist-id PLxxxx`.

## API quota — and how to avoid it

The YouTube Data API has a **default quota of 10,000 units/day**. The operations
cost very differently:

| action | cost | 27 talks |
|--------|------|----------|
| manual upload in the browser (Studio) | **0** (not an API call) | free |
| `videos.update` — edit title/description (`set-metadata.py`) | ~50 units | ~1,400 — one day |
| `videos.insert` — API upload (`upload.py`) | ~1,600 units | ~5 days (only ~6/day) |

So **workflow A** (browser upload + `set-metadata.py`) stays far under the limit
and does everything in one sitting — that's why it's recommended.

If you do use `upload.py` (workflow B), it skips already-uploaded talks (tracked
in `uploaded.json`), so just re-run it once a day for ~5 days until all are done,
or request a quota increase from Google for a single-day batch.

## Notes

- `veytsman-opening` and `fischer-tagging25` have no abstract on tug.org, so
  their description is empty (the Opening had none; Fischer's abstract field is
  blank on the source). Add text by hand in `desc/<token>.txt` if wanted.
- The abstract cleaning is best-effort de-TeXing. `build-descriptions.py` prints
  any LaTeX macro it didn't recognise so you can check those `desc/*.txt`.
- Re-running `build-descriptions.py` overwrites `desc/*.txt`; if you hand-edit a
  description, keep a copy or edit after the final build.
