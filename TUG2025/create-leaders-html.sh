#!/bin/bash

mkdir -p LB

CSV="TUG Meetings Video Data Sheet - 2025.csv"

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
    ds="18. July, 2025"
  elif [[ "$PART1FILE" == *"DAY2"* ]] ; then
    ds="19. July, 2025"
  elif [[ "$PART1FILE" == *"DAY3"* ]] ; then
    ds="20. July, 2025"
  else
    ds="UNKNOWN"
  fi
  if [ -r "LB/$token.html" ] ; then
    echo "Renaming old LB $token.html to $token.previous.html in LB directory."
    mv "LB/$token.html" "LB/$token.previous.html"
  fi
  title=`echo $title | sed -e 's!&!\\\\&!g'`
  sed -e "s#__AUTHORS__#$lecturer#g" \
      -e "s#__TITLE__#$title#g" \
      -e "s#__DATE__#$ds#g" \
    sources/leader-board.html > "LB/$token.html"
done < "$CSV"


# vim:set tabstop=2 shiftwidth=2 expandtab: #
