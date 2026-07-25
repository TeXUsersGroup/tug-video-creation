#!/usr/bin/env python3
"""
Set titles + descriptions on TUG 2026 talks uploaded MANUALLY in the browser
(YouTube Studio).

Manual uploads cost no Data API quota, and editing afterwards is cheap
(videos.update ~50 units each), so all 27 fit in the daily quota.

It matches uploaded videos to talks by their file-name title (e.g.
"schrauwen-keynote-final") -- or by the final title if they were already
renamed -- then sets the proper title + description. Anything ambiguous or
unmatched is reported; pin it by hand in matches.tsv (<token><TAB><videoId>).

    pip install -r requirements.txt
    python3 build-descriptions.py        # ensure desc/*.txt exist
    python3 set-metadata.py --dry-run    # show matched videos + planned changes
    python3 set-metadata.py              # apply (title, description, tags, category)
    python3 set-metadata.py --privacy unlisted   # also set privacy while updating
    python3 set-metadata.py --only schrauwen-keynote

Then put them in a program-ordered playlist with make-playlist.py.
"""
import argparse, sys
import ytcommon as yc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--category", default="28",
                    help="YouTube category id (28=Science & Technology, 27=Education)")
    ap.add_argument("--privacy", default=None,
                    choices=["private", "unlisted", "public"],
                    help="also set privacy (default: leave unchanged)")
    ap.add_argument("--only", default=None, help="just this token")
    ap.add_argument("--dry-run", action="store_true", help="show matches, change nothing")
    args = ap.parse_args()

    recs = list(yc.read_csv())
    if args.only:
        recs = [r for r in recs if r["token"] == args.only]
        if not recs:
            sys.exit(f"unknown token: {args.only}")
    overrides = yc.load_overrides()

    yt = yc.get_service()
    resolved, ambiguous, unmatched = yc.match_videos(yt, recs, overrides)
    for tok in unmatched:
        print(f"[unmatched] {tok}  (no uploaded video matches; add to matches.tsv)")
    for tok, ids in ambiguous.items():
        print(f"[ambiguous] {tok}  {ids}  (pin in matches.tsv)")

    updated = skipped = 0
    for rec in recs:
        tok = rec["token"]
        if tok not in resolved:
            skipped += 1
            continue
        vid = resolved[tok]
        title = yc.make_title(rec, overrides)
        desc = yc.read_desc(tok)
        print(f"[{'plan' if args.dry_run else ' set'}] {tok}  ({vid})")
        print(f"      title: {title}")
        print(f"      desc : {len(desc)} chars" + ("  (EMPTY)" if not desc else ""))
        if args.dry_run:
            updated += 1
            continue
        body = {"id": vid,
                "snippet": {"title": title, "description": desc,
                            "tags": yc.TAGS, "categoryId": args.category}}
        part = "snippet"
        if args.privacy:
            body["status"] = {"privacyStatus": args.privacy}
            part = "snippet,status"
        try:
            yt.videos().update(part=part, body=body).execute()
            print(f"      -> https://youtu.be/{vid} updated")
            updated += 1
        except Exception as e:
            print(f"      FAILED: {e}")
            skipped += 1

    print(f"\n{'would update' if args.dry_run else 'updated'}: {updated}, "
          f"skipped/unmatched: {skipped}")
    if not args.dry_run and updated:
        print("Tip: run  make-playlist.py --title \"TUG 2026\"  to add them in program order.")


if __name__ == "__main__":
    main()
