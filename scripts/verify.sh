#!/bin/bash
set -e
cd work
VERIFY_DIR="verify"
mkdir -p "$VERIFY_DIR"

for img in output/*.img; do
  [ -f "$img" ] || continue
  name=$(basename "$img")
  if file "$img" | grep -q "EROFS\|ext4"; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name 格式异常" | tee -a "$VERIFY_DIR/errors.log"
  fi
done

if [ -f "output/super.img" ] && command -v lpdump > /dev/null 2>&1; then
  lpdump output/super.img > "$VERIFY_DIR/super_table.txt" 2>&1 || true
fi

MOUNT_BASE="$VERIFY_DIR/mnt"
mkdir -p "$MOUNT_BASE"
for img in output/*.img; do
  [ -f "$img" ] || continue
  name=$(basename "$img" .img)
  [ "$name" = "super" ] && continue
  mnt="$MOUNT_BASE/$name"
  mkdir -p "$mnt"
  if sudo mount -o loop,ro "$img" "$mnt" 2>/dev/null; then
    sudo umount "$mnt" 2>/dev/null || true
  else
    echo "  ✗ $name 挂载失败" | tee -a "$VERIFY_DIR/errors.log"
  fi
done