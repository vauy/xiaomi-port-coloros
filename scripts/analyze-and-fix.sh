#!/bin/bash
set -e
cd work
LOG_DIR="verify"
FIX_LOG="$LOG_DIR/fix.log"
FIXED=false
mkdir -p "$LOG_DIR"

log_fix() { echo "[$(date +%H:%M:%S)] $1" | tee -a "$FIX_LOG"; }
match_log() { grep -rqE "$1" "$LOG_DIR"/*.log 2>/dev/null; }

if match_log "avb.*verify|avb_keys"; then
  log_fix ">>> AVB 残留 → 清理"
  find coloros/ -name "fstab*" -type f | while read -r f; do
    sed -i -E -e 's/,avb_keys=[^ ]*//g' -e 's/,avb=[^ ]*//g' -e 's/,verify[^ ]*//g' "$f"
  done
  FIXED=true
fi

if match_log "erofs.*magic|erofs.*invalid"; then
  log_fix ">>> EROFS 问题 → 降级 ext4"
  echo "KERNEL_HAS_EROFS=false" >> "$GITHUB_ENV"
  rm -f coloros/*.img
  FIXED=true
fi

if match_log "lz4.*decompress|lz4.*unsupported"; then
  log_fix ">>> LZ4 问题 → 去压缩"
  echo "KERNEL_HAS_EROFS_LZ4=false" >> "$GITHUB_ENV"
  rm -f coloros/*.img
  FIXED=true
fi

if match_log "lpmake.*invalid|partition.*overlap"; then
  log_fix ">>> super 分区表错误"
  ACTUAL=$(du -sb coloros/*.img 2>/dev/null | awk '{s+=$1} END {print s}')
  [ -n "$ACTUAL" ] && [ "$ACTUAL" -gt 0 ] && echo "SUPER_SIZE=$((ACTUAL * 12 / 10))" >> "$GITHUB_ENV"
  FIXED=true
fi

if [ "$FIXED" = "true" ]; then
  echo "NEED_REPACK=true" >> "$GITHUB_ENV"
else
  echo "NEED_REPACK=false" >> "$GITHUB_ENV"
fi