#!/bin/bash
set -e
cd work

# ============================================================
# 通用 GSI 修补脚本
# 支持 A-only / A/B 机型
# ============================================================

GSI_IMG="${GSI_IMG:-gsi/system.img}"
GSI_TYPE="${GSI_TYPE:-auto}"
PARTITION_TYPE="${PARTITION_TYPE:-a-only}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-both}"

# 命名参数
DEVICE="${DEVICE_MODEL:-cannon}"
SYSTEM_NAME="${SYSTEM_NAME:-GSI}"
DATE_TAG=$(date +%y%m%d)

WORK_DIR="gsi_patch"
mkdir -p "$WORK_DIR"
mkdir -p gsi

if [ ! -f "$GSI_IMG" ]; then
  echo ">>> 错误: 找不到 GSI 镜像 $GSI_IMG"
  exit 1
fi

echo ">>> GSI 镜像: $GSI_IMG"
echo ">>> 分区类型: $PARTITION_TYPE"
file "$GSI_IMG"

# ---- 检测格式 ----
echo ">>> 检测 GSI 格式"
if [ "$GSI_TYPE" = "auto" ]; then
  if file "$GSI_IMG" | grep -q "Android sparse"; then
    GSI_TYPE="sparse"
  elif file "$GSI_IMG" | grep -q "EROFS"; then
    GSI_TYPE="erofs"
  elif file "$GSI_IMG" | grep -q "ext4"; then
    GSI_TYPE="ext4"
  else
    GSI_TYPE="unknown"
  fi
fi
echo "    格式: $GSI_TYPE"

# ---- 解包 GSI ----
echo ">>> 解包 GSI"
IMG="$GSI_IMG"
if [ "$GSI_TYPE" = "sparse" ]; then
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
  MOUNTED=false
fi

# ---- 分析内核配置 ----
echo ">>> 分析内核配置"
if [ -d "kernel_src" ]; then
  DEFCONFIG="kernel_src/arch/arm64/configs/${DEFCONFIG_NAME:-cannon_defconfig}"
  if [ -f "$DEFCONFIG" ]; then
    echo "    defconfig: $DEFCONFIG"
    for key in CONFIG_EROFS_FS CONFIG_EROFS_FS_ZIP_LZ4; do
      if grep -q "^${key}=y" "$DEFCONFIG"; then
        echo "    ✓ $key"
      else
        echo "    ✗ $key"
      fi
    done
  fi
fi

# ---- 查找 etc ----
echo ">>> 查找 GSI etc 目录"
find_etc_dir() {
  for d in system/etc system_ext/etc product/etc; do
    if [ -d "$TARGET_DIR/$d" ]; then
      echo "$TARGET_DIR/$d"
      return 0
    fi
  done
  return 1
}
ETC_DIR=$(find_etc_dir)
if [ -z "$ETC_DIR" ]; then
  echo "    错误: 找不到 etc 目录"
  exit 1
fi
echo "    注入目标: $ETC_DIR"

# ---- 注入配置 ----
echo ">>> 注入配置"

if [ "${INJECT_FEATURES:-true}" = "true" ] && [ -d "device_tree" ]; then
  FEATURES=$(find device_tree -name "device_features*" 2>/dev/null | head -1)
  [ -n "$FEATURES" ] && cp "$FEATURES" "$ETC_DIR/device_features.xml" && echo "    ✓ device_features.xml"
fi

if [ "${INJECT_DISPLAY:-true}" = "true" ] && [ -d "device_tree" ]; then
  DISPLAY=$(find device_tree -name "displayconfig*" 2>/dev/null | head -1)
  [ -n "$DISPLAY" ] && cp "$DISPLAY" "$ETC_DIR/displayconfig.xml" && echo "    ✓ displayconfig.xml"
fi

if [ "${INJECT_INIT:-true}" = "true" ] && [ -d "device_tree" ]; then
  INIT_RC=$(find device_tree -name "init*.rc" 2>/dev/null | grep -i cannon | head -1)
  if [ -n "$INIT_RC" ]; then
    mkdir -p "$ETC_DIR/init"
    cp "$INIT_RC" "$ETC_DIR/init/init.cannon.rc"
    echo "    ✓ init.cannon.rc"
  fi
