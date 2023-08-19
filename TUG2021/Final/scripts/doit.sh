set -x

LEADER=../LB-TUG-2021/$SLUG.html
TUGFILE=../TUG-33.png


scalewatermark="[0:v]scale=1920:1080 [mnn], [mnn][1:v]overlay=x=(main_w-overlay_w-30):y=(main_h-overlay_h-30)"
watermark="[0:v][1:v]overlay=x=(main_w-overlay_w-30):y=(main_h-overlay_h-30)"
audioresample="-ar 32000 -ac 2 -acodec aac"


if [ ! -r $LEADER ] ; then
	echo "Cannot find $LEADER" >&2
	exit 1
fi

if [ ! -r "../leaders/${SLUG}_leader.mp4" ] ; then
  mkdir -p ../leaders/
  tmp=`mktemp -d`
  timesnap $LEADER --viewport=1920,1080 --fps=30 --duration=10 --output-pattern="$tmp/%03d.png"
  ffmpeg -r 30 -f image2 -s 1920x1080 -i $tmp/%03d.png -vcodec libx264 -crf 25  -pix_fmt yuv420p ../leaders/${SLUG}_leader.mp4
  rm -rf $tmp
fi
ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=32000 -i ../leaders/${SLUG}_leader.mp4 -c:v copy -c:a aac -shortest part0.mp4

ffmpeg -ss $TIMEIN -to $TIMEOUT -i $MAINFILE -i $TUGFILE -filter_complex "$scalewatermark" $audioresample part1.mp4

ffmpeg -y -i part0.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts a0.ts
ffmpeg -y -i part1.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts a1.ts
ffmpeg -y -i "concat:a0.ts|a1.ts" -c copy -bsf:a aac_adtstoasc ${SLUG}-final.mp4

# clean up
rm -f a?.ts
rm -f part?.mp4


