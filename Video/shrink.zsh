#!/bin/bash

cd ~/../../mnt

targetSizeKilobytes=8000
fileInput=$1
filename=$(echo "$fileInput" | sed -E "s/(.*)\..*/\1/")
outFormat="mp4"
fileOutput="${filename}_shrunk.${outFormat}"
while [ "$1" != "" ]; do
    case $1 in
        -f | --format )
            shift 
            outFormat=$1
            ;;
        -o | --output )
            shift 
            fileOutput=$1
            ;;
        -h | --help )
            echo "
    -o | --output FILENAME
            "
            exit
    esac
    shift
done

inWidth=$(ffprobe -v quiet -print_format json -show_format -show_streams "$fileInput" | jq '.streams | map(select(.codec_type == "video")) | .[].width')
inFPS=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "$fileInput" | xargs echo | calc -p)
durationSeconds=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$fileInput")

outFPS=$inFPS
if grep -q "~" <<< "$inFPS" ; then outFPS=$(echo "scale=0; ${outFPS:1}/1" | bc) ; fi

outWidth=$inWidth
outScale=1
bitrate=$(echo "$targetSizeKilobytes/ $durationSeconds" | calc -p -d)
pixels=$(ffprobe -v quiet -print_format json -show_format -show_streams "$fileInput" | jq '.streams | map(select(.codec_type == "video")) | .[].width, .[].height' | paste -s -d"*" | bc)
audioBitrateKB=$(ffprobe -v quiet -print_format json -show_format -show_streams "$fileInput" | jq '.streams | map(select(.codec_type == "audio")) | .[].bit_rate ' | xargs -I {} echo "scale=2; {}/8/1000" | bc)
if [[ ! $audioBitrateKB ]] ; then audioBitrateKB=0; fi
videoBitrateKB=$(calc -p "$bitrate-$audioBitrateKB" | sed -E 's/(.*\....).*/\1/')
echo old audio bitrate: $audioBitrateKB
# $1-MaxFPS, $2-MaxPixels, $3-MaxAudioBitrate
function set_ffmpeg_parameters {
    if [[ $inFPS -gt $1 ]] ; then 
        outFPS=$1 
        echo New fps: $outFPS >&2
    fi 
    if [[ $pixels -gt $2 ]] ; then 
        outScale=$(printf "sqrt($2)/sqrt($pixels)" | calc -p -d )
        echo Out scale: $outScale >&2
        outWidth=$(echo "$inWidth*$outScale" | calc -p -d | sed 's/\..*//')
        if [[ $(echo "scale=0; $outWidth % 2" | bc) -eq 1 ]] ; then
            outWidth=$(echo "$outWidth+1" | bc)
        fi
        echo New width: $outWidth >&2
    fi 
    if [[ $(echo $audioBitrateKB | sed -E 's/\..*//') -gt $3 ]] ; then 
        audioBitrateKB=$3 
        echo New audio bitrate: $audioBitrateKB >&2
    fi
    videoBitrateKB=$(calc -p "$bitrate-$audioBitrateKB")
    echo video bitrate: $videoBitrateKB >&2
}

if   [[ $(echo $bitrate | sed -E 's/\..*//') -lt 25 ]] ; then 
    set_ffmpeg_parameters 18 102240 8
elif [[ $(echo $bitrate | sed -E 's/\..*//') -lt 50 ]] ; then 
    set_ffmpeg_parameters 24 230400 8
elif [[ $(echo $bitrate | sed -E 's/\..*//') -lt 100 ]] ; then 
    set_ffmpeg_parameters 30 409920 12
elif [[ $(echo $bitrate | sed -E 's/\..*//') -lt 200 ]] ; then 
    set_ffmpeg_parameters 42 921600 12
fi

encoding=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$fileInput")
encodingRounding="-1"
if [ $encoding == "h264" ] ; then encodingRounding="-2" ; fi

echo "Shrinking ${fileInput} to ${targetSizeKilobytes}KB. Bitrate: ${bitrate}KB"
ffmpeg -y \
    -hide_banner -v warning -stats \
  -i "$fileInput" \
  -vf "scale=$outWidth:${encodingRounding}" \
  -b:v "${videoBitrateKB}KB" \
  -b:a "${audioBitrateKB}KB" \
  -r "$outFPS" \
  "$fileOutput"
	# -loglevel error
afterSizeBytes=$(stat --printf="%s" "$fileOutput")
beforeSizeBytes=$(stat --printf="%s" "$fileInput")
echo $beforeSizeBytes $afterSizeBytes
shrinkFactor=$(echo "scale=2; $afterSizeBytes / $beforeSizeBytes" | bc )
echo "Rebuilt file as ${fileOutput}, shrank to ${shrinkFactor} of original size"
