# GitHub Actions 工作流说明

本目录包含三个工作流，分别对应不同的使用场景。

---

## 📋 工作流对比

| 工作流 | 用途 | 编译内核 | 注入设备树 | 耗时 |
|---|---|---|---|---|
| `port.yml` | ColorOS 完整移植 | ✅ 可选 | ❌ | 60-120 分钟 |
| `patch-gsi.yml` | 修补现成 GSI | ❌ | ✅ | 5-15 分钟 |
| `build-gsi.yml` | 构建专属 GSI | ✅ | ✅ | 40-80 分钟 |

---

## 🎯 推荐使用顺序

### 第一步：`patch-gsi.yml`（快速验证）

**用途**：下载现成的 GSI 包，注入你机型的硬件配置，快速验证能不能开机。

**适合**：
- 第一次尝试 GSI
- 想快速验证硬件兼容性
- 不想等内核编译

**输入**：
- GSI 镜像直链
- 设备树仓库地址
- 内核源码地址（只读，不编译）

**产出**：
- `patched_system.img`
- `GSI-patch-a-only.zip` 或 `GSI-patch-a-b.zip`

---

### 第二步：`build-gsi.yml`（构建专属 GSI）

**用途**：编译你机型的内核，结合设备树配置，构建一个完全适配的 GSI。

**适合**：
- `patch-gsi.yml` 跑通后
- 想要更高的硬件适配度
- 需要定制内核（如集成 KernelSU）

**输入**：
- GSI 基础镜像直链
- 内核源码地址（会编译）
- 设备树仓库地址
- 分区类型（a-only / a-b）

**产出**：
- `patched_system.img`
- `GSI-build-a-only.zip` 或 `GSI-build-a-b.zip`

---

### 第三步：`port.yml`（ColorOS 完整移植）

**用途**：把 ColorOS 官方固件完整移植到你的机型，包含系统分区、精简、替换、修复等。

**适合**：
- 想要完整的 ColorOS 体验
- 不满足于 GSI 的通用性
- 有足够的调试时间

**输入**：
- MIUI/澎湃底包直链
- ColorOS 移植包直链
- 内核源码地址
- 各种精简/替换/修复开关

**产出**：
- `coloros16-port.zip`
- `super.img`

---

## 📥 通用输入说明

以下输入在三个工作流里都用到：

### 内核源码

| 输入 | 说明 | 示例 |
|---|---|---|
| `kernel_source_repo` | 内核源码仓库地址 | `https://github.com/vauy/android_kernel_xiaomi_cannon` |
| `kernel_branch` | 内核分支 | `lineage-20` |
| `defconfig_name` | defconfig 文件名 | `cannon_defconfig` |

### 设备树

| 输入 | 说明 | 示例 |
|---|---|---|
| `device_tree_repo` | 设备树仓库地址 | `https://github.com/xiaomi-mt6853-devs/android_device_xiaomi_cannon` |

### 分区类型

| 值 | 说明 |
|---|---|
| `a-only` | A-only 分区（你的 cannon） |
| `a-b` | A/B 分区 |

### 输出格式

| 值 | 说明 |
|---|---|
| `img` | 只输出 `system.img` |
| `zip` | 只输出卡刷包 |
| `both` | 两个都输出 |

---

## 📤 上传方式

三个工作流都支持以下上传方式：

| 方式 | 需要 Secrets | 说明 |
|---|---|---|
| 123 网盘 | `PAN123_CLIENT_ID`、`PAN123_CLIENT_SECRET` | 默认，推荐 |
| Cloudflare R2 | `R2_ACCESS_KEY` 等 4 个 | 大文件推荐 |
| Alist | `ALIST_URL` 等 3 个 | 需自建服务 |
| GitHub Release | 无 | 单文件 ≤2GB |
| GitHub Artifact | 无 | 7 天过期 |

---

## ⚠️ 常见问题

### Q: 三个工作流可以同时跑吗？

可以。它们是独立的，互不影响。但同一个仓库同时跑多个会排队。

### Q: 先跑哪个？

推荐顺序：
1. `patch-gsi.yml` - 快速验证
2. `build-gsi.yml` - 构建专属
3. `port.yml` - 完整移植

### Q: 没配 Secrets 会怎样？

勾选了上传方式但没配 Secrets，脚本会输出提示并跳过，不会报错。

### Q: GSI 和 ColorOS 移植包有什么区别？

- **GSI**：通用系统镜像，基于 AOSP 或第三方，适配度靠注入配置提升。
- **ColorOS 移植包**：完整的 ColorOS 系统，包含所有 OPPO 定制功能。

### Q: cannon 用哪个分区类型？

你的 Redmi Note 9 5G 是 **A-only**，选 `a-only`。

---

## 📚 相关文档

- 仓库根目录 `README.md`：完整使用说明
- `scripts/` 目录：所有脚本的源码
- `config/patches/` 目录：机型专属补丁

---

## 🔗 参考资源

- [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next)
- [Mystic GSI Updates](https://sourceforge.net/projects/mystic-gsi-updates/)
- [xiaomi-mt6853-devs](https://github.com/xiaomi-mt6853-devs)