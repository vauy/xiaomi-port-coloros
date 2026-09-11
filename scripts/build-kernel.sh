#!/bin/bash
set -e
cd work
[ "${ROOT_INTEGRATED:-false}" != "true" ] && exit 0

mkdir -p verify

compile_kernel() {
  local log=$1
  cd kernel_src
  export ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
  command -v aarch64-linux-gnu-gcc > /dev/null 2>&1 || sudo apt install -y gcc-aarch64-linux-gnu
  make O=out ARCH=arm64 "${DEFCONFIG_NAME}" 2>&1 | tee "../verify/${log}"
  if make -j$(nproc) O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.lz4-dtb 2>&1 | tee -a "../verify/${log}"; then
    if [ -f "out/arch/arm64/boot/Image.lz4-dtb" ]; then
      cp out/arch/arm64/boot/Image.lz4-dtb ../base_boot/kernel
      cd ..
      return 0
    fi
  fi
  cd ..
  return 1
}

if compile_kernel "build.log"; then
  echo "KERNEL_BUILT=true" >> "$GITHUB_ENV"
  exit 0
fi

rm -rf kernel_src/out kernel_src/KernelSU kernel_src/KernelSU-Next

FALLBACK_TYPE="kernelsu"
[ "${ROOT_TYPE:-kernelsu-next}" = "kernelsu" ] && FALLBACK_TYPE="kernelsu-next"

export ENABLE_ROOT=true ROOT_TYPE="$FALLBACK_TYPE" DEFCONFIG_NAME="$DEFCONFIG_NAME"
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