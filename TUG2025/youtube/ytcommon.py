#!/usr/bin/env python3
"""
Shared helpers for the TUG 2025 YouTube scripts (upload.py, set-metadata.py,
make-playlist.py): reading the data sheet, building titles/descriptions,
authenticating, and matching uploaded videos back to talks.
"""
import json, os, re

HERE   = os.path.dirname(os.path.abspath(__file__))
ROOT   = os.path.dirname(HERE)                       # the TUG2025 dir
CSV    = os.path.join(ROOT, "TUG Meetings Video Data Sheet - 2025.csv")
DESC   = os.path.join(HERE, "desc")
STATE  = os.path.join(HERE, "uploaded.json")
SECRET = os.path.join(HERE, "client_secret.json")
TOKEN  = os.path.join(HERE, "token.json")
TITLES = os.path.join(HERE, "titles.tsv")            # optional title overrides
MATCHES = os.path.join(HERE, "matches.tsv")          # optional token<TAB>videoId

PREFIX   = "TUG 2025"
SEP      = " — "                # space em-dash space, as on the channel
MAXTITLE = 100                  # YouTube hard limit
TAGS     = ["TeX", "LaTeX", "TUG", "TUG 2025", "TeX Users Group", "typesetting"]
# youtube.upload -> insert(upload);  youtube -> update/playlists/list-own
SCOPES   = ["https://www.googleapis.com/auth/youtube.upload",
            "https://www.googleapis.com/auth/youtube"]


# ---------- data sheet, titles, descriptions --------------------------------

def read_csv():
    """Yield {token, speaker, title} dicts in CSV (= conference program) order."""
    with open(CSV, encoding="utf-8") as f:
        for row in f:
            row = row.rstrip("\n")
            if not row or row.startswith("#"):
                continue
            c = row.split("#")
            if len(c) < 3 or not c[0] or c[0] == "Token":
                continue
            yield {"token": c[0], "speaker": c[1].strip(), "title": c[2].strip()}


def load_overrides():
    return _load_tsv(TITLES)


def load_manual_matches():
    return _load_tsv(MATCHES)


def _load_tsv(path):
    out = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line or line.startswith("#") or "\t" not in line:
                    continue
                k, v = line.split("\t", 1)
                out[k.strip()] = v.strip()
    return out


def make_title(rec, overrides=None):
    overrides = overrides if overrides is not None else load_overrides()
    if rec["token"] in overrides:
        return overrides[rec["token"]][:MAXTITLE]
    # drop "(remote)" / "(not streamed)" markers, as on the 2024 channel
    title = re.sub(r'\s*\((?:remote|not streamed)\)\s*$', '', rec["title"], flags=re.I)
    full = f"{PREFIX}{SEP}{rec['speaker']}{SEP}{title}"
    if len(full) <= MAXTITLE:
        return full
    head = f"{PREFIX}{SEP}{rec['speaker']}{SEP}"
    budget = MAXTITLE - len(head)
    if budget < 12:
        return full[:MAXTITLE]
    t = title[:budget]
    if " " in t:
        t = t[:t.rstrip().rfind(" ")].rstrip()
    return head + t


def read_desc(token):
    p = os.path.join(DESC, token + ".txt")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return f.read().strip()
    return ""


def load_state():
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save_state(state):
    with open(STATE, "w") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


# ---------- YouTube service + matching --------------------------------------

