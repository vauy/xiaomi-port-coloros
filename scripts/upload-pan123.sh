#!/bin/bash
set -e
cd work

# ============================================================
# 上传 GSI 修补产物到 123 网盘
# ============================================================

# 配置不完整则跳过
if [ -z "$PAN123_CLIENT_ID" ] || [ -z "$PAN123_CLIENT_SECRET" ]; then
  echo ">>> 警告: 123 网盘配置不完整，跳过上传"
  echo "    需要 PAN123_CLIENT_ID / PAN123_CLIENT_SECRET"
  exit 0
fi

echo ">>> 上传到 123 网盘"

# 安装 Node.js
if ! command -v node > /dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
fi

# 安装 SDK
[ ! -d "node_modules/@ked3/pan123-sdk" ] && npm install @ked3/pan123-sdk --quiet

# 执行上传
node << 'JSEOF'
const Pan123SDK = require('@ked3/pan123-sdk');
const path = require('path');
const fs = require('fs');

const sdk = new Pan123SDK({
  clientId: process.env.PAN123_CLIENT_ID,
  clientSecret: process.env.PAN123_CLIENT_SECRET,
});

async function upload() {
  const dir = 'gsi';

  // 目录不存在则跳过
  if (!fs.existsSync(dir)) {
    console.log('  没有 gsi 目录，跳过');
    return;
  }

  // 过滤产物：img 和 zip
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.zip') || f.endsWith('.img'));

  if (files.length === 0) {
    console.log('  没有可上传的文件');
    return;
  }

  // 创建按日期命名的文件夹
  const folderName = `gsi-${new Date().toISOString().slice(0,10)}`;
  let parentId = 0;
  try {
    const resp = await sdk.createFolder(folderName, 0);
    if (resp.code === 0) {
      parentId = resp.data.fileID;
      console.log(`  创建目录: ${folderName}`);
    }
  } catch (e) {
    console.log('  创建目录失败，上传到根目录');
  }

  // 逐个上传
  for (const file of files) {
    const filePath = path.join(dir, file);
    const size = (fs.statSync(filePath).size / 1024 / 1024).toFixed(2);
    console.log(`  上传: ${file} (${size} MB)`);

    try {
      const result = await sdk.uploadFile(filePath, parentId, file);
      if (result.code === 0) {
        console.log(`    ✓ 成功${result.data.reuse ? ' (秒传)' : ''}`);
      } else {
        console.log(`    ✗ 失败: ${result.message}`);
      }
    } catch (e) {
      console.log(`    ✗ 错误: ${e.message}`);
    }
  }

  console.log(`\n>>> 上传完成，共 ${files.length} 个文件`);
}

upload().catch(console.error);
JSEOF