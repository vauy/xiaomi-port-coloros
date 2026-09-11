#!/bin/bash
set -e
BASE_URL=$1
COLOROS_URL=$2
mkdir -p work/download
cd work/download
echo ">>> 下载底包"
aria2c -x16 -s16 --file-allocation=none "$BASE_URL" -o base.zip
echo ">>> 下载 ColorOS 包"
aria2c -x16 -s16 --file-allocation=none "$COLOROS_URL" -o coloros.zip
ls -lh