#!/bin/bash
set -euo pipefail
cd "${0%/*}"

# Use the docker-engine builder so a locally tagged base image can be used as
# FROM. The GHA "docker-container" buildx driver cannot see --load images and
# will try (and fail) to pull docker.io/library/videosubfinder-build:*.
if command -v docker >/dev/null 2>&1; then
  docker buildx use default >/dev/null 2>&1 || true
fi

echo "==> Building CUDA base image (Debian 12 + CUDA 12)"
docker build \
  -t videosubfinder-build:base-cuda \
  -f base_cuda.Dockerfile \
  ../..

echo "==> Building CUDA app image"
docker build \
  --build-arg BASE_IMAGE=videosubfinder-build:base-cuda \
  -t videosubfinder-build:cuda \
  -f build_cuda.Dockerfile \
  ../../..

mkdir -p out
echo "==> Packaging tarball"
docker run --rm -v "$PWD/out:$PWD/out" videosubfinder-build:cuda \
  bash -c "cd /tmp/work/ && tar cvzf \"$PWD/out/videosubfinder-cli-cuda-linux-x64.tar.gz\" \
    VideoSubFinderCli VideoSubFinderCli.run settings \
    \$(ls -1 | grep -E '\\.so(\\..*)?$' || true)"

ls -lh out/videosubfinder-cli-cuda-linux-x64.tar.gz
