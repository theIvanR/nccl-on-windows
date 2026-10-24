# NCCL 1.3.4 for Windows — CUDA 11.8

Active work in progress, fork of https://github.com/MyCaffe/NCCL

## Targets
- **CPU:** AVX2
- **CUDA:** 11.8
- **GPU architectures:** `35, 37, 50, 52, 53, 60, 61, 62, 70, 72, 75, 80, 86, 87, 89, 90`

## Usage
1. Download nccl_all arch.7z and extract files.
2. Select the required build from `windows/nccl_all_arch/`:
   - `nccl.h` — Header
   - `nccl64_134.11.8.dll` — Runtime library
   - `nccl64_134.11.8.lib` — Import library
3. Link against the library and include the header.
4. Enjoy!

## Build
**Dependencies:** CUDA Toolkit 11.8, Visual Studio 2019

1. Clone the repository.
2. Build `nccl.sln` in visual studio. 
3. Run `1_copy_all.ps1` to prepare all supported GPU architectures.
4. Run `2_run_tests.cmd` to execute the smoke tests (`nccl_smoke_test.cu`).
5. Enjoy!
