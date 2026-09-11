#!/bin/bash
set -e
cd work
ASSETS_DIR="../scripts/assets"
mkdir -p "$ASSETS_DIR"

do_replace() {
  local name=$1 enable=$2 url=$3 original_paths=$4 install_path=$5 package_name=$6
  [ "$enable" != "true" ] && return
  for p in $original_paths; do
    [ -d "coloros/$p" ] && rm -rf "coloros/$p"
  done
  if [ -n "$url" ] && [ -n "$install_path" ]; then
    apk_name=$(basename "${url%%\?*}")
    [ -z "$apk_name" ] && apk_name="${name}.apk"
    case "$apk_name" in *.apk) ;; *) apk_name="${name}.apk" ;; esac
    if aria2c -x8 -s8 --file-allocation=none -o "$apk_name" -d "$ASSETS_DIR" "$url"; then
      mkdir -p "coloros/$install_path"
      cp "$ASSETS_DIR/$apk_name" "coloros/$install_path/"
      [ -n "$package_name" ] && echo "ro.oplus.default.${name}=${package_name}" >> coloros/my_product/build.prop
    fi
  fi
}

do_replace "browser" "$REPLACE_BROWSER" "$REPLACE_BROWSER_URL" \
  "my_product/app/Browser my_product/priv-app/Browser" \
  "my_product/app/ViaBrowser" "mark.via"

do_replace "gallery" "$REPLACE_GALLERY" "$REPLACE_GALLERY_URL" \
  "my_product/app/Gallery my_product/priv-app/Gallery" \
  "my_product/app/SimpleGallery" "com.simplemobiletools.gallery.pro"

do_replace "file_manager" "$REPLACE_FILE_MANAGER" "$REPLACE_FILE_MANAGER_URL" \
  "my_product/app/FileManager my_product/priv-app/FileManager" \
  "my_product/app/MaterialFiles" "me.zhanghai.android.files"