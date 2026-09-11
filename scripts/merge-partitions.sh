#!/bin/bash
set -e
cd work

mkdir -p coloros/merged_my
for p in my_product my_stock my_heytap my_carrier my_company my_preload; do
  [ -d "coloros/$p" ] && cp -a "coloros/$p/." coloros/merged_my/ 2>/dev/null || true
done

[ -d "base/system_ext" ] && [ ! -d "coloros/system_ext" ] && cp -a base/system_ext coloros/system_ext
[ -d "base/apex" ] && cp -a base/apex/. coloros/system_ext/apex/ 2>/dev/null || true

for f in group passwd; do
  [ -f "base/vendor/etc/$f" ] && cp -f "base/vendor/etc/$f" "coloros/vendor/etc/$f"
done