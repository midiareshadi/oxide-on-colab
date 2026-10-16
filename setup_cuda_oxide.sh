#!/usr/bin/env bash
# setup_cuda_oxide.sh
#
# Rebuild a working cuda-oxide environment on a fresh Google Colab GPU machine
# (tested on a Tesla T4, sm_75, Ubuntu 24.04, CUDA 13.0, driver 580).
#
# Usage (in a Colab terminal):
#   curl -fsSL https://raw.githubusercontent.com/midiareshadi/oxide-on-colab/main/setup_cuda_oxide.sh | bash
#
# Optional: use a different cuda-oxide commit or branch:
#   CUDA_OXIDE_REF=main bash setup_cuda_oxide.sh
#
# Steps:
#   1. Check the GPU, driver, and CUDA version.
#   2. Install LLVM 21 and clang 21 (cuda-oxide uses clang's resource dir).
#   3. Install rustup (the repo pins its own nightly, downloaded on first use).
#   4. Clone cuda-oxide at a pinned commit (reproducible).
#   5. Run the environment check, build the codegen backend, run vecadd.

set -euo pipefail

# Commit verified working on a T4 on 2026-10-16:
#   6d47ae49c 2026-10-15 feat(unroll): recognize range `for` loops (#1346)
CUDA_OXIDE_REF="${CUDA_OXIDE_REF:-6d47ae49cb}"
CUDA_OXIDE_DIR="${CUDA_OXIDE_DIR:-$HOME/cuda-oxide}"

step() { echo; echo "=== $* ==="; }

# 1. GPU check
step "1/5 GPU, driver, CUDA"
if ! command -v nvidia-smi >/dev/null; then
    echo "No nvidia-smi. Select a GPU runtime first (Runtime > Change runtime type)."
    exit 1
fi
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
ARCH="sm_${CC}"
echo "Target arch: ${ARCH}"
if command -v nvcc >/dev/null; then
    nvcc --version | grep release
else
    echo "WARNING: nvcc not found. cuda-oxide needs CUDA 13."
fi

# 2. LLVM 21 and clang 21
step "2/5 LLVM 21 and clang 21"
if command -v clang-21 >/dev/null; then
    echo "clang-21 already installed, skipping."
else
    # LLVM's install script prints a long debug trace. Send all of it to a
    # log file, and show the end of the log only if something fails.
    LLVM_LOG=/tmp/oxide-setup-llvm.log
    echo "Installing (about 1 minute). Full log: $LLVM_LOG"
    if ! {
        apt-get update -qq &&
        apt-get install -y -qq wget lsb-release software-properties-common gnupg &&
        wget -q https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh &&
        chmod +x /tmp/llvm.sh &&
        /tmp/llvm.sh 21 &&
        apt-get install -y -qq libclang-21-dev clang-21
    } >"$LLVM_LOG" 2>&1; then
        echo "LLVM/clang install FAILED. Last 30 lines of $LLVM_LOG:"
        tail -30 "$LLVM_LOG"
        exit 1
    fi
fi
ln -sf /usr/bin/llc-21 /usr/local/bin/llc
ln -sf /usr/bin/clang-21 /usr/local/bin/clang
clang --version | head -1

# 3. Rust (rustup only; the repo pins its own nightly)
step "3/5 rustup"
if ! command -v rustup >/dev/null && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain none >/dev/null
fi
# shellcheck disable=SC1091
. "$HOME/.cargo/env"
rustup --version 2>/dev/null | head -1

# 4. Clone cuda-oxide at the pinned commit
step "4/5 cuda-oxide @ ${CUDA_OXIDE_REF}"
if [ ! -d "$CUDA_OXIDE_DIR/.git" ]; then
    git clone -q https://github.com/NVlabs/cuda-oxide.git "$CUDA_OXIDE_DIR"
fi
cd "$CUDA_OXIDE_DIR"
git fetch -q origin
git checkout -q "$CUDA_OXIDE_REF"
git log -1 --format='%h %cd %s' --date=short

# The repo is a monorepo since late 2026: cuda-oxide lives in a subfolder,
# with its own pinned nightly and the `cargo oxide` alias.
if [ -f cuda-oxide/.cargo/config.toml ]; then
    cd cuda-oxide
fi

# 5. Check, build, smoke test
step "5/5 doctor, setup, vecadd on ${ARCH}"
cargo oxide doctor 2>&1 | tail -20
echo
echo "Building the codegen backend (first time: 2 to 4 minutes, no output until done)..."
cargo oxide setup 2>&1 | tail -3
echo
echo "Compiling and running vecadd (first time: 1 to 3 minutes, no output until done)..."
cargo oxide run vecadd --arch "$ARCH" 2>&1 | tail -6

echo
echo "Done. In a new terminal, run:"
echo "  . \"\$HOME/.cargo/env\" && cd $(pwd)"