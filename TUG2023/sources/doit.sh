doall=1
if [ "$1" = "missing" ] ; then
  doall=0
fi

set -u

. ../../common-video-settings.sh

if [ ! -r config ] ; then
  echo "Missing config file" >&2
  exit 1
fi

. config

ZOOMDIR="../../Zoom"
PRERECDIR="../../prerecorded"
LEADER="../../leaders/$SLUG.mp4"
PART1FILE="$ZOOMDIR/$PART1FILE_NAME"
PART3FILE="$ZOOMDIR/$PART3FILE_NAME"
TUGFILE="../../TUG-33.png"
PRERECORDED="$PRERECDIR/$PRERECORDED_NAME"
CREDITS="../../credits-final.mp4"

function watermarkscale() {
  fn=$1
  xdim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 $fn)
  if [ $xdim -eq 1920 ] ; then
    echo "$watermark"
  else
    echo "$scalewatermark"
  fi
}

function audiochange() {
  fn=$1
  fieldsstr=$(ffprobe -v error -hide_banner -select_streams a -show_entries stream=codec_name,sample_rate,channels,channel_layout -of compact=p=0:nk=1 "$fn")
  IFS='|' read -a fields <<< "$fieldsstr"
  codec_name=${fields[0]}
  sample_rate=${fields[1]}
  channels=${fields[2]}
  channel_layout=${fields[3]}
  # default target options are
  # -ar $audio_sample_rate -ac 2 -acodec $audio_codec
  rec=""
  if [ ! "$sample_rate" = $audio_sample_rate ] ; then
    rec="$rec -ar $audio_sample_rate "
  fi
  if [ ! "$channels" = $audio_channels ] ; then
    rec="$rec -ac $audio_channels "
  fi
  if [ ! "$codec_name" = "$audio_codec" ] ; then
    rec="$rec -acodec $audio_codec "
  fi
  echo "$rec"
}

prepare_one() {
  inputf=$1
  startts=$2
  endts=$3
  midfile=part${nextpart}-pre.mp4
  #outputfile=part${nextpart}.ts
  outputfile=part${nextpart}.mp4
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
    $ffmpeg $startarg $endarg -i "$inputf" -i $TUGFILE -filter_complex "$(watermarkscale $inputf)" $(audiochange $inputf) -avoid_negative_ts make_zero -r 50 $midfile
  fi
  if [ ! -r normalized/$midfile ] ; then
    echo "segment $nextpart: normalizing audio"
    ffmpeg-normalize -ext mp4 -c:a $audio_codec -f -ar $audio_sample_rate $midfile
  fi
  if [ ! -r $outputfile ] ; then
    echo "segment $nextpart: preparing for concatenation"
    #$ffmpeg -i normalized/$midfile -c copy -bsf:v h264_mp4toannexb -f mpegts -video_track_timescale 12800 $outputfile
    $ffmpeg -i normalized/$midfile -c copy -video_track_timescale 12800 $outputfile
  fi
  nextpart=$((nextpart + 1))
}


echo "========================== working on $SLUG"

nextpart=0

if [ $doall = 1 ] ; then rm -f part${nextpart}.mp4 ; fi
if [ ! -r part${nextpart}.mp4 ] ; then
  # add audio stream to leader
  echo "adding audio to leader"
  #$ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=$audio_sample_rate -i $LEADER -c copy -bsf:v h264_mp4toannexb -f mpegts -c:a $audio_codec -shortest part${nextpart}.ts
  $ffmpeg -y -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=$audio_sample_rate -i $LEADER -c copy -c:a $audio_codec -shortest -video_track_timescale 12800  part${nextpart}.mp4
  #$ffmpeg -y -i part${nextpart}.ts -c copy -bsf:a aac_adtstoasc -video_track_timescale 12800  part${nextpart}.mp4
fi
nextpart=$((nextpart + 1))

prepare_one "$PART1FILE" "$PART1START" "$PART1END"
if [ -n "$PRERECORDED_NAME" ] ; then
  prepare_one "$PRERECORDED" "-1" "-1"
fi
if [ -n "$PART3FILE_NAME" -a -n "$PART3START" -a -n "$PART3END" ] ; then
  prepare_one "$PART3FILE" "$PART3START" "$PART3END"
fi

acc=""
rm -f concat.txt
touch concat.txt
for i in part?.mp4 ; do
  echo "file '$i'" >> concat.txt
done
echo "concatenating parts"
$ffmpeg -y -f concat -i concat.txt -c copy ${SLUG}-final.mp4

