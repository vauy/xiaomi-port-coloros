#!/bin/bash
set -e
cd work

[ -z "$R2_ACCESS_KEY" ] || [ -z "$R2_SECRET_KEY" ] || [ -z "$R2_ENDPOINT" ] || [ -z "$R2_BUCKET" ] && {
  echo ">>> R2 配置不完整，跳过"
  exit 0
}

command -v aws > /dev/null 2>&1 || pip3 install awscli --quiet

DEVICE="${CFG_DEVICE_MODEL:-cannon}"
SYSTEM_NAME="${CFG_DEVICE_SYSTEM_NAME:-GSI}"
UPLOAD_DIR="${DEVICE}-${SYSTEM_NAME}-$(date +%Y%m%d)"

for dir in output gsi; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*.zip "$dir"/*.img; do
    [ -f "$f" ] || continue
    aws s3 cp "$f" "s3://${R2_BUCKET}/${UPLOAD_DIR}/$(basename $f)" \
      --endpoint-url "$R2_ENDPOINT" --no-progress
  done
done