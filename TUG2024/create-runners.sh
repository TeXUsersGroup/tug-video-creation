#!/bin/bash

mkdir -p runners

# token,Lecturer,Title,ZoomRecording,LogoPosition,Part 1 Start,Part 1 End,PreRecordedFileName,Part 3 Start,Part 3 End,Comment,Timing by,Double checked by
while IFS=\# read -r token lecturer title zoomfile foobar part1start part1end prerec part3start part3end comment rest ; do
  #echo -e "token=$token\nzoomfile=$zoomfile\nstart1=$part1start\nprerec=$prerec"
  if [ -z "$token" ] ; then
    echo "Missing token for line"
    continue
  fi
  if [ "$token" = Token ] ; then
    echo "SPECIAL TREATMENT $token"
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
  PART3FILE="$zoomfile"
  PART3START="$part3start"
  PART3END="$part3end"
  mkdir -p "runners/$token"
  if [ -r "runners/$token/config" ] ; then
    # echo "Renaming old runner config $token/config to $token/config.prev in runners directory."
    # mv "runners/$token/config" "runners/$token/config.prev"
    echo "$token: config file already present, not overwriting it!"
  else
    cat <<EOF > "runners/$token/config"
SLUG="$token"
PART1FILE_NAME="$PART1FILE"
PRERECORDED_NAME="$PRERECORDED"
PART3FILE_NAME="$PART3FILE"
PART1START="$PART1START"
PART1END="$PART1END"
PART3START="$PART3START"
PART3END="$PART3END"
EOF
  fi
  if [ -r "runners/$token/doit.sh" ] ; then
    echo "$token: doit.sh already present, not overwriting it."
  else
    echo "$token: installing default doit.sh"
    ln -s ../../../sources/doit.sh "runners/$token/doit.sh"
    # cp sources/doit.sh "runners/$token/doit.sh"
  fi
done < "TUG Meetings Video Data Sheet - 2024.csv"


# :set tabstop=2 shiftwidth=2 expandtab
