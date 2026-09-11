# xiaomi-port-coloros

小米 → ColorOS 16 移植工作流。

## 快速开始

1. Fork 本仓库
2. 进入 Actions → Port ColorOS 16 → Run workflow
3. 填写底包直链、ColorOS 直链，勾选精简/替换/机型配置
4. 跑完后在 123 网盘下载产物

## 上传方式

默认上传到 123 网盘，需配置 Secrets：

- `PAN123_CLIENT_ID`
- `PAN123_CLIENT_SECRET`

## 脚本说明

| 脚本 | 作用 |
|---|---|
| download.sh | 下载底包和 ColorOS |
| unpack.sh | 解包 payload/super/EROFS |
| analyze-kernel.sh | 分析内核配置 |
| integrate-root.sh | 集成 KernelSU Next |
| build-kernel.sh | 编译内核 |
| merge-partitions.sh | 合并分区 |
| debloat.sh | 精简 APP |
| replace-apps.sh | 替换默认应用 |
| system-fixes.sh | 系统级修复 |
| apply-patches.sh | 机型补丁 |
| fix-fstab.sh | 清理 AVB |
| pack.sh | 打包 |
| verify.sh | 验证镜像 |
| analyze-and-fix.sh | 日志分析+自动修复 |
| rollback-fix.sh | 回滚 |
| upload-pan123.sh | 上传 123 网盘 |
| upload-r2.sh | 上传 R2 |
| upload-alist.sh | 上传 Alist |