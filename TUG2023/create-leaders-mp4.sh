#!/bin/bash

mkdir -p leaders
for i in LB/*.html ; do
  slug=$(basename $i .html)
  output=leaders/$slug.mp4
  jpeg=leaders/$slug.jpg
  if [ -r $output ] ; then
    echo "Output already exists, not recreating $output" >&2
    continue
  fi
  snapdir=$(mktemp -d)
  node ../timesnap/node_modules/timesnap/cli.js -L "--no-sandbox --disable-gpu" $i --viewport=1920,1080 --fps=50 --duration=10 --output-pattern="$snapdir/leader-%03d.png"
  ffmpeg -r 50 -f image2 -s 1920x1080 -i $snapdir/leader-%03d.png -vcodec libx264 -crf 25 -pix_fmt yuv420p $output
  # create a snapshot for the title image
  # we could use the png, probably ... 
  ffmpeg -i $output -ss 00:00:09.50 -frames:v 1 $jpeg

  rm $snapdir/leader-*.png
  rmdir $snapdir
done
