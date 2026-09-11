#!/bin/bash
set -e
cd work

PACK_MODE="${PACK_MODE:-zip}"
SUPER_SIZE="${SUPER_SIZE:-8589934592}"
OUT=output
mkdir -p "$OUT"
KERNEL_HAS_EROFS="${KERNEL_HAS_EROFS:-true}"
KERNEL_HAS_EROFS_LZ4="${KERNEL_HAS_EROFS_LZ4:-true}"

# 命名参数：优先 CFG_，其次直接变量，最后默认值
DEVICE="${CFG_DEVICE_MODEL:-${DEVICE_MODEL:-cannon}}"
SYSTEM_NAME="${CFG_DEVICE_SYSTEM_NAME:-${SYSTEM_NAME:-ColorOS}}"
ANDROID_VER="${ANDROID_VER:-15}"
ANDROID_TAG="A${ANDROID_VER}"
DATE_TAG=$(date +%y%m%d)

pack_partitions() {
  cd coloros
  for dir in */; do
    name="${dir%/}"
    case "$name" in merged_my|output|META-INF) continue ;; esac
    [ -d "$name" ] || continue
    [ -f "$name.img" ] && continue
    echo ">>> 打包 $name"
    if [ "$KERNEL_HAS_EROFS" = "true" ]; then
      EROFS_ARGS=(-b 4096 -T 1230768000 --mount-point="/$name")
      [ "$KERNEL_HAS_EROFS_LZ4" = "true" ] && EROFS_ARGS+=(-zlz4)
      if mkfs.erofs "${EROFS_ARGS[@]}" "$name.img" "$name" 2>/dev/null; then
        continue
      fi
    fi
    SIZE_MB=$(($(du -sk "$name" | cut -f1) / 1024 + 100))
    make_ext4fs -s -l "${SIZE_MB}M" -a "/$name" "$name.img" "$name"
  done
  cd ..
}

build_zip() {
  cd "$OUT"
  mkdir -p META-INF/com/google/android
  cat > META-INF/com/google/android/updater-script << 'EOFS'
ui_print("========================================");
ui_print("ColorOS Port");
ui_print("========================================");
package_extract_dir("system", "/system");
package_extract_dir("vendor", "/vendor");
package_extract_dir("my_product", "/my_product");
package_extract_dir("my_stock", "/my_stock");
ui_print("Done!");
EOFS
  cat > META-INF/com/google/android/update-binary << 'EOFB'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3
unzip -o "$ZIPFILE" 'META-INF/com/google/android/updater-script' -d /tmp > /dev/null
. /tmp/META-INF/com/google/android/updater-script
EOFB
  chmod +x META-INF/com/google/android/update-binary
  cp ../coloros/*.img . 2>/dev/null || true

  ZIP_NAME="${DEVICE}-${SYSTEM_NAME}-${ANDROID_TAG}-${DATE_TAG}.zip"
  zip -r "$ZIP_NAME" META-INF/ *.img 2>/dev/null
  echo ">>> 卡刷包: $OUT/$ZIP_NAME"
  cd ..
}

build_super() {
  PARTITIONS=()
  for img in coloros/*.img; do
    name=$(basename "$img" .img)
    case "$name" in super|vbmeta|boot|dtbo) continue ;; esac
    PARTITIONS+=("$name")
  done
  LPM_ARGS=(
    --device-size="$SUPER_SIZE"
    --metadata-size=65536
    --metadata-slots=2
    --group=main:"$SUPER_SIZE"
    --output="$OUT/${DEVICE}-${SYSTEM_NAME}-${ANDROID_TAG}-${DATE_TAG}-super.img"
  )
  for p in "${PARTITIONS[@]}"; do
    LPM_ARGS+=(--partition="$p:readonly:0:main")
    LPM_ARGS+=(--image="$p=coloros/$p.img")
  done
  lpmake "${LPM_ARGS[@]}"
  echo ">>> super.img: $OUT/${DEVICE}-${SYSTEM_NAME}-${ANDROID_TAG}-${DATE_TAG}-super.img"
}

pack_partitions

# 重命名 system.img
if [ -f "coloros/system.img" ]; then
  IMG_NAME="${DEVICE}-${SYSTEM_NAME}-${ANDROID_TAG}-${DATE_TAG}-system.img"
  cp "coloros/system.img" "$OUT/$IMG_NAME"
  echo ">>> 系统镜像: $OUT/$IMG_NAME"
fi

case "$PACK_MODE" in
  zip)   build_zip ;;
  super) build_super ;;
  both)  build_zip; build_super ;;
esac