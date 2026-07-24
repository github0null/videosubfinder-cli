ARG BASE_IMAGE=videosubfinder-build:base-cuda
FROM ${BASE_IMAGE}

ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive \
    CUDA_TOOLKIT_PATH=/usr/local/cuda

COPY Build/Docker/common/bundle_runtime_libs.sh /usr/local/bin/bundle_runtime_libs.sh
RUN chmod +x /usr/local/bin/bundle_runtime_libs.sh

COPY . /tmp/work/videosubfinder-src
RUN CUDA_DIR="$(ls -d1 /usr/local/cuda-* | head -1)" \
    && export CUDA_TOOLKIT_PATH="$CUDA_DIR" \
    && export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$CUDA_DIR/lib64:$CUDA_DIR/extras/CUPTI/lib64" \
    && export PATH="$PATH:$CUDA_DIR/bin" \
    && ln -sf "$CUDA_DIR/targets/x86_64-linux/lib/libcudart.so" /usr/lib/libcudart.so \
    && cd /tmp/work/videosubfinder-src \
    && cp -rf ./Build/Linux_x64/* /tmp/work/ \
    && mkdir -p /tmp/work/settings && cp -rf ./Settings/general.cfg /tmp/work/settings/ \
    && rm -rf linux_build \
    && mkdir -p linux_build \
    && cd linux_build/ \
    && cmake -DCMAKE_BUILD_TYPE=Release -DUSE_CUDA=ON \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN" \
        .. \
    && cmake --build . --config Release -j $(nproc) \
    && cp ./Interfaces/VideoSubFinderCli/VideoSubFinderCli /tmp/work/VideoSubFinderCli.bin \
    && rm -rf /tmp/work/videosubfinder-src

# Bundle app deps; leave libcudart/npp to the CUDA 12 host / nvidia container runtime.
RUN bash /usr/local/bin/bundle_runtime_libs.sh /tmp/work /tmp/work/VideoSubFinderCli.bin \
      "/usr/local/lib/libwx_baseu-*.so.*" \
      "/usr/local/lib/libopencv_*.so.*" \
    && mv -f /tmp/work/VideoSubFinderCli.bin /tmp/work/VideoSubFinderCli \
    && chmod +x /tmp/work/VideoSubFinderCli /tmp/work/VideoSubFinderCli.run \
    && # Drop any accidentally bundled CUDA toolkit libs (host provides CUDA 12).
       rm -f /tmp/work/libcudart.so* /tmp/work/libnpp*.so* /tmp/work/libcuda.so* || true