fi

if [ "${INJECT_MEDIA:-true}" = "true" ] && [ -d "device_tree" ]; then
  for pattern in "media_*.xml" "audio_*.xml" "camera_*.xml"; do
    FILE=$(find device_tree -name "$pattern" 2>/dev/null | head -1)
    [ -n "$FILE" ] && cp "$FILE" "$ETC_DIR/$(basename $FILE)" && echo "    ✓ $(basename $FILE)"
  done
fi

if [ "${INJECT_PERMISSIONS:-true}" = "true" ] && [ -d "device_tree" ]; then
  PERM=$(find device_tree -name "privapp-permissions-*.xml" 2>/dev/null | head -1)
  if [ -n "$PERM" ]; then
    mkdir -p "$ETC_DIR/permissions"
    cp "$PERM" "$ETC_DIR/permissions/"
    echo "    ✓ $(basename $PERM)"
  fi
fi

# ---- 修复权限 ----
echo ">>> 修复权限"
if [ "$MOUNTED" = "true" ]; then
  INJECTED_FILES=$(find "$TARGET_DIR/system/etc" "$TARGET_DIR/system_ext/etc" "$TARGET_DIR/product/etc" \
    \( -name "device_features*.xml" -o -name "displayconfig*.xml" -o -name "init.cannon.rc" \
    -o -name "media_*.xml" -o -name "audio_*.xml" -o -name "camera_*.xml" \
    -o -name "privapp-permissions-*.xml" \) 2>/dev/null)
  for f in $INJECTED_FILES; do
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

# ---- 读取安卓版本 ----
ANDROID_VER=$(strings "$GSI_IMG" 2>/dev/null | grep -m1 'ro.build.version.release=' | cut -d= -f2)
[ -z "$ANDROID_VER" ] && ANDROID_VER="15"
ANDROID_TAG="A${ANDROID_VER}"

# ---- 打包卡刷包 ----
if [ "${OUTPUT_FORMAT:-both}" = "zip" ] || [ "${OUTPUT_FORMAT:-both}" = "both" ]; then
  echo ">>> 打包卡刷包 ($PARTITION_TYPE)"

  ZIP_DIR="gsi_zip"
  rm -rf "$ZIP_DIR"
  mkdir -p "$ZIP_DIR/META-INF/com/google/android"
  cp gsi/patched_system.img "$ZIP_DIR/system.img"

  if [ "$PARTITION_TYPE" = "a-b" ]; then
    cat > "$ZIP_DIR/META-INF/com/google/android/updater-script" << 'EOF'
ui_print("GSI Patch (A/B)");
package_extract_file("system.img", "/dev/block/bootdevice/by-name/system_a");
delete_recursive("/data/dalvik-cache");
EOF
  else
    cat > "$ZIP_DIR/META-INF/com/google/android/updater-script" << 'EOF'
ui_print("GSI Patch (A-only)");
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

  ZIP_NAME="${DEVICE}-${SYSTEM_NAME}-${ANDROID_TAG}-${DATE_TAG}.zip"

  cd "$ZIP_DIR"
  zip -r "../gsi/$ZIP_NAME" . 2>/dev/null
  cd ..
  echo "    ✓ gsi/$ZIP_NAME"
fi

# ---- 重命名 img ----
IMG_NAME="${DEVICE}-${SYSTEM_NAME}-${ANDROID_TAG}-${DATE_TAG}-system.img"
if [ -f "gsi/patched_system.img" ]; then
  cp "gsi/patched_system.img" "gsi/$IMG_NAME"
  echo "    ✓ gsi/$IMG_NAME"
fi

# ---- 汇总 ----
echo ""
echo ">>> 修补完成"
ls -lh gsi/
echo ""
echo "刷入命令："
if [ "$PARTITION_TYPE" = "a-b" ]; then
  echo "  fastboot flash system_a gsi/$IMG_NAME"
else
  echo "  fastboot flash system gsi/$IMG_NAME"
fi