
doall=1
if [ "$1" = "missing" ] ; then
  doall=0
fi

set -u

. ../common-video-settings.sh

SLUG="Bezos-interview"
#
LEADER="../leaders/$SLUG.mp4"
# video: AVC 3840x2160
# audio: AAC 32.0 kHz 1 channel
MAINFILE="../Zoom/GMT20200725-122305_TUG2020_3840x2160.mp4"
TUGFILE="../TUG-33.png"

if [ $doall = 1 ] ; then rm -f part0.mp4 ; fi
if [ ! -r part0.mp4 ] ; then
  # add audio stream to leader
  ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=32000 -i $LEADER -c:v copy -c:a aac -shortest part0.mp4
fi

if [ $doall = 1 ] ; then rm -f part1.mp4 ; fi
if [ ! -r part1.mp4 ] ; then
  # scale and watermark only
  ffmpeg -ss 02:29:08.000 -to 03:09:39.000 -i $MAINFILE -i $TUGFILE -filter_complex "$scalewatermark" $audioresample part1.mp4
fi

# convert to mpeg-4 stream and concatenate
parts=1
for i in `seq 0 $parts` ; do
	ffmpeg -y -i part$i.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts a$i.ts
done
ffmpeg -y -i "concat:$(seq -s\| -f "a%.0f.ts" 0 $parts)" -c copy -bsf:a aac_adtstoasc ${SLUG}-final.mp4

# clean up
rm -f a?.ts
#rm -f part?.mp4


