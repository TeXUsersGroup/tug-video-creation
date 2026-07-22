#!/bin/bash

mkdir -p LB

CSV="TUG Meetings Video Data Sheet - 2026.csv"

# token,Lecturer,Title,Recording,LogoPosition,Part 1 Start,Part 1 End,PreRecordedFileName,Part 3 Start,Part 3 End,Comment,Timing by,Double checked by
while IFS=\# read -r token lecturer title zoomfile foobar part1start part1end prerec part3start part3end comment rest ; do
  if [ -z "$token" ] ; then
    echo "Missing token for line"
    continue
  fi
  if [ "$token" = Token ] ; then
    continue
  fi
  if [ -z "$zoomfile" ] ; then
    echo "Missing recording file for token $token"
    continue
  fi
  if [ -z "$part1start" ] ; then
    echo "Missing part 1 start for token $token"
    continue
  fi
  if [ -z "$part1end" ] ; then
    echo "Missing part 1 end for token $token"
    continue
  fi
  PART1FILE="$zoomfile"
  #
  if [[ "$PART1FILE" == *"DAY1"* ]] ; then
    ds="17. July, 2026"
  elif [[ "$PART1FILE" == *"DAY2"* ]] ; then
    ds="18. July, 2026"
  elif [[ "$PART1FILE" == *"DAY3"* ]] ; then
    ds="19. July, 2026"
  else
    ds="UNKNOWN"
  fi
  # The HTML is deterministically generated from the CSV + template, so just
  # overwrite any existing page. (Do NOT rename it to LB/$token.previous.html:
  # create-leaders-mp4.sh globs LB/*.html and would then render a spurious
  # leaders/$token.previous.mp4 for every such backup.)
  title=`echo $title | sed -e 's!&!\\\\&!g'`
  sed -e "s#__AUTHORS__#$lecturer#g" \
      -e "s#__TITLE__#$title#g" \
      -e "s#__DATE__#$ds#g" \
    sources/leader-board.html > "LB/$token.html"
done < "$CSV"


# vim:set tabstop=2 shiftwidth=2 expandtab: #
