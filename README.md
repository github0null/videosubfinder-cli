# videosubfinder-cli

## Target hosts (Linux x64)
GitHub Actions build:
- **cpu-static**: Debian 12, Broadwell (`-march=broadwell`, no AVX-512)
- **cuda12**: Debian 12 + CUDA 12.x (e.g. Tesla T4 / sm_75)

Always run via `./VideoSubFinderCli.run` (sets a safe C locale for fully-static builds).

## Build (GitHub Actions / Docker)
- Linux CPU static: [Build/Docker/cpu_static/build.sh](Build/Docker/cpu_static/build.sh)
- Linux CUDA 12: [Build/Docker/cuda/build_cuda.sh](Build/Docker/cuda/build_cuda.sh)

CUDA runtime needs a host (or container) with CUDA 12 / NVIDIA driver. See
[Build/Docker/cuda/run_cuda.sh](Build/Docker/cuda/run_cuda.sh).

The static CPU package does not require installation dependencies.

## Usage
```bash
chmod +x ./VideoSubFinderCli.run
./VideoSubFinderCli.run -c -r -i "./test_video.mp4" -o "./ResultsDir" -te 0.5 -be 0.1 -le 0.1 -re 0.9 -s 0:00:10:300 -e 0:00:13:100
```

## Donate
If you use and love videosubfinder-cli, please consider sending some Bitcoin (BTC) to bc1q9t4t6g42hge2stvu96rzr6kn7ynq52al5uv0pg
In case you want to be mentioned as a sponsor, let me know!
