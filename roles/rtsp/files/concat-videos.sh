#!/bin/bash

if [ $# -ne 1 ]; then
  echo "This script should be called as:"
  echo "$0 <dir>"
  exit 1
fi

dir=$1
prefix="saved_"
extension=".mp4"
date_regex="\d{4}-\d{2}-\d{2}"
time_regex="[^\d]\K\d{2}-\d{2}-\d{2}"

function file_get_date()
{
  local file=$1
  basename $file | grep -oP $date_regex
}

function file_get_time()
{
  local file=$1
  basename $file | grep -oP $time_regex | sed 's/-/:/g'
}

function file_get_epoch()
{
  local file=$1
  date --date "$(file_get_date $file) $(file_get_time $file)" +%s
}

function file_too_new()
{
  local file=$1
  local duration=$2

  now=$(date +%s)
  file_timestamp=$(file_get_epoch $file)

  [[ $(($now - $file_timestamp)) -le $((60 + 2 * $duration)) ]]
}

echo "======= Concatenating videos ======="

for datedir in $(find $dir -maxdepth 1 -type d | grep -P "\/\K$date_regex\$" | sort --reverse); do
  date="$(echo $datedir | grep -oP $date_regex)"

  concat_video="$dir/$date.mp4"
  concat_video_partial="$dir/${date}_partial.mp4"
  concat_file="$datedir/concat.txt"

  if [[ -f $concat_video ]]; then
    echo "File $concat_video already exists"
    echo "Removing dir $datedir..."
    rm -rf $datedir
    echo "Done"
    continue
  fi

  if [[ -f $concat_video_partial ]]; then
    echo "Cleaning partial video $concat_video_partial"
    rm -f $concat_video_partial &> /dev/null
  fi

  if [[ $date == "$(date +%Y-%m-%d)" ]]; then
    echo "Creating partial video $concat_video for today ($date)"
    concat_video=$concat_video_partial
  fi

  echo -n "" > $concat_file

  for file in $(ls -tr $datedir | grep -P "$date_regex$time_regex$extension" | sort 2> /dev/null); do
    file="$datedir/$file"
    if file_too_new $file 300; then
      echo "File $file is too new"
      continue
    fi

    echo "file $(basename $file)" >> $concat_file
    continue
  done

  if [[ ! -s $concat_file ]]; then
    echo "Input file $concat_file was empty"
    continue
  fi

  echo "Creating video $concat_video..."
  ffmpeg -v warning -f concat -safe 0 -i $concat_file -c copy $concat_video
  err=$?

  if [[ $err -ne 0 ]]; then
    echo "Failure while concatenating videos for date $date (err: $err)"
    exit $err
  fi

  echo "Done"

  if [[ ! $concat_video == $concat_video_partial ]]; then
    echo "Removing dir $datedir..."
    rm -rf $datedir
    echo "Done"
  fi

done