def get_service():
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request
    from googleapiclient.discovery import build
    import sys
    creds = None
    if os.path.exists(TOKEN):
        creds = Credentials.from_authorized_user_file(TOKEN, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(SECRET):
                sys.exit(f"Missing {SECRET} -- create an OAuth Desktop client "
                         f"(see README.md) and save it there.")
            flow = InstalledAppFlow.from_client_secrets_file(SECRET, SCOPES)
            try:
                creds = flow.run_local_server(port=0)
            except Exception:
                creds = flow.run_console()
        with open(TOKEN, "w") as f:
            f.write(creds.to_json())
    return build("youtube", "v3", credentials=creds)


def norm(s):
    """lowercase, drop a trailing -final, keep only alphanumerics"""
    s = s.strip().lower()
    s = re.sub(r'[\s_-]*final$', '', s)
    return re.sub(r'[^a-z0-9]', '', s)


def list_uploads(yt):
    """Return [(videoId, title)] for every video on the authorised channel."""
    ch = yt.channels().list(part="contentDetails", mine=True).execute()
    uploads = ch["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
    out, page = [], None
    while True:
        r = yt.playlistItems().list(part="snippet,contentDetails",
                                    playlistId=uploads, maxResults=50,
                                    pageToken=page).execute()
        for it in r["items"]:
            out.append((it["contentDetails"]["videoId"], it["snippet"]["title"]))
        page = r.get("nextPageToken")
        if not page:
            break
    return out


def match_videos(yt, recs, overrides=None):
    """Map each talk token to its uploaded videoId.

    Matches by, in priority order: a manual pin in matches.tsv; the final
    title (== make_title, i.e. videos already renamed by set-metadata.py); or
    the upload's file-name title (e.g. "schrauwen-keynote-final").
    Returns (resolved {token: videoId}, ambiguous {token: [ids]}, unmatched [tokens]).
    """
    overrides = overrides if overrides is not None else load_overrides()
    manual = load_manual_matches()
    vids = list_uploads(yt)
    by_title = {make_title(r, overrides): r["token"] for r in recs}
    by_norm  = {norm(r["token"]): r["token"] for r in recs}
    found = {}
    for vid, title in vids:
        tok = by_title.get(title) or by_norm.get(norm(title))
        if tok:
            found.setdefault(tok, []).append(vid)
    for tok, vid in manual.items():
        found[tok] = [vid]
    resolved, ambiguous, unmatched = {}, {}, []
    for r in recs:
        c = found.get(r["token"], [])
        if len(c) == 1:
            resolved[r["token"]] = c[0]
        elif len(c) > 1:
            ambiguous[r["token"]] = c
        else:
            unmatched.append(r["token"])
    return resolved, ambiguous, unmatched


# ---------- playlists -------------------------------------------------------

def find_playlist(yt, title):
    page = None
    while True:
        r = yt.playlists().list(part="snippet", mine=True,
                                maxResults=50, pageToken=page).execute()
        for it in r["items"]:
            if it["snippet"]["title"] == title:
                return it["id"]
        page = r.get("nextPageToken")
        if not page:
            return None


def create_playlist(yt, title, privacy="public", description=""):
    r = yt.playlists().insert(
        part="snippet,status",
        body={"snippet": {"title": title, "description": description},
              "status": {"privacyStatus": privacy}}).execute()
    return r["id"]


def playlist_items(yt, playlist_id):
    """videoId -> (playlistItemId, position) for items already in the playlist."""
    out, page = {}, None
    while True:
        r = yt.playlistItems().list(part="snippet", playlistId=playlist_id,
                                    maxResults=50, pageToken=page).execute()
        for it in r["items"]:
            sn = it["snippet"]
            out[sn["resourceId"]["videoId"]] = (it["id"], sn["position"])
        page = r.get("nextPageToken")
        if not page:
            break
    return out


def arrange_playlist(yt, playlist_id, ordered_video_ids, dry=False, log=print):
    """Make the playlist contain exactly ordered_video_ids, in that order.
    Inserts missing videos and fixes the position of misplaced ones. Safe to
    re-run."""
    existing = playlist_items(yt, playlist_id)
    for pos, vid in enumerate(ordered_video_ids):
        if vid in existing:
            item_id, cur = existing[vid]
            if cur == pos:
                log(f"  [ok ] pos {pos:2d}  {vid}")
                continue
            log(f"  [move] {vid}  {cur} -> {pos}")
            if not dry:
                yt.playlistItems().update(
                    part="snippet",
                    body={"id": item_id,
                          "snippet": {"playlistId": playlist_id, "position": pos,
                                      "resourceId": {"kind": "youtube#video",
                                                     "videoId": vid}}}).execute()
        else:
            log(f"  [add ] pos {pos:2d}  {vid}")
            if not dry:
                yt.playlistItems().insert(
                    part="snippet",
                    body={"snippet": {"playlistId": playlist_id, "position": pos,
                                      "resourceId": {"kind": "youtube#video",
                                                     "videoId": vid}}}).execute()
