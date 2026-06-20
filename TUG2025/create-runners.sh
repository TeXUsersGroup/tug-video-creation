#!/bin/bash

mkdir -p runners

CSV="TUG Meetings Video Data Sheet - 2025.csv"

# token,Lecturer,Title,Recording,LogoPosition,Part 1 Start,Part 1 End,PreRecordedFileName,Part 3 Start,Part 3 End,Comment,Timing by,Double checked by
while IFS=\# read -r token lecturer title zoomfile foobar part1start part1end prerec part3start part3end comment rest ; do
  if [ -z "$token" ] ; then
    echo "Missing token for line"
    continue
  fi
  if [ "$token" = Token ] ; then
    echo "SPECIAL TREATMENT $token"
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
  PART1START="$part1start"
  PART1END="$part1end"
  PRERECORDED="$prerec"
  PART3FILE="$zoomfile"
  PART3START="$part3start"
  PART3END="$part3end"
  mkdir -p "runners/$token"
  if [ -r "runners/$token/config" ] ; then
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
  fi
done < "$CSV"


# :set tabstop=2 shiftwidth=2 expandtab
