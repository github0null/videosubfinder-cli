#!/bin/bash
set -euo pipefail
cd "${0%/*}"

# Prefer docker-engine builder so local base tags resolve for FROM.
if command -v docker >/dev/null 2>&1; then
  docker buildx use default >/dev/null 2>&1 || true
fi

echo "==> Building CPU base image"
docker build -t videosubfinder-build:base -f base.Dockerfile ../..

echo "==> Building CPU app image"
docker build \
  --build-arg BASE_IMAGE=videosubfinder-build:base \
  -t videosubfinder-build:cpu \
  -f build.Dockerfile \
  ../../..

mkdir -p out
echo "==> Packaging tarball"
docker run --rm -v "$PWD/out:$PWD/out" videosubfinder-build:cpu \
  bash -c "cd /tmp/work/ && tar cvzf $PWD/out/videosubfinder-cli-cpu-linux-x64.tar.gz \
    VideoSubFinderCli VideoSubFinderCli.run settings \
    \$(ls -1 | grep -E '\\.so(\\..*)?$' || true)"

ls -lh out/videosubfinder-cli-cpu-linux-x64.tar.gz
