#!/usr/bin/env python3
"""
Put all the TUG 2025 talk videos into a playlist, in conference-program order.

It matches your uploaded videos to the talks (whether they still have their
upload file-name titles or were already renamed by set-metadata.py), then adds
them to the playlist in the order they appear in the data sheet -- which is the
program order -- and fixes the position of any that are already there but out of
order. Safe to re-run.

    python3 make-playlist.py --title "TUG 2025" --dry-run
    python3 make-playlist.py --title "TUG 2025"               # find or create it
    python3 make-playlist.py --playlist-id PLxxxx             # use an existing one
    python3 make-playlist.py --title "TUG 2025" --privacy unlisted

Quota: playlistItems insert/update cost ~50 units each, so all 27 fit easily in
the 10,000 units/day budget. Uses the same OAuth as the other scripts.
"""
import argparse, sys
import ytcommon as yc


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--title", help="playlist title to find or create")
    g.add_argument("--playlist-id", help="id of an existing playlist to use")
    ap.add_argument("--privacy", default="public",
                    choices=["private", "unlisted", "public"],
                    help="privacy for a newly created playlist (default public)")
    ap.add_argument("--dry-run", action="store_true",
                    help="show the planned playlist without changing anything")
    args = ap.parse_args()

    recs = list(yc.read_csv())
    yt = yc.get_service()

    resolved, ambiguous, unmatched = yc.match_videos(yt, recs)
    for tok in unmatched:
        print(f"[unmatched] {tok}  (upload it / pin in matches.tsv)")
    for tok, ids in ambiguous.items():
        print(f"[ambiguous] {tok}  {ids}  (pin in matches.tsv)")

    # program-ordered list of videoIds (CSV order)
    ordered = [resolved[r["token"]] for r in recs if r["token"] in resolved]
    print(f"\n{len(ordered)} videos to place, in program order:")
    for r in recs:
        if r["token"] in resolved:
            print(f"  {resolved[r['token']]}  {r['token']}")

    # locate / create the playlist
    if args.playlist_id:
        pid = args.playlist_id
    else:
        pid = yc.find_playlist(yt, args.title)
        if pid:
            print(f"\nusing existing playlist '{args.title}': {pid}")
        elif args.dry_run:
            print(f"\nplaylist '{args.title}' would be CREATED ({args.privacy})")
            pid = None
        else:
            pid = yc.create_playlist(yt, args.title, args.privacy,
                                     description="Talks from the TUG 2025 conference, "
                                                 "Thiruvananthapuram, India.")
            print(f"\ncreated playlist '{args.title}': {pid}")

    print("\narranging playlist:")
    if pid is None and args.dry_run:
        for pos, vid in enumerate(ordered):
            print(f"  [add ] pos {pos:2d}  {vid}")
    else:
        yc.arrange_playlist(yt, pid, ordered, dry=args.dry_run)

    if pid:
        print(f"\nplaylist: https://www.youtube.com/playlist?list={pid}")
    print(f"{'(dry-run) ' if args.dry_run else ''}placed {len(ordered)} videos, "
          f"{len(unmatched)} unmatched, {len(ambiguous)} ambiguous")


if __name__ == "__main__":
    main()
