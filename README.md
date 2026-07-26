# videosubfinder-cli

## GitHub Actions
- **cuda12**: Debian 12 + CUDA 12.x (e.g. Tesla T4 / sm_75)

Build: [Build/Docker/cuda/build_cuda.sh](Build/Docker/cuda/build_cuda.sh)

Always run via `./VideoSubFinderCli.run`. Host needs an NVIDIA driver (`libcuda.so`).

## Usage
```bash
chmod +x ./VideoSubFinderCli.run
./VideoSubFinderCli.run -c -r -uc -i "./test_video.mp4" -o "./ResultsDir" \
  -te 0.5 -be 0.1 -le 0.1 -re 0.9 -s 0:00:10:300 -e 0:00:13:100
```

`-uc` enables CUDA GPU acceleration for subtitle search (k-means etc.).
If CUDA init fails, the program logs an error and falls back to CPU.

## Donate
If you use and love videosubfinder-cli, please consider sending some Bitcoin (BTC) to bc1q9t4t6g42hge2stvu96rzr6kn7ynq52al5uv0pg
In case you want to be mentioned as a sponsor, let me know!
