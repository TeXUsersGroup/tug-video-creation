#!/usr/bin/env python3
"""
Upload the finished TUG 2026 talk videos to YouTube via the Data API.

For each talk it uploads ../runners/<token>/<token>-final.mp4 with
    title       "TUG 2026 — <speaker> — <title>"   (see ytcommon.make_title)
    description  the cleaned abstract in desc/<token>.txt (build-descriptions.py)

Idempotent: each successful upload's video id is recorded in uploaded.json and
that talk is skipped next time (use --force to redo).

    pip install -r requirements.txt
    python3 build-descriptions.py
    python3 upload.py --dry-run            # review titles + descriptions
    python3 upload.py                      # upload (default privacy: private)
    python3 upload.py --only schrauwen-keynote

NOTE on quota: videos.insert costs ~1600 units and the daily quota is 10,000,
so only ~6 uploads/day. To publish without that limit, upload the files in the
browser instead and run set-metadata.py (see README.md). Put videos into an
ordered playlist with make-playlist.py.
"""
import argparse, os, sys
import ytcommon as yc


def upload_one(yt, mp4, title, desc, privacy, category):
    from googleapiclient.http import MediaFileUpload
    body = {
        "snippet": {"title": title, "description": desc,
                    "tags": yc.TAGS, "categoryId": category},
        "status": {"privacyStatus": privacy, "selfDeclaredMadeForKids": False},
    }
    media = MediaFileUpload(mp4, chunksize=-1, resumable=True, mimetype="video/mp4")
    req = yt.videos().insert(part="snippet,status", body=body, media_body=media)
    resp = None
    while resp is None:
        status, resp = req.next_chunk()
        if status:
            print(f"      {int(status.progress() * 100)}%", end="\r", flush=True)
    return resp["id"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--privacy", default="private",
                    choices=["private", "unlisted", "public"],
                    help="default: private (review before publishing)")
    ap.add_argument("--category", default="28",
                    help="YouTube category id (28=Science & Technology, 27=Education)")
    ap.add_argument("--only", default=None, help="upload just this token")
    ap.add_argument("--force", action="store_true", help="re-upload even if already done")
    ap.add_argument("--dry-run", action="store_true", help="print plan, do not upload")
    args = ap.parse_args()

    overrides = yc.load_overrides()
    state = yc.load_state()
    recs = list(yc.read_csv())
    if args.only:
        recs = [r for r in recs if r["token"] == args.only]
        if not recs:
            sys.exit(f"unknown token: {args.only}")

    yt = None if args.dry_run else yc.get_service()
    done = skipped = failed = 0
    for rec in recs:
        token = rec["token"]
        mp4 = os.path.join(yc.ROOT, "runners", token, f"{token}-final.mp4")
        title = yc.make_title(rec, overrides)
        desc = yc.read_desc(token)

        if token in state and not args.force:
            print(f"[skip] {token}  (already uploaded: {state[token]['videoId']})")
            skipped += 1
            continue
        if not os.path.exists(mp4):
            print(f"[MISS] {token}  (no final video at {mp4})")
            failed += 1
            continue

        note = "  (title override)" if token in overrides else ""
        print(f"[{'plan' if args.dry_run else ' up '}] {token}{note}")
        print(f"      title: {title}  ({len(title)} chars)")
        print(f"      desc : {len(desc)} chars" + ("  (EMPTY)" if not desc else ""))
        if args.dry_run:
            done += 1
            continue
        try:
            vid = upload_one(yt, mp4, title, desc, args.privacy, args.category)
            state[token] = {"videoId": vid, "title": title, "privacy": args.privacy}
            yc.save_state(state)                            # persist immediately
            print(f"      -> https://youtu.be/{vid}")
            done += 1
        except Exception as e:
            print(f"      FAILED: {e}")
            failed += 1

    print(f"\n{'planned' if args.dry_run else 'uploaded'}: {done}, "
          f"skipped: {skipped}, failed/missing: {failed}")
    if not args.dry_run and done:
        print("Tip: run  make-playlist.py --title \"TUG 2026\"  to add them in program order.")


if __name__ == "__main__":
    main()
