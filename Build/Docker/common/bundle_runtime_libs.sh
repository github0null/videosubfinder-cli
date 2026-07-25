#!/bin/bash
# Copy non-glibc runtime shared libraries next to the binary so the
# package can run on Debian 12 / newer hosts without installing build-time
# packages (ffmpeg, tbb, ...).
set -euo pipefail

TARGET_DIR="${1:?target dir}"
BIN="${2:?binary path}"
shift 2

mkdir -p "$TARGET_DIR"

# Resolve absolute paths so we never try to copy a file onto itself.
BIN_ABS="$(readlink -f "$BIN")"
BIN_DEST="$TARGET_DIR/$(basename "$BIN_ABS")"
BIN_DEST_ABS="$(mkdir -p "$TARGET_DIR" && readlink -f "$TARGET_DIR")/$(basename "$BIN_ABS")"

if [ ! -f "$BIN_ABS" ]; then
  echo "ERROR: binary not found: $BIN" >&2
  exit 1
fi

if [ "$BIN_ABS" != "$BIN_DEST_ABS" ]; then
  cp -f "$BIN_ABS" "$BIN_DEST_ABS"
fi

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
      */libgcc_s.so.*) continue ;;
    esac
    case "$lib" in
      */libcuda.so*) continue ;;   # NVIDIA driver; provided by host
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
    # Skip the launcher script and non-ELF files.
    case "$so" in
      *.run|*.cfg) continue ;;
    esac
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
