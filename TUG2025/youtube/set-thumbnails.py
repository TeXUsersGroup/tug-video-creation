#!/usr/bin/env python3
"""
Set each TUG 2025 talk's YouTube thumbnail to its leader (title-card) image,
../leaders/<token>.jpg.

Matches uploaded videos to talks the same way set-metadata.py / make-playlist.py
do (file-name title, or already-set title), then uploads the leader still as a
custom thumbnail (thumbnails.set, ~50 units each — well within the daily quota).

    python3 set-thumbnails.py --dry-run     # show which video gets which image
    python3 set-thumbnails.py               # apply
    python3 set-thumbnails.py --only schrauwen-keynote

Note: the channel must be enabled for custom thumbnails (verify a phone number
on the account once, in YouTube Studio). Uses the same OAuth as the other scripts.
"""
import argparse, os, sys
import ytcommon as yc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="just this token")
    ap.add_argument("--dry-run", action="store_true", help="show plan, change nothing")
    args = ap.parse_args()

    recs = list(yc.read_csv())
    if args.only:
        recs = [r for r in recs if r["token"] == args.only]
        if not recs:
            sys.exit(f"unknown token: {args.only}")

    yt = yc.get_service()
    resolved, ambiguous, unmatched = yc.match_videos(yt, recs)
    for tok in unmatched:
        print(f"[unmatched] {tok}  (upload it / pin in matches.tsv)")
    for tok, ids in ambiguous.items():
        print(f"[ambiguous] {tok}  {ids}  (pin in matches.tsv)")

    done = skipped = 0
    for rec in recs:
        tok = rec["token"]
        if tok not in resolved:
            skipped += 1
            continue
        vid = resolved[tok]
        img = yc.thumb_path(tok)
        if not os.path.exists(img):
            print(f"[MISS] {tok}  (no leader image at {img})")
            skipped += 1
            continue
        print(f"[{'plan' if args.dry_run else 'thumb'}] {tok}  ({vid})  <- {os.path.relpath(img, yc.ROOT)}")
        if args.dry_run:
            done += 1
            continue
        try:
            yc.set_thumbnail(yt, vid, img)
            print(f"      -> set on https://youtu.be/{vid}")
            done += 1
        except Exception as e:
            print(f"      FAILED: {e}")
            skipped += 1

    print(f"\n{'would set' if args.dry_run else 'set'}: {done}, skipped/unmatched: {skipped}")


if __name__ == "__main__":
    main()
