#!/bin/bash
set -e
cd work

# ============================================================
# GSI 构建脚本
# 用法：build-gsi.sh [kernel|gsi]
#   kernel - 编译内核
#   gsi    - 注入配置并构建 GSI
# ============================================================

MODE="${1:-gsi}"

# ============================================================
# 模式一：编译内核
# ============================================================
if [ "$MODE" = "kernel" ]; then
  echo ">>> 编译内核"

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
  make O=out ARCH=arm64 "${DEFCONFIG_NAME}" 2>&1 | tee ../verify/kernel-build.log

  # 自动探测产物名
  local target=""
  for t in Image.lz4-dtb Image.gz-dtb Image-dtb Image; do
    echo ">>> 尝试编译目标: $t"
    if make -j$(nproc) O=out ARCH=arm64 \
        CROSS_COMPILE=aarch64-linux-gnu- "$t" 2>&1 | tee -a ../verify/kernel-build.log; then
      if [ -f "out/arch/arm64/boot/$t" ]; then
        target="$t"
        break
      fi
    fi
  done

  if [ -n "$target" ]; then
    mkdir -p ../gsi
    cp "out/arch/arm64/boot/$target" "../gsi/kernel-$target"
    echo ">>> 内核编译成功: $target"
  else
    echo ">>> 内核编译失败"
    exit 1
  fi

  cd ..
  exit 0
fi

# ============================================================
# 模式二：构建 GSI
# ============================================================
echo ">>> 构建 GSI"

GSI_IMG="${GSI_IMG:-gsi/base.img}"
PARTITION_TYPE="${PARTITION_TYPE:-a-only}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-both}"

WORK_DIR="gsi_work"
mkdir -p "$WORK_DIR"
mkdir -p gsi

# ---- 检查 GSI 镜像 ----
if [ ! -f "$GSI_IMG" ]; then
  echo ">>> 错误: 找不到 GSI 镜像 $GSI_IMG"
  exit 1
fi

echo ">>> GSI 基础镜像: $GSI_IMG"
file "$GSI_IMG"

# ---- 解包 GSI ----
echo ">>> 解包 GSI"

IMG="$GSI_IMG"

if file "$GSI_IMG" | grep -q "Android sparse"; then
  simg2img "$GSI_IMG" "$WORK_DIR/gsi_raw.img"
  IMG="$WORK_DIR/gsi_raw.img"
fi

mkdir -p "$WORK_DIR/gsi_mnt"
TARGET_DIR=""
MOUNTED=false

if sudo mount -o loop,ro "$IMG" "$WORK_DIR/gsi_mnt" 2>/dev/null; then
  echo "    挂载成功"
  TARGET_DIR="$WORK_DIR/gsi_mnt"
  MOUNTED=true
else
  echo "    挂载失败，使用 debugfs/fsck.erofs 解包"
  if file "$IMG" | grep -q "EROFS"; then
    mkdir -p "$WORK_DIR/gsi_extract"
    fsck.erofs --extract="$WORK_DIR/gsi_extract" "$IMG" 2>/dev/null || true
    TARGET_DIR="$WORK_DIR/gsi_extract"
  else
    mkdir -p "$WORK_DIR/gsi_extract"
    debugfs -R "rdump / $WORK_DIR/gsi_extract" "$IMG" 2>/dev/null || true
    TARGET_DIR="$WORK_DIR/gsi_extract"
  fi
fi

# ---- 查找 etc 目录 ----
find_etc_dir() {
  for d in system/etc system_ext/etc product/etc; do
    [ -d "$TARGET_DIR/$d" ] && echo "$TARGET_DIR/$d" && return 0
  done
  return 1
}

ETC_DIR=$(find_etc_dir)
if [ -z "$ETC_DIR" ]; then
  echo ">>> 错误: 找不到 etc 目录"
  exit 1
fi
echo ">>> 注入目标: $ETC_DIR"

# ---- 注入配置 ----
echo ">>> 注入配置"

if [ "${INJECT_FEATURES:-true}" = "true" ] && [ -d "device_tree" ]; then
  F=$(find device_tree -name "device_features*" 2>/dev/null | head -1)
  [ -n "$F" ] && cp "$F" "$ETC_DIR/device_features.xml" && echo "    ✓ device_features.xml"
fi

if [ "${INJECT_DISPLAY:-true}" = "true" ] && [ -d "device_tree" ]; then
  F=$(find device_tree -name "displayconfig*" 2>/dev/null | head -1)
  [ -n "$F" ] && cp "$F" "$ETC_DIR/displayconfig.xml" && echo "    ✓ displayconfig.xml"
fi

