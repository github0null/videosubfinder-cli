#!/bin/bash
set -euo pipefail
cd "${0%/*}"

# Always rebuild the local base image so CPU flags / OpenCV options apply.
# Pre-published eritpchy/* images are intentionally not required.
if [[ "${GITHUB_ACTION:-${GITHUB_ACTIONS:-}}" ]]; then
  docker buildx build --load --cache-from type=gha --cache-to type=gha,mode=max \
    -t videosubfinder-build:base -f base.Dockerfile ../..
  docker buildx build --load --cache-from type=gha --cache-to type=gha,mode=max \
    --build-arg BASE_IMAGE=videosubfinder-build:base \
    -t videosubfinder-build:cpu -f build.Dockerfile ../../..
else
  docker build -t videosubfinder-build:base -f base.Dockerfile ../..
  docker build --build-arg BASE_IMAGE=videosubfinder-build:base \
    -t videosubfinder-build:cpu -f build.Dockerfile ../../..
fi

mkdir -p out
docker run --rm -v "$PWD/out:$PWD/out" videosubfinder-build:cpu \
  bash -c "cd /tmp/work/ && tar cvzf $PWD/out/videosubfinder-cli-cpu-linux-x64.tar.gz \
    VideoSubFinderCli VideoSubFinderCli.run settings \
    \$(ls -1 | grep -E '\\.so(\\..*)?$' || true)"
