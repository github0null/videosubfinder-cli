# Runtime image matching the Debian 12 build (glibc 2.36+).
FROM debian:12-slim

ARG CUDA_TOOLKIT_VERSION=12-4

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C \
    LANG=C \
    GCONV_PATH=/nonexistent \
    LOCPATH=/nonexistent \
    LD_LIBRARY_PATH=/opt/videosubfinder:/usr/local/cuda/lib64

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates wget \
        libavcodec59 libavformat59 libswscale6 libavfilter8 \
        libpcre2-32-0 libtbb12 libtbbmalloc2 \
    && wget -q https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm -f cuda-keyring_1.1-1_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        cuda-cudart-${CUDA_TOOLKIT_VERSION} \
        libnpp-${CUDA_TOOLKIT_VERSION} \
    && CUDA_DIR="$(ls -d /usr/local/cuda-[0-9]* 2>/dev/null | sort -V | tail -1)" \
    && test -n "$CUDA_DIR" \
    && rm -rf /usr/local/cuda \
    && ln -s "$CUDA_DIR" /usr/local/cuda \
    && rm -rf /var/lib/apt/lists/*

# Expect the release tarball next to this Dockerfile (copied by run_cuda.sh).
ADD videosubfinder-cli-cuda-linux-x64.tar.gz /opt/videosubfinder/
WORKDIR /opt/videosubfinder
RUN chmod +x /opt/videosubfinder/VideoSubFinderCli /opt/videosubfinder/VideoSubFinderCli.run \
    && ln -sf /opt/videosubfinder/VideoSubFinderCli.run /VideoSubFinderCli

ENTRYPOINT ["/VideoSubFinderCli"]
