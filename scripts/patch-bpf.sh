#!/bin/bash
set -e
cd work

# ============================================================
# MTK BPF 补丁脚本
# 解决 MTK 4.14/4.19 内核在 Android 12+ 上的网络问题
# ============================================================

echo ">>> 应用 MTK BPF 补丁"

BPF_PATCHER="mtk-bpf-patcher"
KERNEL_SRC=""
TARGET="base_boot/kernel"

mkdir -p base_boot

# ============================================================
# 路径一：使用已编译的内核镜像
# ============================================================
if [ -n "$KERNEL_IMG_URL" ]; then
  echo ">>> 下载已编译内核"
  aria2c -x8 -s8 --file-allocation=none "$KERNEL_IMG_URL" -o "$KERNEL_SRC"
  echo "    内核: $KERNEL_SRC"
fi

# ============================================================
# 路径二：从内核源码编译
# ============================================================
if [ -z "$KERNEL_SRC" ] && [ -d "kernel_src" ]; then
  echo ">>> 从源码编译内核"

  cd kernel_src

  export ARCH=arm64
  export SUBARCH=arm64
  export CROSS_COMPILE=aarch64-linux-gnu-

  command -v aarch64-linux-gnu-gcc > /dev/null 2>&1 || sudo apt install -y gcc-aarch64-linux-gnu
  command -v mkimage > /dev/null 2>&1 || sudo apt install -y u-boot-tools

  make O=out ARCH=arm64 "${DEFCONFIG_NAME}" 2>&1 | tail -10

  for t in Image.lz4-dtb Image.gz-dtb Image-dtb Image; do
    if make -j$(nproc) O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$t" 2>&1 | tail -5; then
      if [ -f "out/arch/arm64/boot/$t" ]; then
        cd ..
        KERNEL_SRC="kernel_src/out/arch/arm64/boot/$t"
        echo "    编译产物: $t"
        break
      fi
    fi
  done
  cd ..
fi

if [ -z "$KERNEL_SRC" ] || [ ! -f "$KERNEL_SRC" ]; then
  echo ">>> 警告: 无内核产物，跳过 BPF 补丁"
  echo "BPF_PATCHED=false" >> "$GITHUB_ENV"
  exit 0
fi

# ============================================================
# 下载 mtk-bpf-patcher
# ============================================================
if [ ! -f "$BPF_PATCHER" ]; then
  echo ">>> 下载 mtk-bpf-patcher"
  curl -LSs "https://github.com/R0rt1z2/mtk-bpf-patcher/releases/latest/download/mtk-bpf-patcher" \
    -o "$BPF_PATCHER" 2>/dev/null || true

  # Release 失败则从源码编译
  if [ ! -f "$BPF_PATCHER" ] || [ ! -s "$BPF_PATCHER" ]; then
    echo ">>> Release 下载失败，从源码编译"
    git clone --depth=1 https://github.com/R0rt1z2/mtk-bpf-patcher.git 2>/dev/null || true
    if [ -d "mtk-bpf-patcher" ]; then
      cd mtk-bpf-patcher
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

# ============================================================
# 应用补丁
# ============================================================
if [ -f "$BPF_PATCHER" ] && [ -x "$BPF_PATCHER" ]; then
  echo ">>> 执行 BPF 补丁"
  if "./$BPF_PATCHER" "$KERNEL_SRC" "$TARGET"; then
    echo ">>> BPF 补丁成功"
    echo "BPF_PATCHED=true" >> "$GITHUB_ENV"
  else
    echo ">>> BPF 补丁失败，使用原内核"
    cp "$KERNEL_SRC" "$TARGET"
    echo "BPF_PATCHED=false" >> "$GITHUB_ENV"
  fi
else
  echo ">>> 警告: mtk-bpf-patcher 不可用"
  cp "$KERNEL_SRC" "$TARGET"
  echo "BPF_PATCHED=false" >> "$GITHUB_ENV"
fi

echo ">>> 处理完成"
ls -lh base_boot/