if [ "${INJECT_INIT:-true}" = "true" ] && [ -d "device_tree" ]; then
  F=$(find device_tree -name "init*.rc" 2>/dev/null | grep -i cannon | head -1)
  if [ -n "$F" ]; then
    mkdir -p "$ETC_DIR/init"
    cp "$F" "$ETC_DIR/init/init.cannon.rc"
    echo "    ✓ init.cannon.rc"
  fi
fi

if [ "${INJECT_MEDIA:-true}" = "true" ] && [ -d "device_tree" ]; then
  for pattern in "media_*.xml" "audio_*.xml" "camera_*.xml"; do
    F=$(find device_tree -name "$pattern" 2>/dev/null | head -1)
    [ -n "$F" ] && cp "$F" "$ETC_DIR/$(basename $F)" && echo "    ✓ $(basename $F)"
  done
fi

if [ "${INJECT_PERMISSIONS:-true}" = "true" ] && [ -d "device_tree" ]; then
  F=$(find device_tree -name "privapp-permissions-*.xml" 2>/dev/null | head -1)
  if [ -n "$F" ]; then
    mkdir -p "$ETC_DIR/permissions"
    cp "$F" "$ETC_DIR/permissions/"
    echo "    ✓ $(basename $F)"
  fi
fi

# ---- 修复权限 ----
if [ "$MOUNTED" = "true" ]; then
  find "$TARGET_DIR/system/etc" "$TARGET_DIR/system_ext/etc" "$TARGET_DIR/product/etc" \
    \( -name "device_features*.xml" -o -name "displayconfig*.xml" -o -name "init.cannon.rc" \
    -o -name "media_*.xml" -o -name "audio_*.xml" -o -name "camera_*.xml" \
    -o -name "privapp-permissions-*.xml" \) 2>/dev/null | while read -r f; do
    sudo chmod 644 "$f" 2>/dev/null || true
    sudo chown 0:0 "$f" 2>/dev/null || true
    command -v chcon > /dev/null 2>&1 && sudo chcon u:object_r:system_file:s0 "$f" 2>/dev/null || true
  done
  sudo umount "$WORK_DIR/gsi_mnt" 2>/dev/null || true
fi

# ---- 重新打包镜像 ----
echo ">>> 重新打包镜像"

if [ "$MOUNTED" = "false" ]; then
  EXTRACT_DIR="$TARGET_DIR"
  if file "$IMG" | grep -q "EROFS"; then
    mkfs.erofs -zlz4 "gsi/patched_system.img" "$EXTRACT_DIR"
  else
    SIZE_MB=$(($(du -sk "$EXTRACT_DIR" | cut -f1) / 1024 + 200))
    make_ext4fs -s -l "${SIZE_MB}M" -a system "gsi/patched_system.img" "$EXTRACT_DIR"
  fi
  echo "    ✓ gsi/patched_system.img"
fi

# ---- 打包卡刷包 ----
if [ "${OUTPUT_FORMAT:-both}" = "zip" ] || [ "${OUTPUT_FORMAT:-both}" = "both" ]; then
  echo ">>> 打包卡刷包 ($PARTITION_TYPE)"

  ZIP_DIR="gsi_zip"
  rm -rf "$ZIP_DIR"
  mkdir -p "$ZIP_DIR/META-INF/com/google/android"
  cp gsi/patched_system.img "$ZIP_DIR/system.img"

  if [ "$PARTITION_TYPE" = "a-b" ]; then
    cat > "$ZIP_DIR/META-INF/com/google/android/updater-script" << 'EOF'
ui_print("GSI Build (A/B)");
package_extract_file("system.img", "/dev/block/bootdevice/by-name/system_a");
delete_recursive("/data/dalvik-cache");
EOF
  else
    cat > "$ZIP_DIR/META-INF/com/google/android/updater-script" << 'EOF'
ui_print("GSI Build (A-only)");
package_extract_file("system.img", "/dev/block/bootdevice/by-name/system");
delete_recursive("/data/dalvik-cache");
EOF
  fi

  cat > "$ZIP_DIR/META-INF/com/google/android/update-binary" << 'EOF'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3
unzip -o "$ZIPFILE" 'META-INF/com/google/android/updater-script' -d /tmp > /dev/null
. /tmp/META-INF/com/google/android/updater-script
EOF
  chmod +x "$ZIP_DIR/META-INF/com/google/android/update-binary"

  cd "$ZIP_DIR"
  zip -r "../gsi/GSI-build-${PARTITION_TYPE}.zip" . 2>/dev/null
  cd ..
  echo "    ✓ gsi/GSI-build-${PARTITION_TYPE}.zip"
fi

# ---- 汇总 ----
echo ""
echo ">>> 构建完成"
ls -lh gsi/
echo ""
echo "刷入命令："
if [ "$PARTITION_TYPE" = "a-b" ]; then
  echo "  fastboot flash system_a gsi/patched_system.img"
else
  echo "  fastboot flash system gsi/patched_system.img"
fi