#!/bin/bash
set -e
cd work
ASSETS_DIR="../scripts/assets"
mkdir -p "$ASSETS_DIR"

# ============================================================
# 替换默认应用
# ============================================================
# 原包名                    原 APP              替换包名                          替换 APP
# --------------------------------------------------------------------------------------------
# com.heytap.browser        ColorOS 浏览器      mark.via                          Via
# com.oplus.gallery         ColorOS 相册        com.simplemobiletools.gallery.pro Simple Gallery
# com.oplus.filemanager     ColorOS 文件管理    me.zhanghai.android.files         Material Files
# ============================================================

do_replace() {
  local name=$1 enable=$2 url=$3 original_paths=$4 install_path=$5 package_name=$6
  [ "$enable" != "true" ] && echo "  跳过: $name" && return

  echo ">>> 处理: $name"

  # 1. 删除原应用
  for p in $original_paths; do
    [ -d "coloros/$p" ] && rm -rf "coloros/$p" && echo "  已删除: $p"
  done

  # 2. 下载并植入
  if [ -n "$url" ] && [ -n "$install_path" ]; then
    apk_name=$(basename "${url%%\?*}")
    [ -z "$apk_name" ] && apk_name="${name}.apk"
    case "$apk_name" in *.apk) ;; *) apk_name="${name}.apk" ;; esac

    echo "  下载: $url"
    if aria2c -x8 -s8 --file-allocation=none -o "$apk_name" -d "$ASSETS_DIR" "$url"; then
      mkdir -p "coloros/$install_path"
      cp "$ASSETS_DIR/$apk_name" "coloros/$install_path/"
      echo "  已植入: $install_path/$apk_name"

      # 3. 写入默认设置
      if [ -n "$package_name" ]; then
        echo "ro.oplus.default.${name}=${package_name}" >> coloros/my_product/build.prop
        echo "  已设置默认: ${package_name}"
      fi
    else
      echo "  下载失败，跳过植入"
    fi
  fi
}

# 浏览器
do_replace "browser" "$REPLACE_BROWSER" "$REPLACE_BROWSER_URL" \
  "my_product/app/Browser my_product/priv-app/Browser" \
  "my_product/app/ViaBrowser" "mark.via"

# 相册
do_replace "gallery" "$REPLACE_GALLERY" "$REPLACE_GALLERY_URL" \
  "my_product/app/Gallery my_product/priv-app/Gallery" \
  "my_product/app/SimpleGallery" "com.simplemobiletools.gallery.pro"

# 文件管理
do_replace "file_manager" "$REPLACE_FILE_MANAGER" "$REPLACE_FILE_MANAGER_URL" \
  "my_product/app/FileManager my_product/priv-app/FileManager" \
  "my_product/app/MaterialFiles" "me.zhanghai.android.files"

echo ">>> 替换完成"