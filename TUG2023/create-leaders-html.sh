#!/bin/bash

mkdir -p LB

# token,Lecturer,Title,ZoomRecording,LogoPosition,Part 1 Start,Part 1 End,PreRecordedFileName,Part 3 Start,Part 3 End,Comment,Timing by,Double checked by
while IFS=\# read -r token lecturer title zoomfile foobar part1start part1end prerec part3start part3end comment rest ; do
  #echo -e "token=$token\nzoomfile=$zoomfile\nstart1=$part1start\nprerec=$prerec"
  if [ -z "$token" ] ; then
    echo "Missing token for line"
    continue
  fi
  if [ -z "$zoomfile" ] ; then
    echo "Missing zoom file for token $token"
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
  PART1START="$part1start"
  PART1END="$part1end"
  PRERECORDED="$prerec"
  PART3FILE="$part3start"
  PART3START="$part3start"
  PART3END="$part3end"
  #
  if [[ "$PART1FILE" == *_Day_1_* ]] ; then
    ds="15. July, 2023"
  elif [[ "$PART1FILE" == *_Day_2_* ]] ; then
    ds="16. July, 2023"
  elif [[ "$PART1FILE" == *_Day_3* ]] ; then
    ds="17. July, 2023"
  else
    ds="UNKNOWN"
  fi
  if [ -r "LB/$token.html" ] ; then
    echo "Renaming old LB $token.html to $token.previous.html in LB directory."
    mv "LB/$token.html" "LB/$token.previous.html"
  fi
  title=`echo $title | sed -e 's!&!\\\\&!g'`
  sed -e "s!__AUTHORS__!$lecturer!g" \
      -e "s!__TITLE__!$title!g" \
      -e "s!__DATE__!$ds!g" \
    sources/leader-board.html > "LB/$token.html"
done < "TUG Meetings Video Data Sheet - 2023.csv"


# vim:set tabstop=2 shiftwidth=2 expandtab: #
