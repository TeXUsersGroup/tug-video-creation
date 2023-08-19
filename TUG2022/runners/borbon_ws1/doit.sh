#################################
##### WARNING ###################
#################################
# This is not the default doit.sh
# Manually adjusted!!!
#################################

doall=1
if [ "$1" = "missing" ] ; then
  doall=0
fi

set -u

. ../../common-video-settings.sh

# override to put logo in lower left
scalewatermark="[0:v]scale=1920:1080 [mnn], [mnn][1:v]overlay=x=30:y=(main_h-overlay_h-30)"
watermark="[0:v][1:v]overlay=x=30:y=(main_h-overlay_h-30)"


SLUG="borbon_ws1"
PRERECORDED_NAME="Workshop-ES/Alexander-Borbon_Inicio_con_LaTeX-I.mkv"
PRERECDIR="../../prerecorded"
LEADER="../../leaders/$SLUG.mp4"
TUGFILE="../../TUG-33.png"
PRERECORDED="$PRERECDIR/$PRERECORDED_NAME"

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

prepare_one "$PRERECORDED" "-1" "-1"

acc=""
for i in part?.ts ; do
  if [ -n "$acc" ] ; then acc="$acc|" ; fi
  acc="${acc}$i"
done
echo "concatenating parts"
$ffmpeg -y -i "concat:$acc" -c copy -bsf:a aac_adtstoasc ${SLUG}-final.mp4

