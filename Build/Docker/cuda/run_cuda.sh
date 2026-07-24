#!/bin/bash
set -euo pipefail
cd "${0%/*}"

input=""
output=""
while :; do
  while getopts i:o:-: arg; do
    case $arg in
      i)
        input="$OPTARG"
        ;;
      o)
        output="$OPTARG"
        ;;
      *)
        ;;
    esac
    [ -n "$input" ] && [ -n "$output" ] && break
  done
  ((OPTIND++)) || true
  [ "$OPTIND" -gt $# ] && break
done

if [ -n "$input" ]; then
  input="$(realpath "$input")"
  input="${input%/*}"
fi

if [ -n "$output" ]; then
  output="$(realpath "$output")"
fi
echo "Input: $input"
echo "Output: $output"

TAR_SRC=""
for candidate in \
  ./out/videosubfinder-cli-cuda-linux-x64.tar.gz \
  ./videosubfinder-cli-cuda-linux-x64.tar.gz \
  ../cpu/out/videosubfinder-cli-cuda-linux-x64.tar.gz
do
  if [ -f "$candidate" ]; then
    TAR_SRC="$candidate"
    break
  fi
done

if [ -z "$TAR_SRC" ]; then
  echo "ERROR: videosubfinder-cli-cuda-linux-x64.tar.gz not found. Build it with ./build_cuda.sh first." >&2
  exit 1
fi

cp -f "$TAR_SRC" ./videosubfinder-cli-cuda-linux-x64.tar.gz

docker build -t videosubfinder:cuda -f run_cuda.Dockerfile .
if [ "$input" = "$output" ]; then
  docker run -it --gpus all --rm -v "$input":"$input" videosubfinder:cuda "$@"
else
  docker run -it --gpus all --rm -v "$input":"$input" -v "$output":"$output" videosubfinder:cuda "$@"
fi
