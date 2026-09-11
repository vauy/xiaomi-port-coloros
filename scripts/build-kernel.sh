#!/bin/bash
set -e
cd work

[ "${ROOT_INTEGRATED:-false}" != "true" ] && exit 0

mkdir -p verify

compile_kernel() {
  local log=$1
  cd kernel_src

  export ARCH=arm64
  export SUBARCH=arm64
  export CROSS_COMPILE=aarch64-linux-gnu-

  if ! command -v aarch64-linux-gnu-gcc > /dev/null 2>&1; then
    sudo apt install -y gcc-aarch64-linux-gnu
  fi

  if ! command -v mkimage > /dev/null 2>&1; then
    sudo apt install -y u-boot-tools
  fi

  make O=out ARCH=arm64 "${DEFCONFIG_NAME}" 2>&1 | tee "../verify/${log}"

  local target=""
  for t in Image.lz4-dtb Image.gz-dtb Image-dtb Image; do
    echo ">>> 尝试编译目标: $t"
    if make -j$(nproc) O=out ARCH=arm64 \
        CROSS_COMPILE=aarch64-linux-gnu- "$t" 2>&1 | tee -a "../verify/${log}"; then
      if [ -f "out/arch/arm64/boot/$t" ]; then
        target="$t"
        echo "  编译产物: $t"
        break
      fi
    fi
  done

  if [ -n "$target" ]; then
    cp "out/arch/arm64/boot/$target" ../base_boot/kernel
    cd ..
    return 0
  fi

  echo "  ✗ 未找到任何内核产物"
  cd ..
  return 1
}

if compile_kernel "build.log"; then
  echo "KERNEL_BUILT=true" >> "$GITHUB_ENV"
  exit 0
fi

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
  exit 0
fi

echo "KERNEL_BUILT=false" >> "$GITHUB_ENV"
echo "ROOT_FALLBACK_FAILED=true" >> "$GITHUB_ENV"
exit 1