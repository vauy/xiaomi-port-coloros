# xiaomi-port-coloros

小米 → ColorOS 16 半自动移植工作流。

基于 GitHub Actions，把「下载、解包、内核分析、Root 集成、编译、精简、替换、修复、打包、验证、上传」全部串成一条流水线。

---

## 📋 目录

- [快速开始](#快速开始)
- [工作流步骤](#工作流步骤)
- [精简 APP 对照表](#精简-app-对照表)
- [替换应用对照表](#替换应用对照表)
- [系统级修复开关](#系统级修复开关)
- [机型专属配置](#机型专属配置)
- [上传方式](#上传方式)
- [内核 Root 集成](#内核-root-集成)
- [内核编译失败排查](#内核编译失败排查)
- [脚本说明](#脚本说明)
- [常见问题](#常见问题)

---

## 🚀 快速开始

1. Fork 本仓库到你的 GitHub 账号
2. 进入 **Actions** → **Port ColorOS 16** → **Run workflow**
3. 按界面提示填写：
   - 底包直链（MIUI/澎湃）
   - ColorOS 16 移植包直链
   - 内核源码地址（可选，集成 Root 时需要）
   - defconfig 名（可选）
   - 精简/替换/修复开关
   - 机型专属配置（挖孔坐标等）
   - 上传方式（默认 123 网盘）
4. 点 **Run workflow** 开始跑
5. 跑完后在 123 网盘下载 ROM

---

## ⚙️ 工作流步骤

| 步骤 | 脚本 | 说明 |
|---|---|---|
| 1. 下载固件 | `download.sh` | 下载底包和 ColorOS 包 |
| 2. 解包 | `unpack.sh` | 处理 payload.bin / super.img / EROFS |
| 3. 分析内核配置 | `analyze-kernel.sh` | 优先源码，其次镜像提取 .config |
| 4. 集成 Root | `integrate-root.sh` | KernelSU Next 优先，失败回退原版 |
| 5. 编译内核 | `build-kernel.sh` | 编译带 Root 的内核，失败自动回退 |
| 6. 合并分区 | `merge-partitions.sh` | 合并 my 分区、补 system_ext |
| 7. 精简 APP | `debloat.sh` | 按开关删除指定 APP |
| 8. 替换应用 | `replace-apps.sh` | 删除原应用 → 下载 → 植入 → 设默认 |
| 9. 系统级修复 | `system-fixes.sh` | OpenID/SELinux/音频/振动等 |
| 10. 机型补丁 | `apply-patches.sh` | AVB/挖孔/first_api_level |
| 11. 修复 fstab | `fix-fstab.sh` | 清理 AVB 校验参数 |
| 12. 打包 | `pack.sh` | 输出卡刷包或 super.img |
| 13. 验证镜像 | `verify.sh` | 检查格式、分区表、挂载 |
| 14. 日志分析 | `analyze-and-fix.sh` | 自动修复确定性问题 |
| 15. 回滚 | `rollback-fix.sh` | 二次验证失败时回滚 |
| 16. 上传 | `upload-*.sh` | 上传到 123 网盘/R2/Alist/Release |

---

## 📦 精简 APP 对照表

| Actions 开关 | 包名 | APP 名称 | 路径 | 风险 |
|---|---|---|---|---|
| `debloat_ad` | `com.oplus.ad` | 广告服务 | `my_product/app/AdServices` | 低 |
| `debloat_app_market` | `com.heytap.market` | OPPO 软件商店 | `my_product/app/AppMarket` | 低 |
| `debloat_game_center` | `com.oplus.gamecenter` | 游戏中心 | `my_product/app/GameCenter` | 低 |
| `debloat_browser` | `com.heytap.browser` | ColorOS 浏览器 | `my_product/app/Browser` | 低 |
| `debloat_content_ext` | `com.oplus.content` | 内容推荐服务 | `my_product/app/ContentExt` | 低 |
| `debloat_theme_store` | `com.heytap.themestore` | 主题商店 | `my_product/app/ThemeStore` | 低 |
| `debloat_voice_assistant` | `com.oplus.voiceassistant` | 小布语音助手 | `my_product/app/VoiceAssistant` | 低 |
| `debloat_music` | `com.oplus.music` | ColorOS 音乐 | `my_product/app/Music` | 低 |
| `debloat_video` | `com.oplus.video` | ColorOS 视频 | `my_product/app/Video` | 低 |
| `debloat_feedback` | `com.oplus.feedback` | 用户反馈 | `my_product/app/Feedback` | 低 |
| `debloat_ota` | `com.oplus.ota` | OTA 更新服务 | `my_product/app/OTA` | 中 |

### 未默认启用，可手动加

| 包名 | APP 名称 | 路径 | 风险 |
|---|---|---|---|
| `com.oplus.push` | OPPO 推送服务 | `my_product/app/OplusPush` | 中 |
| `com.oplus.wallpaper` | 动态壁纸 | `my_product/app/Wallpaper` | 中 |
| `com.oplus.gallery` | 相册 | `my_product/app/Gallery` | 中 |
| `com.oplus.cloud` | 云服务 | `my_product/app/CloudService` | 高 |
| `com.oplus.account` | 账号服务 | `my_product/app/OplusAccount` | 高 |
| `com.oplus.ime` | 自带输入法 | `my_product/app/OplusIme` | 极高 |
| `com.oplus.camera` | 相机 | `my_product/app/Camera` | 极高 |

---

## 🔄 替换应用对照表

| Actions 开关 | 原包名 | 原 APP | 替换包名 | 替换 APP | 风险 |
|---|---|---|---|---|---|
| `replace_browser` | `com.heytap.browser` | ColorOS 浏览器 | `mark.via` | Via | 低 |
| `replace_gallery` | `com.oplus.gallery` | ColorOS 相册 | `com.simplemobiletools.gallery.pro` | Simple Gallery | 中 |
| `replace_file_manager` | `com.oplus.filemanager` | ColorOS 文件管理 | `me.zhanghai.android.files` | Material Files | 低 |

---

## 🩹 系统级修复开关

| Actions 开关 | 修复问题 | 根因 | 风险 |
|---|---|---|---|
| `fix_openid` | OpenID/OUID 卡顿 | 缺 OPlus 序列号属性 | 低 |
| `fix_selinux` | SELinux 拒绝 | sepolicy 不匹配 | 中 |
| `fix_audio` | 音频炸裂 | 音频策略不兼容 | 低 |
| `fix_vibrator` | 振动异常 | 权限段不匹配 | 低 |
| `fix_hdr` | 抖音卡顿 | HDR 特性冲突 | 低 |
| `fix_wechat_scan` | 微信扫一扫 | 相机优化冲突 | 低 |
| `fix_wallpaper` | 实况壁纸黑屏 | 壁纸服务不兼容 | 中 |
| `fix_color_temp` | 屏幕色温异常 | 色温曲线不匹配 | 低 |
| `fix_nfc` | NFC 不可用 | NFC 配置不匹配 | 中 |
| `fix_modem` | 信号丢失 | modem 配置不匹配 | 高 |

---

## 📱 机型专属配置

| Actions 输入 | 说明 | 示例 |
|---|---|---|
| `device_model` | 机型标识 | `xiaomi13` |
| `punch_hole_position` | 挖孔坐标 | `505,29:575,99` |
| `soc_model` | 芯片平台（留空自动检测） | `sm8650` |
| `serial_no` | 序列号（留空自动读取） | 空 |
| `replace_selinux` | 是否替换 SELinux | 新平台建议开 |
| `patch_first_api_level` | 是否修补 first_api_level | 默认开 |
| `patch_openid` | 是否修复 OpenID | 默认开 |

### 挖孔坐标怎么测

1. 开发者选项 → **指针位置**
2. 手指点在挖孔左上角和右下角
3. 记录两组坐标，格式：`左x,上y:右x,下y`

---

## 📤 上传方式

上传方式是**独立勾选框**，可以多选。

| 勾选项 | 说明 | 需要 Secrets | 单文件限制 |
|---|---|---|---|
| `upload_pan123` | 123 网盘（**默认**） | ✅ | 100GB+ |
| `upload_release` | GitHub Release | ❌ | ≤2GB |
| `upload_r2` | Cloudflare R2 | ✅ | 无限制 |
| `upload_alist` | Alist | ✅ | 取决于后端 |
| `upload_artifact` | GitHub Artifact | ❌ | 无，7天过期 |

### 123 网盘配置

1. 登录 [123 云盘开放平台](https://www.123pan.com/open/)
2. 创建应用，获取 **Client ID** 和 **Client Secret**
3. 在仓库 **Settings → Secrets → Actions** 配置：
   - `PAN123_CLIENT_ID`
   - `PAN123_CLIENT_SECRET`
4. 或在 Actions 输入框里直接填（临时测试用）

### 其他网盘配置

**Cloudflare R2**：
- `R2_ACCESS_KEY`
- `R2_SECRET_KEY`
- `R2_ENDPOINT`
- `R2_BUCKET`

**Alist**：
- `ALIST_URL`
- `ALIST_TOKEN`
- `ALIST_PATH`

---

## 🔧 内核 Root 集成

### 默认方案：KernelSU Next

工作流默认集成 **KernelSU Next**，支持 4.4 到 6.6 内核。

| 内核版本 | 集成方式 |
|---|---|
| 4.14 / 4.19 | 手动打 5 个补丁 |
| 5.10+ GKI | 自动集成 |

### 回退机制

如果 KernelSU Next 失败，自动回退到原版 KernelSU：

- 4.14 / 4.19：锁 `v0.9.5`
- 5.10+ GKI：用最新版

两次都失败时，内核不带 Root，但移植流程继续。

### 4.14 手动补丁

| 补丁 | 文件 | 作用 |
|---|---|---|
| 1 | `fs/exec.c` | 拦截进程执行 |
| 2 | `fs/open.c` | 拦截文件访问权限 |
| 3 | `fs/read_write.c` | 拦截文件读取 |
| 4 | `fs/stat.c` | 拦截文件状态查询 |
| 5 | `include/linux/sched.h` | 加 `ksu_flags` 字段 |

---

## 🔧 内核编译失败排查

### 错误 1：`undefined reference to ksu_*`

**原因**：Kbuild 没接入，KernelSU 源码没被编译。

**修复**：
```bash
cd kernel_src
grep "KernelSU" drivers/Makefile
grep "KernelSU" drivers/Kconfig
```

### 错误 2：`Kbuild: No such file or directory`

**原因**：KernelSU 目录名和 Kbuild 里写的不一致。

**修复**：
```bash
ls -la kernel_src/ | grep -i kernelsu
```

### 错误 3：`pattern not found in fs/exec.c`

**原因**：手动补丁的正则没匹配到函数签名。

**修复**：
```bash
grep -A2 "do_execveat_common" kernel_src/fs/exec.c
grep -A2 "vfs_fstatat\|vfs_statx" kernel_src/fs/stat.c
```

### 错误 4：`aarch64-linux-gnu-gcc: command not found`

**修复**：
```bash
sudo apt install -y gcc-aarch64-linux-gnu
```

### 错误 5：`Image.lz4-dtb` 不存在

**原因**：产物名不对，有些内核是 `Image.gz-dtb`。

**修复**：
```bash
ls kernel_src/out/arch/arm64/boot/
```

---

## 📁 脚本说明

| 脚本 | 作用 |
|---|---|
| `download.sh` | 下载底包和 ColorOS |
| `unpack.sh` | 解包 payload/super/EROFS |
| `analyze-kernel.sh` | 分析内核配置，确定 EROFS/LZ4 能力 |
| `integrate-root.sh` | 集成 KernelSU Next，失败回退原版 |
| `build-kernel.sh` | 编译内核，失败自动回退 |
| `merge-partitions.sh` | 合并 my 分区、补 system_ext |
| `debloat.sh` | 按开关删除指定 APP |
| `replace-apps.sh` | 替换默认应用 |
| `system-fixes.sh` | 系统级修复 |
| `apply-patches.sh` | 机型补丁 |
| `fix-fstab.sh` | 清理 AVB |
| `pack.sh` | 打包成 zip 或 super.img |
| `verify.sh` | 验证镜像合法性 |
| `analyze-and-fix.sh` | 日志分析 + 自动修复 |
| `rollback-fix.sh` | 回滚修复 |
| `upload-pan123.sh` | 上传到 123 网盘 |
| `upload-r2.sh` | 上传到 Cloudflare R2 |
| `upload-alist.sh` | 上传到 Alist |

---

## ❓ 常见问题

### Q: 没配 Secrets 会怎样？

勾选了对应上传方式但没配 Secrets，脚本会输出提示并跳过，不会报错。

### Q: 输入项和 Secrets 哪个优先？

**输入项优先**。输入项填了就用输入项，留空则回退到 Secrets。

### Q: 输入项安全吗？

**不安全**。输入项会记录在 Actions 运行日志里，公开仓库建议用 Secrets。

### Q: 编译内核需要多久？

4.14 内核首次编译约 20-40 分钟。工作流超时设为 300 分钟。

### Q: 没提供内核源码能集成 Root 吗？

不能。Root 集成必须有内核源码，没源码时自动跳过。

### Q: 挖孔坐标填错了会怎样？

流体云位置会偏，但不影响开机。用开发者选项「指针位置」实测。

### Q: 精简了输入法会怎样？

**开机后无法输入**。强烈建议保持 `debloat_ime` 为 `false`。

### Q: 上传到 123 网盘失败怎么办？

检查：
1. `PAN123_CLIENT_ID` 和 `PAN123_CLIENT_SECRET` 是否正确
2. 123 账号是否已实名认证
3. 日志里有没有 `signature error`

### Q: 怎么切换上传到 Release？

在 Actions 里勾 `upload_release`，取消 `upload_pan123` 即可。Release 无需配置。

---

## 📄 许可证

仅供学习交流，请勿用于商业用途。移植 ROM 的版权归原厂商所有。