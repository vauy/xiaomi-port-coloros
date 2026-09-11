#!/bin/bash
set -e
cd work

[ -z "$ALIST_URL" ] || [ -z "$ALIST_TOKEN" ] || [ -z "$ALIST_PATH" ] && {
  echo ">>> Alist 配置不完整，跳过"
  exit 0
}

UPLOAD_DIR="${ALIST_PATH}/coloros16-$(date +%Y%m%d)"
for f in output/*.zip output/super.img; do
  [ -f "$f" ] || continue
  curl -sS -X PUT "${ALIST_URL}/api/fs/form" \
    -H "Authorization: ${ALIST_TOKEN}" \
    -H "File-Path: ${UPLOAD_DIR}/$(basename $f)" \
    -F "file=@${f}" -o /dev/null -w "    HTTP: %{http_code}\n"
done