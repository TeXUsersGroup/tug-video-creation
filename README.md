# Video preparation for TUG 2022

TUG2022: https://www.tug.org/tug2022/

## Preparation

The following directories and files need to be added (not included in the
git repository):
```
Zoom/GMT20220721-111652_Recording_gallery_1920x1080.mp4
Zoom/GMT20220722-140823_Recording_gallery_3686x2304.mp4
Zoom/GMT20220723-001522_Recording_gallery_2880x1800.mp4
Zoom/GMT20220723-101840_Recording_gallery_1966x1508.mp4
Zoom/GMT20220723-191622_Recording_gallery_2560x1440.mp4
Zoom/GMT20220724-060654_Recording_gallery_3840x2160.mp4
Zoom/GMT20220724-151151_Recording_gallery_3840x2160.mp4

prerecorded/Chetan_Shirore.mp4
prerecorded/Joseph_Wright-2022-07-22-siunitx.mp4
prerecorded/Joseph_Wright-Case-changing.mp4
prerecorded/Marnanel_Thurman.mp4
prerecorded/Paulo_Cereda-IoT-theatre-present_v2.m4v
prerecorded/Paulo_Cereda-The-story-of-a-silly-package.m4v
prerecorded/silly-talk-tug-2022.m4v
prerecorded/Ulrike_Fischer-new-in-stock.mp4
prerecorded/Ulrike_Fischer-spotcolors.mp4

sources/credits-screencapture.mp4
```

## Install the timesnap program

Change into the `timesnap` directory and call `npm install`. That
should install the necessary node modules.

## Create leaders html file

Run the script `create-leaders-html.sh`.

Warning: some leaders need to be edited by hand afterwards, in particular
the interview leaders where the text should be changed.

## Create leaders mp4 file

Run the script `create-leaders-mp4.sh`.

Requires that timesnap and the `ffmpeg` binary.

## Create the credits mp4 file

Run the script `create-credits.sh`.

Requires ffmpeg and `sources/credits-screencapture.mp4`

The `sources/credits-screencapture.mp4` used was created by screen-recording the 
display of the tug2022/CREDITS/ URL in a browser. Timesnap should be able
to do this, but the outcome was always bad.

## Create the config files and link the runner

Run the script `create-runners.sh`.

For TUG2022, two scripts were hand adjusted:
```
runners/chernoff-engines/doit.sh
runners/samcarter-bricks/doit.sh
```
due to additional complications.

## Create the final mp4s

Run the following code in bash
```bash
cd runners
for i in * ; do
  bash do-one $i
done
```

That will take quite some time, but will only generate missing files, so can
be done to regenerate after some fixup.


# Copyright and License

Where there is Public Domain available, the scripts and files are under Public Domain.

On all other regions:

Copyright 2022 Norbert Preining
License: CC0 or MIT license.
