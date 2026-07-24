#!/bin/bash
set -euo pipefail
cd "${0%/*}"

export DOCKER_BUILDKIT=1

if [[ "${GITHUB_ACTIONS:-${GITHUB_ACTION:-}}" ]]; then
  docker buildx build --load \
    --cache-from type=gha,scope=cpu-static-base \
    --cache-to type=gha,mode=max,scope=cpu-static-base \
    -t videosubfinder-build:base-cpu-static -f base.Dockerfile ../..
  docker buildx build --load \
    --cache-from type=gha,scope=cpu-static-app \
    --cache-to type=gha,mode=max,scope=cpu-static-app \
    --build-arg BASE_IMAGE=videosubfinder-build:base-cpu-static \
    -t videosubfinder-build:cpu-static -f build.Dockerfile ../../..
else
  docker build -t videosubfinder-build:base-cpu-static -f base.Dockerfile ../..
  docker build --build-arg BASE_IMAGE=videosubfinder-build:base-cpu-static \
    -t videosubfinder-build:cpu-static -f build.Dockerfile ../../..
fi

mkdir -p out
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
