#!/bin/bash
set -e
cd work

if [ "${FIX_OPENID:-false}" = "true" ]; then
  SERIAL=$(grep -m1 'ro.serialno=' base/system/build.prop 2>/dev/null | cut -d= -f2)
  [ -z "$SERIAL" ] && SERIAL=$(grep -m1 'ro.boot.serialno=' base/vendor/build.prop 2>/dev/null | cut -d= -f2)
  if [ -n "$SERIAL" ]; then
    for prop in vendor.gsm.serial gsm.serial; do
      grep -q "^${prop}=" coloros/vendor/build.prop 2>/dev/null || echo "${prop}=${SERIAL}" >> coloros/vendor/build.prop
    done
  fi
fi

if [ "${FIX_SELINUX:-false}" = "true" ]; then
  for dir in system/etc/selinux system_ext/etc/selinux product/etc/selinux vendor/etc/selinux; do
    if [ -d "base/$dir" ] && [ -d "coloros/$dir" ]; then
      rm -rf "coloros/$dir"
      cp -a "base/$dir" "coloros/$dir"
    fi
  done
fi

if [ "${FIX_AUDIO:-false}" = "true" ]; then
  rm -f coloros/my_product/etc/audio_policy_configuration.xml
  [ -f "base/vendor/etc/audio_policy_configuration.xml" ] && \
    cp base/vendor/etc/audio_policy_configuration.xml coloros/my_product/etc/
fi

if [ "${FIX_VIBRATOR:-false}" = "true" ]; then
  PERM_DIR="coloros/my_product/etc/permissions"
  [ -d "$PERM_DIR" ] && grep -rl "lmvibrator\|richctap" "$PERM_DIR" 2>/dev/null | while read -r f; do
    sed -i '/lmvibrator/d; /richctap/d' "$f"
  done
fi

if [ "${FIX_HDR:-false}" = "true" ]; then
  find coloros/my_product/etc -iname "*hdr*" -delete 2>/dev/null || true
fi

if [