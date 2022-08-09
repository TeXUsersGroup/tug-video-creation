
ffmpeg="ffmpeg -hide_banner -loglevel error -stats"
scalewatermark="[0:v]scale=1920:1080 [mnn], [mnn][1:v]overlay=x=(main_w-overlay_w-30):y=(main_h-overlay_h-30)"
watermark="[0:v][1:v]overlay=x=(main_w-overlay_w-30):y=(main_h-overlay_h-30)"
audioresample="-ar 32000 -ac 2 -acodec aac"
