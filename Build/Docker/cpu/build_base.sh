#!/bin/bash
set -e
cd "${0%/*}"
# Optional: rebuild & publish multi-arch base images to a registry you control.
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t eritpchy/videosubfinder-build:base \
  -f base.Dockerfile ../..
