
# needs original credits.mp4 as captured and cut correctly

. common-video-settings.sh

mkdir tmp
# create still image video of logo
$ffmpeg -y -loop 1 -r 1  -f image2 -s 1920x1080 -i 'sources/t2022-claudio-frame.jpg' -vcodec libx264 -crf 25 -pix_fmt yuv420p -t 3 -r 25 tmp/out.mp4
# change fps of screencapture
$ffmpeg -y -i sources/credits-screencapture.mp4 -filter:v fps=25 tmp/credits-screencapture-fps25.mp4
# prepare for concatenation
$ffmpeg -y -i tmp/credits-screencapture-fps25.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts tmp/credits.ts
$ffmpeg -y -i tmp/out.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts tmp/out.ts
$ffmpeg -y -i "concat:tmp/out.ts|tmp/credits.ts" -c copy -bsf:a aac_adtstoasc tmp/credits-final-pre.mp4
$ffmpeg -y -i tmp/credits-final-pre.mp4 -vf tpad=stop_mode=clone:stop_duration=2 credits-final.mp4

