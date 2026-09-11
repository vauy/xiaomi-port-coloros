#!/bin/bash
set -e
cd work

CONFIG_OUT="base_kernel.config"
rm -f "$CONFIG_OUT"

if [ -n "$KERNEL_SOURCE_REPO" ]; then
  git clone --depth=1 "$KERNEL_SOURCE_REPO" kernel_src 2>/dev/null || true
  if [ -d kernel_src ]; then
    if [ -f kernel_src/.config ]; then
      cp kernel_src/.config "$CONFIG_OUT"
    else
      DEFCONFIG=$(find kernel_src/arch/arm64/configs/ -name "*defconfig" 2>/dev/null | head -1)
      [ -n "$DEFCONFIG" ] && cp "$DEFCONFIG" "$CONFIG_OUT"
    fi
  fi
fi

if [ ! -s "$CONFIG_OUT" ]; then
  mkdir -p base_boot
  unpack_bootimg --boot_img base/boot.img --out base_boot/ 2>/dev/null || true
  KERNEL_IMG="base_boot/kernel"
  [ -f "$KERNEL_IMG" ] && [ -f scripts/extract-ikconfig ] && \
    bash scripts/extract-ikconfig "$KERNEL_IMG" > "$CONFIG_OUT" 2>/dev/null || true
fi

if [ -s "$CONFIG_OUT" ]; then
  check_and_set() {
    local key=$1
    local var_name=$2
    if grep -q "^${key}=y" "$CONFIG_OUT"; then
      echo "${var_name}=true" >> "$GITHUB_ENV"
    else
      echo "${var_name}=false" >> "$GITHUB_ENV"
    fi
  }
  check_and_set "CONFIG_EROFS_FS" "KERNEL_HAS_EROFS"
  check_and_set "CONFIG_EROFS_FS_ZIP_LZ4" "KERNEL_HAS_EROFS_LZ4"
else
  echo "KERNEL_HAS_EROFS=false" >> "$GITHUB_ENV"
  echo "KERNEL_HAS_EROFS_LZ4=false" >> "$GITHUB_ENV"
fi