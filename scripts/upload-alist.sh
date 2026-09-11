#!/bin/bash
set -e
cd work

[ -z "$ALIST_URL" ] || [ -z "$ALIST_TOKEN" ] || [ -z "$ALIST_PATH" ] && {
  echo ">>> Alist 配置不完整，跳过"
  exit 0
}

DEVICE="${CFG_DEVICE_MODEL:-cannon}"
SYSTEM_NAME="${CFG_DEVICE_SYSTEM_NAME:-GSI}"
UPLOAD_DIR="${ALIST_PATH}/${DEVICE}-${SYSTEM_NAME}-$(date +%Y%m%d)"

for dir in output gsi; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*.zip "$dir"/*.img; do
    [ -f "$f" ] || continue
    curl -sS -X PUT "${ALIST_URL}/api/fs/form" \
      -H "Authorization: ${ALIST_TOKEN}" \
      -H "File-Path: ${UPLOAD_DIR}/$(basename $f)" \
      -F "file=@${f}" -o /dev/null -w "    HTTP: %{http_code}\n"
  done
done