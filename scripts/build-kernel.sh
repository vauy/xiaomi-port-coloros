#!/bin/bash
set -e
cd work

[ "${ROOT_INTEGRATED:-false}" != "true" ] && exit 0

mkdir -p verify

# ============================================================
# 编译内核
# 自动探测产物名：Image.lz4-dtb / Image.gz-dtb / Image-dtb / Image
# ============================================================
compile_kernel() {
  local log=$1
  cd kernel_src

  export ARCH=arm64
  export SUBARCH=arm64
  export CROSS_COMPILE=aarch64-linux-gnu-

  # 安装工具链
  if ! command -v aarch64-linux-gnu-gcc > /dev/null 2>&1; then
    sudo apt install -y gcc-aarch64-linux-gnu
  fi

  # 安装 mkimage（联发科内核常用）
  if ! command -v mkimage > /dev/null 2>&1; then
    sudo apt install -y u-boot-tools
  fi

  # 生成 .config
  make O=out ARCH=arm64 "${DEFCONFIG_NAME}" 2>&1 | tee "../verify/${log}"

  # 自动探测产物名
  local target=""
  for t in Image.lz4-dtb Image.gz-dtb Image-dtb Image; do
    echo ">>> 尝试编译目标: $t"
    if make -j$(nproc) O=out ARCH=arm64 \
        CROSS_COMPILE=aarch64-linux-gnu- "$t" 2>&1 | tee -a "../verify/${log}"; then
      if [ -f "out/arch/arm64/boot/$t" ]; then
        target="$t"
        break
      fi
    fi
  done

  if [ -n "$target" ]; then
    cd ..
    echo "KERNEL_TARGET=$target" >> "$GITHUB_ENV"
    return 0
  fi

  echo "  ✗ 未找到任何内核产物"
  cd ..
  return 1
}

# ============================================================
# 第一次编译
# ============================================================
if compile_kernel "build.log"; then
  echo "KERNEL_BUILT=true" >> "$GITHUB_ENV"
else
  echo ">>> 第一次编译失败，回退 Root 方案"
  rm -rf kernel_src/out kernel_src/KernelSU kernel_src/KernelSU-Next

  FALLBACK_TYPE="kernelsu"
  [ "${ROOT_TYPE:-kernelsu-next}" = "kernelsu" ] && FALLBACK_TYPE="kernelsu-next"

  export ENABLE_ROOT=true
  export ROOT_TYPE="$FALLBACK_TYPE"
  export DEFCONFIG_NAME="$DEFCONFIG_NAME"
  export KERNEL_SOURCE_REPO="$KERNEL_SOURCE_REPO"

  bash scripts/integrate-root.sh || {
    echo "KERNEL_BUILT=false" >> "$GITHUB_ENV"
    echo "ROOT_FALLBACK_FAILED=true" >> "$GITHUB_ENV"
    exit 1
  }

  if compile_kernel "build-fallback.log"; then
    echo "KERNEL_BUILT=true" >> "$GITHUB_ENV"
    echo "ROOT_FALLBACK=true" >> "$GITHUB_ENV"
  else
    echo "KERNEL_BUILT=false" >> "$GITHUB_ENV"
    echo "ROOT_FALLBACK_FAILED=true" >> "$GITHUB_ENV"
    exit 1
  fi
fi

# ============================================================
# 应用 MTK BPF 补丁
# 解决 MTK 4.14 内核在 Android 12+ 上的网络问题
# ============================================================
echo ">>> 应用 MTK BPF 补丁"

KERNEL_TARGET="${KERNEL_TARGET:-Image.gz-dtb}"
KERNEL_SRC="kernel_src/out/arch/arm64/boot/${KERNEL_TARGET}"

if [ ! -f "$KERNEL_SRC" ]; then
  echo ">>> 错误: 找不到内核产物 $KERNEL_SRC"
  exit 1
fi

# 下载 mtk-bpf-patcher
BPF_PATCHER="mtk-bpf-patcher"
if [ ! -f "$BPF_PATCHER" ]; then
  echo ">>> 下载 mtk-bpf-patcher"
  curl -LSs "https://github.com/R0rt1z2/mtk-bpf-patcher/releases/latest/download/mtk-bpf-patcher" \
    -o "$BPF_PATCHER" 2>/dev/null || true

  # 如果 release 下载失败，从源码编译
  if [ ! -f "$BPF_PATCHER" ] || [ ! -s "$BPF_PATCHER" ]; then
    echo ">>> Release 下载失败，从源码编译"
    git clone --depth=1 https://github.com/R0rt1z2/mtk-bpf-patcher.git 2>/dev/null || true
    if [ -d "mtk-bpf-patcher" ]; then
      cd mtk-bpf-patcher
      # 如果是 Rust 项目
      if [ -f "Cargo.toml" ]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null || true
        source "$HOME/.cargo/env" 2>/dev/null || true
        cargo build --release 2>&1 | tail -20
        cp target/release/mtk-bpf-patcher "../$BPF_PATCHER" 2>/dev/null || true
      fi
      cd ..
    fi
  fi

  chmod +x "$BPF_PATCHER" 2>/dev/null || true
fi

# 应用补丁
mkdir -p base_boot
if [ -f "$BPF_PATCHER" ] && [ -x "$BPF_PATCHER" ]; then
  echo ">>> 执行 BPF 补丁"
  if "./$BPF_PATCHER" "$KERNEL_SRC" "base_boot/kernel"; then
    echo ">>> BPF 补丁成功"
    echo "BPF_PATCHED=true" >> "$GITHUB_ENV"
  else
    echo ">>> BPF 补丁失败，使用原内核"
    cp "$KERNEL_SRC" "base_boot/kernel"
    echo "BPF_PATCHED=false" >> "$GITHUB_ENV"
  fi
else
  echo ">>> 警告: mtk-bpf-patcher 不可用，使用原内核"
  cp "$KERNEL_SRC" "base_boot/kernel"
  echo "BPF_PATCHED=false" >> "$GITHUB_ENV"
fi

echo ">>> 内核处理完成"
ls -lh base_boot/