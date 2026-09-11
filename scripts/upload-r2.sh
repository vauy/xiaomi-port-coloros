#!/bin/bash
set -e
cd work

# ============================================================
# 上传 GSI 修补产物到 Cloudflare R2
# ============================================================

# 配置不完整则跳过
if [ -z "$R2_ACCESS_KEY" ] || [ -z "$R2_SECRET_KEY" ] || [ -z "$R2_ENDPOINT" ] || [ -z "$R2_BUCKET" ]; then
  echo ">>> R2 配置不完整，跳过上传"
  echo "    需要 R2_ACCESS_KEY / R2_SECRET_KEY / R2_ENDPOINT / R2_BUCKET"
  exit 0
fi

echo ">>> 上传到 Cloudflare R2"

# 安装 aws-cli
if ! command -v aws > /dev/null 2>&1; then
  pip3 install awscli --quiet
fi

# 上传目录按日期和 commit 命名
UPLOAD_DIR="gsi-$(date +%Y%m%d)-$(git rev-parse --short HEAD 2>/dev/null || echo 'local')"

# 上传 gsi 目录下的产物
for f in gsi/*.zip gsi/*.img; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  size=$(du -h "$f" | cut -f1)
  echo "  上传: $name ($size)"
  aws s3 cp "$f" "s3://${R2_BUCKET}/${UPLOAD_DIR}/${name}" \
    --endpoint-url "$R2_ENDPOINT" --no-progress
done

echo ">>> R2 上传完成"
echo "    路径: s3://${R2_BUCKET}/${UPLOAD_DIR}/"