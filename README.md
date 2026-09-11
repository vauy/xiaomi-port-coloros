# xiaomi-port-coloros

小米 → ColorOS / GSI 半自动移植工作流。

基于 GitHub Actions，把「下载、解包、内核分析、Root 集成、编译、精简、替换、修复、打包、验证、上传」串成一条流水线。

---

## 📋 目录

- [快速开始](#快速开始)
- [仓库结构](#仓库结构)
- [三个工作流](#三个工作流)
- [配置文件](#配置文件)
- [精简 APP 对照表](#精简-app-对照表)
- [替换应用对照表](#替换应用对照表)
- [系统级修复开关](#系统级修复开关)
- [机型专属配置](#机型专属配置)
- [上传方式](#上传方式)
- [内核 Root 集成](#内核-root-集成)
- [MTK BPF 补丁](#mtk-bpf-补丁)
- [内核编译失败排查](#内核编译失败排查)
- [脚本说明](#脚本说明)
- [常见问题](#常见问题)

---

## 🚀 快速开始

1. Fork 本仓库到你的 GitHub 账号
2. 编辑 `.github/workflows/port-config.yml`（或 `patch-gsi-config.yml`、`build-gsi-config.yml`），按需修改开关
3. 进入 **Actions** → 选择工作流 → **Run workflow**
4. 填写必填项（底包、ColorOS 包、内核源码、设备树等）
5. 跑完后在 123 网盘或 Artifact 下载产物

---

## 📁 仓库结构

```
xiaomi-port-coloros/
├── .github/workflows/
│   ├── README.md                  # 工作流说明
│   ├── port.yml                   # ColorOS 完整移植
│   ├── port-config.yml            # 移植配置
│   ├── patch-gsi.yml              # 修补现成 GSI
│   ├── patch-gsi-config.yml       # 修补配置
│   ├── build-gsi.yml              # 构建专属 GSI
│   └── build-gsi-config.yml       # 构建配置
├── scripts/
│   ├── download.sh
│   ├── unpack.sh
│   ├── analyze-kernel.sh
│   ├── integrate-root.sh
│   ├── build-kernel.sh
│   ├── merge-partitions.sh
│   ├── debloat.sh
│   ├── replace-apps.sh
│   ├── system-fixes.sh
│   ├── apply-patches.sh
│   ├── fix-fstab.sh
│   ├── pack.sh
│   ├── verify.sh
│   ├── analyze-and-fix.sh
│   ├── rollback-fix.sh
│   ├── patch-gsi.sh
│   ├── build-gsi.sh
│   ├── patch-bpf.sh
│   ├── upload-pan123.sh
│   ├── upload-r2.sh
│   └── upload-alist.sh
└── README.md
```

---

## ⚙️ 三个工作流

| 工作流 | 用途 | 编译内核 | 注入设备树 | 耗时 |
|---|---|---|---|---|
| `port.yml` | ColorOS 完整移植 | ✅ 可选 | ❌ | 60-120 分钟 |
| `patch-gsi.yml` | 修补现成 GSI | ❌ | ✅ | 5-15 分钟 |
| `build-gsi.yml` | 构建专属 GSI | ✅ | ✅ | 40-80 分钟 |

### 推荐使用顺序

1. **`patch-gsi.yml`**：快速验证硬件兼容性
2. **`build-gsi.yml`**：构建专属 GSI，适配度更高
3. **`port.yml`**：完整的 ColorOS 移植

---

## 📝 配置文件

所有可选配置集中在 `config.yml` 里，改完提交即可，不用在 Actions 界面里勾。

| 工作流 | 配置文件 |
|---|---|
| `port.yml` | `.github/workflows/port-config.yml` |
| `patch-gsi.yml` | `.github/workflows/patch-gsi-config.yml` |
| `build-gsi.yml` | `.github/workflows/build-gsi-config.yml` |

### 变量对照

| config 路径 | 环境变量 |
|---|---|
| `device.model` | `CFG_DEVICE_MODEL` |
| `device.system_name` | `CFG_DEVICE_SYSTEM_NAME` |
| `device.partition_type` | `CFG_DEVICE_PARTITION_TYPE` |
| `root.enable` | `CFG_ROOT_ENABLE` |
| `kernel_patch.enable_bpf` | `CFG_KERNEL_PATCH_ENABLE_BPF` |
| `debloat.ad` | `CFG_DEBLOAT_AD` |
| `fix.openid` | `CFG_FIX_OPENID` |
| `gsi_inject.features` | `CFG_GSI_INJECT_FEATURES` |
| `gsi_output.format` | `CFG_GSI_OUTPUT_FORMAT` |
| `upload.pan123` | `CFG_UPLOAD_PAN123` |

---

## 📦 精简 APP 对照表

| config 开关 | 包名 | APP 名称 | 风险 |
|---|---|---|---|
| `debloat.ad` | `com.oplus.ad` | 广告服务 | 低 |
| `debloat.app_market` | `com.heytap.market` | OPPO 软件商店 | 低 |
| `debloat.game_center` | `com.oplus.gamecenter` | 游戏中心 | 低 |
| `debloat.browser` | `com.heytap.browser` | ColorOS 浏览器 | 低 |
| `debloat.content_ext` | `com.oplus.content` | 内容推荐服务 | 低 |
| `debloat.theme_store` | `com.heytap.themestore` | 主题商店 | 低 |
| `debloat.voice_assistant` | `com.oplus.voiceassistant` | 小布语音助手 | 低 |
| `debloat.music` | `com.oplus.music` | ColorOS 音乐 | 低 |
| `debloat.video` | `com.oplus.video` | ColorOS 视频 | 低 |
| `debloat.feedback` | `com.oplus.feedback` | 用户反馈 | 低 |
| `debloat.ota` | `com.oplus.ota` | OTA 更新服务 | 中 |
| `debloat.push` | `com.oplus.push` | OPPO 推送服务 | 中 |
| `debloat.wallpaper` | `com.oplus.wallpaper` | 动态壁纸 | 中 |
| `debloat.gallery` | `com.oplus.gallery` | 相册 | 中 |
| `debloat.cloud` | `com.oplus.cloud` | 云服务 | 高 |
| `debloat.account` | `com.oplus.account` | 账号服务 | 高 |
| `debloat.ime` | `com.oplus.ime` | 自带输入法 | 极高 |
| `debloat.camera` | `com.oplus.camera` | 相机 | 极高 |

---

## 🔄 替换应用对照表

| config 开关 | 原包名 | 原 APP | 替换包名 | 替换 APP | 风险 |
|---|---|---|---|---|---|
| `replace.browser` | `com.heytap.browser` | ColorOS 浏览器 | `mark.via` | Via | 低 |
| `replace.gallery` | `com.oplus.gallery` | ColorOS 相册 | `com.simplemobiletools.gallery.pro` | Simple Gallery | 中 |
| `replace.file_manager` | `com.oplus.filemanager` | ColorOS 文件管理 | `me.zhanghai.android.files` | Material Files | 低 |

---

## 🩹 系统级修复开关

| config 开关 | 修复问题 | 根因 | 风险 |
|---|---|---|---|
| `fix.openid` | OpenID/OUID 卡顿 | 缺 OPlus 序列号属性 | 低 |
| `fix.selinux` | SELinux 拒绝 | sepolicy 不匹配 | 中 |
| `fix.audio` | 音频炸裂 | 音频策略不兼容 | 低 |
| `fix.vibrator` | 振动异常 | 权限段不匹配 | 低 |
| `fix.hdr` | 抖音卡顿 | HDR 特性冲突 | 低 |
| `fix.wechat_scan` | 微信扫一扫 | 相机优化冲突 | 低 |
| `fix.wallpaper` | 实况壁纸黑屏 | 壁纸服务不兼容 | 中 |
| `fix.color_temp` | 屏幕色温异常 | 色温曲线不匹配 | 低 |
| `fix.nfc` | NFC 不可用 | NFC 配置不匹配 | 中 |
| `fix.modem` | 信号丢失 | modem 配置不匹配 | 高 |

---

## 📱 机型专属配置

| config 路径 | 说明 | 示例 |
|---|---|---|
| `device.model` | 机型代号 | `cannon` |
| `device.system_name` | 系统名 | `ColorOS` |
| `device.punch_hole_position` | 挖孔坐标 | `505,29:575,99` |
| `device.soc_model` | 芯片平台 | `mt6853` |
| `device.serial_no` | 序列号 | 空 |

### 挖孔坐标怎么测

1. 开发者选项 → **指针位置**
2. 手指点在挖孔左上角和右下角
3. 记录两组坐标，格式：`左x,上y:右x,下y`

---

## 📤 上传方式

在 `config.yml` 里配置：

| config 开关 | 说明 | 需要 Secrets | 单文件限制 |
|---|---|---|---|
| `upload.pan123` | 123 网盘（默认） | ✅ | 100GB+ |
| `upload.release` | GitHub Release | ❌ | ≤2GB |
| `upload.r2` | Cloudflare R2 | ✅ | 无限制 |
| `upload.alist` | Alist | ✅ | 取决于后端 |
| `upload.artifact` | GitHub Artifact | ❌ | 7 天过期 |

### 123 网盘配置

1. 登录 [123 云盘开放平台](https://www.123pan.com/open/)
2. 创建应用，获取 **Client ID** 和 **Client Secret**
3. 在仓库 **Settings → Secrets → Actions** 配置：
   - `PAN123_CLIENT_ID`
   - `PAN123_CLIENT_SECRET`

### 其他网盘 Secrets

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

| 内核版本 | 集成方式 |
|---|---|
| 4.14 / 4.19 | 手动打 5 个补丁 |
| 5.10+ GKI | 自动集成 |

### 回退机制

KernelSU Next 失败 → 自动回退原版 KernelSU（4.14/4.19 锁 `v0.9.5`）。

### 4.14 手动补丁

| 补丁 | 文件 | 作用 |
|---|---|---|
| 1 | `fs/exec.c` | 拦截进程执行 |
| 2 | `fs/open.c` | 拦截文件访问权限 |
| 3 | `fs/read_write.c` | 拦截文件读取 |
| 4 | `fs/stat.c` | 拦截文件状态查询 |
| 5 | `include/linux/sched.h` | 加 `ksu_flags` 字段 |

---

## 🔧 MTK BPF 补丁

MTK 在 4.14 内核里引入的一个 BPF 提交有缺陷，会导致 Android 12+ 网络问题。

工作流自动应用 `mtk-bpf-patcher`，在编译内核后、打包前执行。

| config 开关 | 说明 |
|---|---|
| `kernel_patch.enable_bpf` | `true` 时自动打补丁 |

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
| `analyze-kernel.sh` | 分析内核配置 |
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
| `patch-gsi.sh` | 修补 GSI |
| `build-gsi.sh` | 构建 GSI |
| `patch-bpf.sh` | MTK BPF 补丁 |
| `upload-pan123.sh` | 上传到 123 网盘 |
| `upload-r2.sh` | 上传到 Cloudflare R2 |
| `upload-alist.sh` | 上传到 Alist |

---

## ❓ 常见问题

### Q: 没配 Secrets 会怎样？

勾选了对应上传方式但没配 Secrets，脚本会输出提示并跳过，不会报错。

### Q: 编译内核需要多久？

4.14 内核首次编译约 20-40 分钟。工作流超时设为 300 分钟。

### Q: 没提供内核源码能集成 Root 吗？

不能。Root 集成必须有内核源码，没源码时自动跳过。

### Q: 精简了输入法会怎样？

**开机后无法输入**。强烈建议保持 `debloat.ime` 为 `false`。

### Q: 怎么切换上传到 Release？

在 `config.yml` 里把 `upload.release` 改成 `true`，`upload.pan123` 改成 `false`。

### Q: MTK BPF 补丁失败会怎样？

自动回退到原内核，工作流不会中断，但 Android 12+ 可能出现网络问题。

### Q: 产物命名规则是什么？

```
<机型代号>-<系统名>-<安卓版本>-<日期>.<后缀>
```

示例：
```
cannon-ColorOS-A15-260912.zip
cannon-GSI-A15-260912-system.img
cannon-ColorOS-A15-260912-kernel-ksu-bpf.img
```

---

## 📄 许可证

仅供学习交流，请勿用于商业用途。移植 ROM 的版权归原厂商所有。