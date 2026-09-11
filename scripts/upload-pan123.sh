#!/bin/bash
set -e
cd work

if [ -z "$PAN123_CLIENT_ID" ] || [ -z "$PAN123_CLIENT_SECRET" ]; then
  echo ">>> 123 网盘配置不完整，跳过"
  exit 0
fi

command -v node > /dev/null 2>&1 || {
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
}

[ ! -d "node_modules/@ked3/pan123-sdk" ] && npm install @ked3/pan123-sdk --quiet

node << 'JSEOF'
const Pan123SDK = require('@ked3/pan123-sdk');
const path = require('path');
const fs = require('fs');

const sdk = new Pan123SDK({
  clientId: process.env.PAN123_CLIENT_ID,
  clientSecret: process.env.PAN123_CLIENT_SECRET,
});

async function upload() {
  // 扫描 output 和 gsi 两个目录
  const dirs = ['output', 'gsi'];
  const files = [];
  for (const dir of dirs) {
    if (fs.existsSync(dir)) {
      fs.readdirSync(dir)
        .filter(f => f.endsWith('.zip') || f.endsWith('.img'))
        .forEach(f => files.push({ dir, name: f }));
    }
  }

  if (files.length === 0) {
    console.log('  没有可上传的文件');
    return;
  }

  const folderName = `${process.env.CFG_DEVICE_MODEL || 'cannon'}-${process.env.CFG_DEVICE_SYSTEM_NAME || 'GSI'}-${new Date().toISOString().slice(0,10)}`;
  let parentId = 0;
  try {
    const resp = await sdk.createFolder(folderName, 0);
    if (resp.code === 0) parentId = resp.data.fileID;
  } catch (e) {}

  for (const { dir, name } of files) {
    const filePath = path.join(dir, name);
    const size = (fs.statSync(filePath).size / 1024 / 1024).toFixed(2);
    console.log(`  上传: ${name} (${size} MB)`);
    try {
      const result = await sdk.uploadFile(filePath, parentId, name);
      console.log(result.code === 0 ? `    ✓ ${name}` : `    ✗ ${name}: ${result.message}`);
    } catch (e) {
      console.log(`    ✗ ${name}: ${e.message}`);
    }
  }
}
upload().catch(console.error);
JSEOF