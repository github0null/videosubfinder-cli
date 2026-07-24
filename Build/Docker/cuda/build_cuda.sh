#!/bin/bash
set -euo pipefail
cd "${0%/*}"

if [[ "${GITHUB_ACTION:-${GITHUB_ACTIONS:-}}" ]]; then
  docker buildx build --load --cache-from type=gha --cache-to type=gha,mode=max \
    -t videosubfinder-build:base-cuda -f base_cuda.Dockerfile ../..
  docker buildx build --load --cache-from type=gha --cache-to type=gha,mode=max \
    --build-arg BASE_IMAGE=videosubfinder-build:base-cuda \
    -t videosubfinder-build:cuda -f build_cuda.Dockerfile ../../..
else
  docker build -t videosubfinder-build:base-cuda -f base_cuda.Dockerfile ../..
  docker build --build-arg BASE_IMAGE=videosubfinder-build:base-cuda \
    -t videosubfinder-build:cuda -f build_cuda.Dockerfile ../../..
fi

mkdir -p out
docker run --rm -v "$PWD/out:$PWD/out" videosubfinder-build:cuda \
  bash -c "cd /tmp/work/ && tar cvzf $PWD/out/videosubfinder-cli-cuda-linux-x64.tar.gz \
    VideoSubFinderCli VideoSubFinderCli.run settings \
    \$(ls -1 | grep -E '\\.so(\\..*)?$' || true)"
