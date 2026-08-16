#!/usr/bin/env python3
"""Write a CSV of  slug,youtube_url  for every talk found on the channel.

    python3 dump-urls.py [out.csv]        # default: slugs-youtube.csv

Matches uploaded videos to talks exactly as set-metadata.py does. Unmatched /
ambiguous tokens are reported on stderr (and omitted from the CSV).
"""
import csv, sys
import ytcommon as y

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "slugs-youtube.csv"
    yt = y.get_service()
    recs = list(y.read_csv())
    resolved, ambiguous, unmatched = y.match_videos(yt, recs)
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["slug", "youtube_url"])
        for r in recs:
            vid = resolved.get(r["token"])
            if vid:
                w.writerow([r["token"], f"https://www.youtube.com/watch?v={vid}"])
    for t in unmatched:
        print(f"# unmatched: {t}", file=sys.stderr)
    for t, ids in ambiguous.items():
        print(f"# ambiguous: {t} -> {ids}", file=sys.stderr)
    print(f"wrote {out}: {len(resolved)} rows", file=sys.stderr)

if __name__ == "__main__":
    main()
