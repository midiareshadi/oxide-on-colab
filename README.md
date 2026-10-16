# oxide-on-colab: cuda-oxide on a free NVIDIA T4 in Google Colab

One-command setup for [NVlabs cuda-oxide](https://github.com/NVlabs/cuda-oxide)
(write CUDA GPU kernels in Rust) on a fresh, free Google Colab T4 GPU machine.

Colab machines are temporary: when the session ends, everything you installed
is gone. This script rebuilds a working cuda-oxide environment from zero, so
you don't repeat the setup by hand every time.

Tested on a **Tesla T4** (Turing, sm_75), Ubuntu 24.04, CUDA 13.0, driver 580.

## Usage

In a Colab **terminal** with a GPU runtime selected:

```bash
git clone https://github.com/midiareshadi/oxide-on-colab.git
cd oxide-on-colab
bash setup_cuda_oxide.sh
```

It takes about 10 minutes. Most of the time is the cuda-oxide backend build.
When it ends you should see:

```
✓ SUCCESS: All 1024 elements correct!
```

## What the script does

1. Checks the GPU, the driver, and the CUDA version.
2. Installs LLVM 21 and clang 21.
3. Installs `rustup`. (cuda-oxide pins its own Rust nightly and downloads it on first use.)
4. Clones cuda-oxide at a **pinned commit**, so the result is reproducible.
5. Runs `cargo oxide doctor`, builds the codegen backend, and runs the
   `vecadd` example for the detected GPU architecture.

The script is safe to run twice. It skips steps that are already done.

## Pinned version

cuda-oxide changes fast. To keep this setup reproducible, the script uses the
commit verified on a T4:

```
6d47ae49c  2026-10-15  feat(unroll): recognize range `for` loops (#1346)
```

To try the latest version instead:

```bash
CUDA_OXIDE_REF=main bash setup_cuda_oxide.sh
```

## After setup

In a new terminal:

```bash
. "$HOME/.cargo/env"
cd ~/cuda-oxide/cuda-oxide
cargo oxide run <example> --arch sm_75
```

## Limits

- Needs CUDA 13 and an NVIDIA driver 580 or newer on the Colab image.
  The script warns you if they are missing.
- A T4 (sm_75) has no FP8, TMA, WGMMA, or cluster support. Examples that
  need Ampere, Ada, Hopper, or Blackwell features will not run on it.
