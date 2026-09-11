#!/bin/bash
set -e
cd work
find coloros/ -name "fstab*" -type f | while read -r f; do
  sed -i -E -e 's/,avb_keys=[^ ]*//g' -e 's/,avb=[^ ]*//g' -e 's/,verify[^ ]*//g' -e 's/,forceencrypt=[^ ]*//g' "$f"
done
find coloros/ -name "vbmeta*" -delete 2>/dev/null || true