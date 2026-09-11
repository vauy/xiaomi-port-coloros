#!/bin/bash
set -e
cd work

unpack_rom() {
  local name=$1
  mkdir -p "$name" && cd "$name"
  unzip -o "../download/$name.zip" > /dev/null

  if [ -f payload.bin ]; then
    payload-dumper-go -o . payload.bin
  fi

  if [ -f super.img ]; then
    simg2img super.img super.raw.img
    lpunpack super.raw.img .
  fi

  for img in *.img; do
    fsck.erofs --extract="$img.dir" "$img" 2>/dev/null || true
  done
  cd ..
}

unpack_rom base
unpack_rom coloros
ls -lh base/ coloros/