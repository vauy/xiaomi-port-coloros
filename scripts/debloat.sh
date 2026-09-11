#!/bin/bash
set -e
cd work

echo ">>> 开始精简 APP"

# ============================================================
# 精简映射表
# ============================================================
# 格式：[环境变量]="路径1 路径2"
#
# 变量名                   包名                       APP 名称           风险
# ---------------------------------------------------------------------------
# DEBLOAT_AD               com.oplus.ad               广告服务           低
# DEBLOAT_APP_MARKET       com.heytap.market          OPPO 软件商店      低
# DEBLOAT_GAME_CENTER      com.oplus.gamecenter       游戏中心           低
# DEBLOAT_BROWSER          com.heytap.browser         ColorOS 浏览器     低
# DEBLOAT_CONTENT_EXT      com.oplus.content          内容推荐服务       低
# DEBLOAT_THEME_STORE      com.heytap.themestore      主题商店           低
# DEBLOAT_VOICE_ASSISTANT  com.oplus.voiceassistant   小布语音助手       低
# DEBLOAT_MUSIC            com.oplus.music            ColorOS 音乐       低
# DEBLOAT_VIDEO            com.oplus.video            ColorOS 视频       低
# DEBLOAT_FEEDBACK         com.oplus.feedback         用户反馈           低
# DEBLOAT_OTA              com.oplus.ota              OTA 更新服务       中
# DEBLOAT_PUSH             com.oplus.push             OPPO 推送服务      中
# DEBLOAT_WALLPAPER        com.oplus.wallpaper        动态壁纸           中
# DEBLOAT_GALLERY          com.oplus.gallery          相册               中
# DEBLOAT_CLOUD            com.oplus.cloud            云服务             高
# DEBLOAT_ACCOUNT          com.oplus.account          账号服务           高
# DEBLOAT_IME              com.oplus.ime              自带输入法         极高
# DEBLOAT_CAMERA           com.oplus.camera           相机               极高
# ============================================================

declare -A DEBLOAT_MAP=(
  # ---- 低风险，可安全删除 ----
  [DEBLOAT_AD]="my_product/app/AdServices my_product/priv-app/AdServices"
  [DEBLOAT_APP_MARKET]="my_product/app/AppMarket my_product/priv-app/AppMarket"
  [DEBLOAT_GAME_CENTER]="my_product/app/GameCenter my_product/priv-app/GameCenter"
  [DEBLOAT_BROWSER]="my_product/app/Browser my_product/priv-app/Browser"
  [DEBLOAT_CONTENT_EXT]="my_product/app/ContentExt my_product/priv-app/ContentExt"
  [DEBLOAT_THEME_STORE]="my_product/app/ThemeStore my_product/priv-app/ThemeStore"
  [DEBLOAT_VOICE_ASSISTANT]="my_product/app/VoiceAssistant my_product/priv-app/VoiceAssistant"
  [DEBLOAT_MUSIC]="my_product/app/Music my_product/priv-app/Music"
  [DEBLOAT_VIDEO]="my_product/app/Video my_product/priv-app/Video"
  [DEBLOAT_FEEDBACK]="my_product/app/Feedback my_product/priv-app/Feedback"

  # ---- 中风险，删后可能影响部分功能 ----
  [DEBLOAT_OTA]="my_product/app/OTA my_product/priv-app/OTA"
  [DEBLOAT_PUSH]="my_product/app/OplusPush my_product/priv-app/OplusPush"
  [DEBLOAT_WALLPAPER]="my_product/app/Wallpaper my_product/priv-app/Wallpaper"
  [DEBLOAT_GALLERY]="my_product/app/Gallery my_product/priv-app/Gallery"

  # ---- 高风险，删后系统功能受损 ----
  [DEBLOAT_CLOUD]="my_product/app/CloudService my_product/priv-app/CloudService"
  [DEBLOAT_ACCOUNT]="my_product/app/OplusAccount my_product/priv-app/OplusAccount"

  # ---- 极高风险，删后基本功能不可用 ----
  [DEBLOAT_IME]="my_product/app/OplusIme my_product/priv-app/OplusIme"
  [DEBLOAT_CAMERA]="my_product/app/Camera my_product/priv-app/Camera"
)

for var in "${!DEBLOAT_MAP[@]}"; do
  value="${!var:-false}"
  [ "$value" != "true" ] && continue
  for p in ${DEBLOAT_MAP[$var]}; do
    [ -d "coloros/$p" ] && rm -rf "coloros/$p" && echo "  已删除: $p"
  done
done

echo ">>> 精简完成"