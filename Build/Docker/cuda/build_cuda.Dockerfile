ARG BASE_IMAGE=videosubfinder-build:base-cuda
FROM ${BASE_IMAGE}

ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive \
    CUDA_TOOLKIT_PATH=/usr/local/cuda

COPY Build/Docker/common/bundle_runtime_libs.sh /usr/local/bin/bundle_runtime_libs.sh
RUN chmod +x /usr/local/bin/bundle_runtime_libs.sh

COPY . /tmp/work/videosubfinder-src
RUN set -eux; \
    CUDA_DIR="$(readlink -f /usr/local/cuda)"; \
    export CUDA_TOOLKIT_PATH="$CUDA_DIR"; \
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$CUDA_DIR/lib64:$CUDA_DIR/targets/x86_64-linux/lib:${CUDA_DIR}/extras/CUPTI/lib64"; \
    export PATH="$PATH:$CUDA_DIR/bin"; \
    # Help the linker find CUDA archives / shared stubs.
    for d in "$CUDA_DIR/lib64" "$CUDA_DIR/targets/x86_64-linux/lib"; do \
      if [ -e "$d/libcudart.so" ]; then ln -sfn "$d/libcudart.so" /usr/lib/libcudart.so; fi; \
      if [ -e "$d/libcudart_static.a" ]; then ln -sfn "$d/libcudart_static.a" /usr/lib/libcudart_static.a; fi; \
    done; \
    cd /tmp/work/videosubfinder-src; \
    cp -rf ./Build/Linux_x64/* /tmp/work/; \
    mkdir -p /tmp/work/settings; \
    cp -rf ./Settings/general.cfg /tmp/work/settings/; \
    rm -rf linux_build; \
    mkdir -p linux_build; \
    cd linux_build/; \
    cmake -DCMAKE_BUILD_TYPE=Release -DUSE_CUDA=ON \
        -DCUDA_USE_STATIC_LIBS=ON \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN -L${CUDA_DIR}/lib64 -L${CUDA_DIR}/targets/x86_64-linux/lib" \
        ..; \
    # Guardrail: CUDA toolkit headers/APIs belong in Components/CUDAKernels/*.cu only.
    # CXX targets are not given CUDA include paths, so accidental includes break the build.
    if grep -RInE --include='*.cpp' --include='*.h' --include='*.hpp' \
         '#include[[:space:]]*[<"](cuda_runtime|cuda\.h|nppi|nppc|driver_types)' \
         Components/IPAlgorithms Components/FFMPEGVideo Components/OCVVideo Interfaces; then \
      echo "ERROR: CUDA toolkit headers must stay in Components/CUDAKernels/*.cu" >&2; \
      exit 1; \
    fi; \
    if grep -RInE --include='*.cpp' --include='*.h' --include='*.hpp' \
         '\bcuda(SetDevice|Malloc|Free|Memcpy|GetErrorString)[[:space:]]*\(' \
         Components/IPAlgorithms Components/FFMPEGVideo Components/OCVVideo Interfaces; then \
      echo "ERROR: CUDA runtime APIs must stay in Components/CUDAKernels/*.cu" >&2; \
      exit 1; \
    fi; \
    if ! cmake --build . --config Release -j "$(nproc)"; then \
      echo "Parallel build failed; re-running -j1 to surface the real error" >&2; \
      cmake --build . --config Release -j 1; \
      exit 1; \
    fi; \
    cp -f ./Interfaces/VideoSubFinderCli/VideoSubFinderCli /tmp/work/VideoSubFinderCli; \
    rm -rf /tmp/work/videosubfinder-src; \
    test -x /tmp/work/VideoSubFinderCli; \
    # cudart/npp should be static in the main binary. OpenCV may still need
    # shared libtbb — that gets bundled in the next step.
    if ldd /tmp/work/VideoSubFinderCli | grep -E 'libcudart\.so|libnppicc\.so|libnppig\.so|libnppc\.so' ; then \
      echo "ERROR: CUDA libs still linked dynamically" >&2; \
      ldd /tmp/work/VideoSubFinderCli; \
      exit 1; \
    fi

# Bundle remaining shared deps (OpenCV/wx/FFmpeg/TBB). Keep libcuda.so out (NVIDIA driver).
RUN set -eux; \
    bash /usr/local/bin/bundle_runtime_libs.sh /tmp/work /tmp/work/VideoSubFinderCli \
      "/usr/local/lib/libwx_baseu-*.so.*" \
      "/usr/local/lib/libopencv_*.so.*" \
      "/usr/lib/*/libtbb.so*" \
      "/usr/lib/*/libtbbmalloc.so*" \
      "/lib/*/libtbb.so*" \
      "/lib/*/libtbbmalloc.so*"; \
    chmod +x /tmp/work/VideoSubFinderCli /tmp/work/VideoSubFinderCli.run; \
    rm -f /tmp/work/libcuda.so* /tmp/work/libnvidia-*.so*; \
    test -x /tmp/work/VideoSubFinderCli; \
    echo "NEEDED shared libs (with bundled LD_LIBRARY_PATH):"; \
    LD_LIBRARY_PATH=/tmp/work ldd /tmp/work/VideoSubFinderCli || true; \
    # libcuda.so comes from the host NVIDIA driver; everything else must resolve
    # via $ORIGIN bundled libs (VideoSubFinderCli.run sets LD_LIBRARY_PATH).
    missing="$(LD_LIBRARY_PATH=/tmp/work ldd /tmp/work/VideoSubFinderCli | awk '/not found/ && $1 !~ /libcuda\\.so/ {print}' || true)"; \
    if [ -n "$missing" ]; then \
      echo "ERROR: unresolved shared libraries in CUDA package:" >&2; \
      echo "$missing" >&2; \
      ls -la /tmp/work; \
      exit 1; \
    fi
