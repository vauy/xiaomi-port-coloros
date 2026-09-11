#!/bin/bash
set -e
cd work

echo ">>> 分析内核配置"

CONFIG_OUT="base_kernel.config"
rm -f "$CONFIG_OUT"

# ============================================================
# 路径一：优先从内核源码提取
# 支持指定分支（kernel_branch）
# ============================================================
if [ -n "$KERNEL_SOURCE_REPO" ]; then
  echo ">>> 优先使用内核源码"

  if [ -n "$KERNEL_BRANCH" ]; then
    echo "    克隆分支: $KERNEL_BRANCH"
    git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_SOURCE_REPO" kernel_src 2>/dev/null || true
  else
    echo "    克隆默认分支"
    git clone --depth=1 "$KERNEL_SOURCE_REPO" kernel_src 2>/dev/null || true
  fi

  if [ -d kernel_src ]; then
    # 优先找实际 .config
    if [ -f kernel_src/.config ]; then
      cp kernel_src/.config "$CONFIG_OUT"
      echo "    从 .config 提取成功"
    else
      # 退化到 defconfig
      DEFCONFIG=$(find kernel_src/arch/arm64/configs/ -name "*defconfig" 2>/dev/null | head -1)
      if [ -n "$DEFCONFIG" ]; then
        cp "$DEFCONFIG" "$CONFIG_OUT"
        echo "    从 defconfig 提取（可能不完整）"
      fi
    fi
  fi
fi

# ============================================================
# 路径二：从内核镜像提取（兜底）
# ============================================================
if [ ! -s "$CONFIG_OUT" ]; then
  echo ">>> 源码不可用，尝试从内核镜像提取"

  mkdir -p base_boot
  if command -v unpack_bootimg > /dev/null 2>&1; then
    unpack_bootimg --boot_img base/boot.img --out base_boot/ 2>/dev/null || true
  fi

  KERNEL_IMG="base_boot/kernel"

  # 如果 boot.img 里没有，尝试 vendor_boot.img
  if [ ! -f "$KERNEL_IMG" ] && [ -f base/vendor_boot.img ]; then
    unpack_bootimg --boot_img base/vendor_boot.img --out base_boot/ 2>/dev/null || true
    KERNEL_IMG="base_boot/kernel"
  fi

  # 用 extract-ikconfig 提取
  if [ -f "$KERNEL_IMG" ] && [ -f scripts/extract-ikconfig ]; then
    bash scripts/extract-ikconfig "$KERNEL_IMG" > "$CONFIG_OUT" 2>/dev/null || true
  fi
fi

# ============================================================
# 检查能力并写入环境变量
# ============================================================
if [ -s "$CONFIG_OUT" ]; then
  echo ">>> 内核配置提取成功，检查关键能力："

  check_and_set() {
    local key=$1
    local var_name=$2
    if grep -q "^${key}=y" "$CONFIG_OUT"; then
      echo "  ✓ ${key}"
      echo "${var_name}=true" >> "$GITHUB_ENV"
    else
      echo "  ✗ ${key} (不支持)"
      echo "${var_name}=false" >> "$GITHUB_ENV"
    fi
  }

  check_and_set "CONFIG_EROFS_FS" "KERNEL_HAS_EROFS"
  check_and_set "CONFIG_EROFS_FS_ZIP_LZ4" "KERNEL_HAS_EROFS_LZ4"
else
  echo ">>> 警告：无法提取内核配置，使用保守策略（强制 ext4）"
  echo "KERNEL_HAS_EROFS=false" >> "$GITHUB_ENV"
  echo "KERNEL_HAS_EROFS_LZ4=false" >> "$GITHUB_ENV"
fi