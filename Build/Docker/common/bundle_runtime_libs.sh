#!/bin/bash
# Copy non-glibc runtime shared libraries next to the binary so the
# package can run on Debian 12 / newer hosts without installing Ubuntu
# build-time packages (ffmpeg, tbb, ...).
set -euo pipefail

TARGET_DIR="${1:?target dir}"
BIN="${2:?binary path}"
shift 2

mkdir -p "$TARGET_DIR"
cp -f "$BIN" "$TARGET_DIR/$(basename "$BIN")"

# Optional extra libs (absolute paths or globs)
for extra in "$@"; do
  # shellcheck disable=SC2086
  for f in $extra; do
    [ -e "$f" ] || continue
    cp -Lf "$f" "$TARGET_DIR/"
  done
done

# Collect transitive deps of the binary + already copied libs.
collect_deps() {
  local path="$1"
  ldd "$path" 2>/dev/null | awk '/=>/ {print $3} /^\// {print $1}' | while read -r lib; do
    [ -n "$lib" ] || continue
    [ -e "$lib" ] || continue
    case "$lib" in
      */ld-linux-*.so.*) continue ;;
      */libc.so.*) continue ;;
      */libm.so.*) continue ;;
      */libdl.so.*) continue ;;
      */librt.so.*) continue ;;
      */libpthread.so.*) continue ;;
      */libresolv.so.*) continue ;;
      */libutil.so.*) continue ;;
      */libnss_*.so.*) continue ;;
      */libgcc_s.so.*) continue ;;  # usually OK from host; keep if missing later
    esac
    # Skip NVIDIA driver stubs; runtime provides them on CUDA hosts/containers.
    case "$lib" in
      */libcuda.so*) continue ;;
      */libnvidia-*.so*) continue ;;
    esac
    echo "$lib"
  done
}

copied=1
while [ "$copied" -gt 0 ]; do
  copied=0
  for so in "$TARGET_DIR"/*; do
    [ -f "$so" ] || continue
    while read -r lib; do
      base="$(basename "$lib")"
      if [ ! -e "$TARGET_DIR/$base" ]; then
        cp -Lf "$lib" "$TARGET_DIR/$base"
        copied=$((copied + 1))
      fi
    done < <(collect_deps "$so")
  done
done

echo "Bundled libraries in $TARGET_DIR:"
ls -la "$TARGET_DIR"
