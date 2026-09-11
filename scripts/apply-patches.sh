#!/bin/bash
set -e
cd work

echo ">>> 删除 AVB"
find coloros/ -name "fstab*" -type f | while read -r f; do
  sed -i -E -e 's/,avb_keys=[^ ]*//g' -e 's/,avb=[^ ]*//g' -e 's/,verify[^ ]*//g' "$f"
done
find coloros/ -name "vbmeta*" -delete 2>/dev/null || true

if [ "${PATCH_OPENID:-true}" = "true" ]; then
  SERIAL="${SERIAL_NO:-}"
  [ -z "$SERIAL" ] && SERIAL=$(grep -m1 'ro.serialno=' base/system/build.prop 2>/dev/null | cut -d= -f2)
  [ -n "$SERIAL" ] && for prop in vendor.gsm.serial gsm.serial; do
    grep -q "^${prop}=" coloros/vendor/build.prop 2>/dev/null || echo "${prop}=${SERIAL}" >> coloros/vendor/build.prop
  done
fi

if [ -n "${PUNCH_HOLE_POSITION:-}" ]; then
  grep -q 'ro.oplus.display.screenhole.position' coloros/my_product/build.prop 2>/dev/null || \
    echo "ro.oplus.display.screenhole.position=${PUNCH_HOLE_POSITION}" >> coloros/my_product/build.prop
fi

if [ "${REPLACE_SELINUX:-false}" = "true" ]; then
  for dir in system/etc/selinux system_ext/etc/selinux product/etc/selinux vendor/etc/selinux; do
    if [ -d "base/$dir" ] && [ -d "coloros/$dir" ]; then
      rm -rf "coloros/$dir"
      cp -a "base/$dir" "coloros/$dir"
    fi
  done
fi

if [ "${PATCH_FIRST_API_LEVEL:-true}" = "true" ]; then
  BASE_API=$(grep -m1 'ro.product.first_api_level=' base/system/build.prop 2>/dev/null | cut -d= -f2)
  [ -n "$BASE_API" ] && grep -q 'ro.product.first_api_level=' coloros/system/build.prop 2>/dev/null || \
    echo "ro.product.first_api_level=${BASE_API}" >> coloros/system/build.prop
fi

if [ -d "../config/patches" ]; then
  for p in ../config/patches/*.sh; do
    [ -f "$p" ] && bash "$p"
  done
fi