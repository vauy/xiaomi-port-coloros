#!/bin/bash
set -e
cd work

[ "${ROOT_INTEGRATED:-false}" != "true" ] && exit 0

mkdir -p verify

DEVICE="${CFG_DEVICE_MODEL:-${DEVICE_MODEL:-cannon}}"
SYSTEM_NAME="${CFG_DEVICE_SYSTEM_NAME:-${SYSTEM_NAME:-ColorOS}}"
ANDROID_VER="${ANDROID_VER:-15}"
ANDROID_TAG="A${ANDROID_VER}"
DATE_TAG=$(date +%y%m%d)

compile_kernel() {
  local log=$1
  cd kernel_src

  export ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

  command -v aarch64-linux-gnu-gcc > /dev/null 2>&1 || sudo apt install -y gcc-aarch64-linux-gnu
  command -v mkimage > /dev/null 2>&1 || sudo apt install -y u-boot-tools

  make O=out ARCH=arm64 "${DEFCONFIG_NAME}" 2>&1 | tee "../verify/${log}"

  local target=""
  for t in Image.lz4-dtb Image.gz-dtb Image-dtb Image; do
    if make -j$(nproc) O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$t" 2>&1 | tee -a "../verify/${log}"; then
      [ -f "out/arch/arm64/boot/$t" ] && target="$t" && break
    fi
  done

  if [ -n "$target" ]; then
    cd ..
    echo "KERNEL_TARGET=$target" >> "$GITHUB_ENV"
    return 0
  fi
  cd ..
  return 1
}

if compile_kernel "build.log"; then
  echo "KERNEL_BUILT=true" >> "$GITHUB_ENV"
else