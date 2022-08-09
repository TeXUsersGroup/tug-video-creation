###################################3
### WARNING
###################################
# This is NOT the original doit.sh runner
# but adjusted, do NOT overwrite it
###############################

doall=1
if [ "$1" = "missing" ] ; then
  doall=0
fi

set -u

. ../../common-video-settings.sh

SLUG="chernoff-engines"
PART1FILE_NAME="GMT20220723-191622_Recording_gallery_2560x1440.mp4"
PART3FILE_NAME=""
PRERECORDED_NAME=""

ZOOMDIR="../../Zoom"
PRERECDIR="../../prerecorded"
LEADER="../../leaders/$SLUG.mp4"
PART1FILE="$ZOOMDIR/$PART1FILE_NAME"
PART3FILE="$ZOOMDIR/$PART3FILE_NAME"
TUGFILE="../../TUG-33.png"
PRERECORDED="$PRERECDIR/$PRERECORDED_NAME"
CREDITS=../../credits-final.mp4

function watermarkscale() {
  fn=$1
  xdim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 $fn)
  if [ $xdim -eq 1920 ] ; then
    echo "$watermark"
  else
    echo "$scalewatermark"
  fi
}

prepare_one() {
  inputf=$1
  startts=$2
  endts=$3
  midfile=part${nextpart}-pre.mp4
  outputfile=part${nextpart}.ts
  if [ $startts = "-1" -o $startts = "BEGIN" ] ; then
    startarg=""
  else
    startarg="-ss $startts"
  fi
  if [ $endts = "-1" -o $endts = "END" ] ; then
    endarg=""
  else
    endarg="-to $endts"
  fi
  if [ $doall = 1 ] ; then rm -f $outputfile $midfile normalized/$midfile ; fi
  if [ ! -r $midfile ] ; then
    echo "segment $nextpart: extracting and rescaling/watermarking"
    $ffmpeg $startarg $endarg -i "$inputf" -i $TUGFILE -filter_complex "$(watermarkscale $inputf)" $midfile
  fi
  if [ ! -r normalized/$midfile ] ; then
    echo "segment $nextpart: normalizing audio"
    ffmpeg-normalize -ext mp4 -c:a aac -f -ar 32000 $midfile
  fi
  if [ ! -r $outputfile ] ; then
    echo "segment $nextpart: preparing for concatenation"
    $ffmpeg -i normalized/$midfile -c copy -bsf:v h264_mp4toannexb -f mpegts $outputfile
  fi
  nextpart=$((nextpart + 1))
}


echo "========================== working on $SLUG"

nextpart=0

if [ $doall = 1 ] ; then rm -f part${nextpart}.ts ; fi
if [ ! -r part${nextpart}.ts ] ; then
  # add audio stream to leader
  echo "adding audio to leader"
  $ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=32000 -i $LEADER -c copy -bsf:v h264_mp4toannexb -f mpegts -c:a aac -shortest part${nextpart}.ts
fi
nextpart=$((nextpart + 1))

# times in the video that was cut out
#   00:00:00 -> 00:00:51
#   00:01:33 -> 00:01:44
#   00:01:59 -> 00:09:04
#   00:11:34 -> 00:18:16
#   00:20:25 -> 00:24:07
#   00:25:24 -> 00:39:21
#   00:40:17 -> 00:41:07
#   00:41:22 -> 00:42:35
#
# original cut of started at 02:58:52
# 
EPOCH='jan 1 1970'
secstart=$(date -u -d "$EPOCH 02:58:52" +%s)
shiftit() {
  secs=$(date -u -d "$EPOCH $1" +%s)
  newsecs=$((secstart + secs))
  echo $(date -u --date='@'$newsecs +%T)
}
prepare_one "$PART1FILE" $(shiftit 00:00:00) $(shiftit 00:00:51)
prepare_one "$PART1FILE" $(shiftit 00:01:33) $(shiftit 00:01:44)
# cut one more pieace out
#prepare_one "$PART1FILE" $(shiftit 00:01:59) $(shiftit 00:09:04)
prepare_one "$PART1FILE" $(shiftit 00:01:59) $(shiftit 00:04:10)
prepare_one "$PART1FILE" $(shiftit 00:04:17) $(shiftit 00:09:04)
# 
# cut one more
#prepare_one "$PART1FILE" $(shiftit 00:11:34) $(shiftit 00:18:16)
prepare_one "$PART1FILE" $(shiftit 00:11:34) $(shiftit 00:14:08)
prepare_one "$PART1FILE" $(shiftit 00:14:23) $(shiftit 00:18:16)
#
prepare_one "$PART1FILE" $(shiftit 00:20:25) $(shiftit 00:24:07)
prepare_one "$PART1FILE" $(shiftit 00:25:24) $(shiftit 00:39:21)
prepare_one "$PART1FILE" $(shiftit 00:40:17) $(shiftit 00:41:07)
prepare_one "$PART1FILE" $(shiftit 00:41:22) $(shiftit 00:42:35)

if [ $doall = 1 ] ; then rm -f part${nextpart}.ts ; fi
if [ ! -r part${nextpart}.ts ] ; then
  # add audio stream to leader
  echo "adding audio to credits"
  $ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=32000 -i $CREDITS -c copy -bsf:v h264_mp4toannexb -f mpegts -c:a aac -shortest part${nextpart}.ts
fi
nextpart=$((nextpart + 1))

acc=""
for i in part?.ts ; do
  if [ -n "$acc" ] ; then acc="$acc|" ; fi
  acc="${acc}$i"
done
echo "concatenating parts"
$ffmpeg -y -i "concat:$acc" -c copy -bsf:a aac_adtstoasc ${SLUG}-final.mp4

