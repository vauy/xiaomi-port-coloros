#!/bin/bash
set -e
cd work

# ============================================================
# 上传 GSI 修补产物到 Alist
# ============================================================

# 配置不完整则跳过
if [ -z "$ALIST_URL" ] || [ -z "$ALIST_TOKEN" ] || [ -z "$ALIST_PATH" ]; then
  echo ">>> Alist 配置不完整，跳过上传"
  echo "    需要 ALIST_URL / ALIST_TOKEN / ALIST_PATH"
  exit 0
fi

echo ">>> 上传到 Alist"

# 上传目录按日期命名
UPLOAD_DIR="${ALIST_PATH}/gsi-$(date +%Y%m%d)"

# 上传 gsi 目录下的产物
for f in gsi/*.zip gsi/*.img; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  size=$(du -h "$f" | cut -f1)
  echo "  上传: $name ($size)"

  # Alist v3 API：PUT /api/fs/form
  curl -sS -X PUT "${ALIST_URL}/api/fs/form" \
    -H "Authorization: ${ALIST_TOKEN}" \
    -H "File-Path: ${UPLOAD_DIR}/${name}" \
    -F "file=@${f}" \
    -o /dev/null -w "    HTTP: %{http_code}\n"
done

echo ">>> Alist 上传完成"
echo "    路径: ${UPLOAD_DIR}"