#!/bin/bash
set -e
cd work

declare -A DEBLOAT_MAP=(
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
  [DEBLOAT_OTA]="my_product/app/OTA my_product/priv-app/OTA"
)

for var in "${!DEBLOAT_MAP[@]}"; do
  value="${!var:-false}"
  [ "$value" != "true" ] && continue
  for p in ${DEBLOAT_MAP[$var]}; do
    [ -d "coloros/$p" ] && rm -rf "coloros/$p" && echo "  已删除: $p"
  done
done