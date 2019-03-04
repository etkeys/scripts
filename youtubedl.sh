#!/bin/bash

# This function expects these params
# 1: The url to download
# 2: The final name of the file
# 3: The directory to put the final file
function download {

	youtube-dl --restrict-filename --extract-audio --audio-format mp3 "$1" --exec "mv {} $3/$2.mp3"
}

pushd /tmp

restingPlace="$HOME/Music/Bassline"

if [ ! -d "$restingPlace" ]; then
	echo "Creating $restingPlace"
	
	# I'm not sure if the -p option helps things?
	mkdir -p  "$restingPlace"
fi

download "https://www.youtube.com/watch?v=3c1RnA3HUdk" "EcTwins-SteppingUp" "$restingPlace"

popd
