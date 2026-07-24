#!/bin/bash
set -euo pipefail
cd "${0%/*}"

if command -v docker >/dev/null 2>&1; then
  docker buildx use default >/dev/null 2>&1 || true
fi

echo "==> Building CPU static base image"
docker build -t videosubfinder-build:base-cpu-static -f base.Dockerfile ../..

echo "==> Building CPU static app image"
docker build \
  --build-arg BASE_IMAGE=videosubfinder-build:base-cpu-static \
  -t videosubfinder-build:cpu-static \
  -f build.Dockerfile \
  ../../..

mkdir -p out
echo "==> Packaging tarballs"
docker run --rm -v "$PWD/out:$PWD/out" videosubfinder-build:cpu-static \
  bash -c "ARCH=\$(uname -m) \
    && ARCH=\${ARCH/x86_64/x64} \
    && cd /tmp/work/ \
    && tar cvzf $PWD/out/videosubfinder-cli-cpu-static-linux-\$ARCH.tar.gz \
    VideoSubFinderCli VideoSubFinderCli.run settings \
    && mv -fv ./VideoSubFinderCli.upx ./VideoSubFinderCli \
    && tar cvzf $PWD/out/videosubfinder-cli-cpu-static-upx-linux-\$ARCH.tar.gz \
    VideoSubFinderCli VideoSubFinderCli.run settings \
  "

ls -lh out/
