#!/bin/sh

if [ $# -ne 2 ]; then
  echo "This script should be called as:"
  echo "$0 <dir> <input>"
  exit 1
fi

path=$1
input=$2

date=$(date +%Y-%m-%d)
datetime=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p $path/$date && ffmpeg -i $input -c copy -f segment -strftime 1 -segment_time 600 -segment_format mp4 $path/$date/$datetime.mp4
