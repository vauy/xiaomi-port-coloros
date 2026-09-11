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
  const dir = 'output';
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.zip') || f.endsWith('.img'));
  const folderName = `coloros16-${new Date().toISOString().slice(0,10)}`;
  let parentId = 0;
  try {
    const resp = await sdk.createFolder(folderName, 0);
    if (resp.code === 0) parentId = resp.data.fileID;
  } catch (e) {}
  for (const file of files) {
    try {
      const result = await sdk.uploadFile(path.join(dir, file), parentId, file);
      console.log(result.code === 0 ? `    ✓ ${file}` : `    ✗ ${file}`);
    } catch (e) {
      console.log(`    ✗ ${file}: ${e.message}`);
    }
  }
}
upload().catch(console.error);
JSEOF