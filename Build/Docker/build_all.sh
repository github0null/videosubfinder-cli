#!/bin/bash
set -e
cd "${0%/*}"
./cpu_static/build.sh
./cuda/build_cuda.sh
