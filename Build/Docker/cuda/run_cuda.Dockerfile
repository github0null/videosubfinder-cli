FROM nvidia/cuda:12.3.2-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C \
    LANG=C \
    GCONV_PATH=/nonexistent \
    LOCPATH=/nonexistent

# Allow ubuntu to cache package downloads
RUN rm -f /etc/apt/apt.conf.d/docker-clean
ARG USE_GUI=0
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        libavcodec58 libavformat58 libswscale5 libavfilter7 \
        libpcre2-32-0 libtbb12 libtbbmalloc2 \
    && rm -rf /var/lib/apt/lists/*

# Expect the release tarball next to this Dockerfile (copied by run_cuda.sh).
ADD videosubfinder-cli-cuda-linux-x64.tar.gz /opt/videosubfinder/
WORKDIR /opt/videosubfinder
RUN chmod +x /opt/videosubfinder/VideoSubFinderCli /opt/videosubfinder/VideoSubFinderCli.run \
    && ln -sf /opt/videosubfinder/VideoSubFinderCli.run /VideoSubFinderCli

ENV LD_LIBRARY_PATH=/opt/videosubfinder:${LD_LIBRARY_PATH}
ENTRYPOINT ["/VideoSubFinderCli"]
