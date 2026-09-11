#!/bin/bash
set -e
cd work

# ============================================================
# 通用 GSI 修补脚本
# ============================================================

GSI_IMG="${GSI_IMG:-gsi/system.img}"
GSI_TYPE="${GSI_TYPE:-auto}"
PARTITION_TYPE="${PARTITION_TYPE:-${CFG_DEVICE_PARTITION_TYPE:-a-only}}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-${CFG_GSI_OUTPUT_FORMAT:-both}}"

# 命名参数
DEVICE="${CFG_DEVICE_MODEL:-${DEVICE_MODEL:-cannon}}"
SYSTEM_NAME="${CFG_DEVICE_SYSTEM_NAME:-${SYSTEM_NAME:-GSI}}"
DATE_TAG=$(date +%y%m%d)

WORK_DIR="gsi_patch"
mkdir -p "$WORK_DIR"
mkdir -p gsi

[ ! -f "$GSI_IMG" ] && echo ">>> 错误: 找不到 GSI 镜像 $GSI_IMG" && exit 1

echo ">>> GSI 镜像: $GSI_IMG"
echo ">>> 分区类型: $PARTITION_TYPE"
file "$GSI_IMG"

# ---- 检测格式 ----
if [ "$GSI_TYPE" = "auto" ]; then
  if file "$GSI_IMG" | grep -q "Android sparse"; then
    GSI_TYPE="sparse"
  elif file "$GSI_IMG" | grep -q "EROFS"; then
    GSI_TYPE="erofs"
  elif file "$GSI_IMG" | grep -q "ext4"; then
    GSI_TYPE="ext4"
  fi
fi
echo "    格式: $GSI_TYPE"

# ---- 解包 ----
IMG="$GSI_IMG"
if [ "$GSI_TYPE" = "sparse" ]; then
  simg2img "$GSI_IMG" "$WORK_DIR/gsi_raw.img"
  IMG="$WORK_DIR/gsi_raw.img"
fi

mkdir -p "$WORK_DIR/gsi_mnt"
TARGET_DIR=""
MOUNTED=false

if sudo mount -o loop,ro "$IMG" "$WORK_DIR/gsi_mnt" 2>/dev/null; then
  TARGET_DIR="$WORK_DIR/gsi_mnt"
  MOUNTED=true
else
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

# ---- 查找 etc ----
find_etc_dir() {
  for d in system/etc system_ext/etc product/etc; do
    [ -d "$TARGET_DIR/$d" ] && echo "$TARGET_DIR/$d" && return 0
  done
  return 1
}
ETC_DIR=$(find_etc_dir)
[ -z "$ETC_DIR" ] && echo ">>> 错误: 找不到 etc 目录" && exit 1
echo ">>> 注入目标: $ETC_DIR"

# ---- 注入配置 ----
[ "${INJECT_FEATURES:-${CFG_GSI_INJECT_FEATURES:-true}}" = "true" ] && [ -d "device_tree" ] && {
  F=$(find device_tree -name "device_features*" 2>/dev/null | head -1)
  [ -n "$F" ] && cp "$F" "$ETC_DIR/device_features.xml" && echo "    ✓ device_features.xml"
}

[ "${INJECT_DISPLAY:-${CFG_GSI_INJECT_DISPLAY:-true}}" = "true" ] && [ -d "device_tree" ] && {
  F=$(find device_tree -name "displayconfig*" 2>/dev/null | head -1)
  [ -n "$F" ] && cp "$F" "$ETC_DIR/displayconfig.xml" && echo "    ✓ displayconfig.xml"
}

[ "${INJECT_INIT:-${CFG_GSI_INJECT_INIT:-true}}" = "true" ] && [ -d "device_tree" ] && {
  F=$(find device_tree -name "init*.rc" 2>/dev/null | grep -i cannon | head -1)
  if [ -n "$F" ]; then
    mkdir -p "$ETC_DIR/init"
    cp "$F" "$ETC_DIR/init/init.cannon.rc"
    echo "    ✓ init.cannon.rc"
  fi
}

[ "${INJECT_MEDIA:-${CFG_GSI_INJECT_MEDIA:-true}}" = "true" ] && [ -d "device_tree" ] && {
  for pattern in "media_*.xml" "audio_*.xml" "camera_*.xml"; do
    F=$(find device_tree -name "$pattern" 2>/dev/null | head -1)
    [ -n "$F" ] && cp "$F" "$ETC_DIR/$(basename $F)" && echo "    ✓ $(basename $F)"
  done
}

[ "${INJECT_PERMISSIONS:-${CFG_GSI_INJECT_PERMISSIONS:-true}}" = "true" ] && [ -d "device_tree" ] && {
  F=$(find device_tree -name "privapp-permissions-*.xml" 2>/dev/null | head -1)
  if [ -n "$F" ]; then
    mkdir -p "$ETC_DIR/permissions"
    cp "$F" "$ETC_DIR/permissions/"
    echo "    ✓ $(basename $F)"
  fi
}

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

# ---- 重新打包 ----
if [ "$MOUNTED" = "false" ]; then
  if file "$IMG" | grep -q "EROFS"; then
    mkfs.erofs -zlz4 "gsi/patched_system.img" "$TARGET_DIR"
  else
    SIZE_MB=$(($(du -sk "$TARGET_DIR" | cut -f1) / 1024 + 200))
    make_ext4fs -s -l "${SIZE_MB}M" -a system "gsi/patched_system.img" "$TARGET_DIR"
  fi
fi

# ---- 读取安卓版本 ----
ANDROID_VER=$(strings "$GSI_IMG" 2>/dev/null | grep -m1 'ro.build.version.release=' | cut -d= -f2)
[ -z "$ANDROID_VER" ] && ANDROID_VER="15"
ANDROID_TAG="A${ANDROID_VER}"

# ---- 打包卡刷包 ----
if [ "${OUTPUT_FORMAT}" = "zip" ] || [ "${OUTPUT_FORMAT}" = "both" ]; then
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
[ -f "gsi/patched_system.img" ] && cp "gsi/patched_system.img" "gsi/$IMG_NAME" && echo "    ✓ gsi/$IMG_NAME"

echo ""
echo ">>> 修补完成"
ls -lh gsi/