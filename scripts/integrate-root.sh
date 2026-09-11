#!/bin/bash
set -e
cd work

[ "${ENABLE_ROOT:-true}" != "true" ] && exit 0
[ -z "${KERNEL_SOURCE_REPO:-}" ] || [ ! -d "kernel_src" ] && {
  echo "ROOT_INTEGRATED=false" >> "$GITHUB_ENV"
  exit 0
}

cd kernel_src
KERNEL_VERSION=$(make -s kernelversion 2>/dev/null | cut -d. -f1,2 || echo "unknown")
echo ">>> 内核版本: $KERNEL_VERSION"

# ============================================================
# 手动打补丁（4.14 / 4.19）
# ============================================================
apply_manual_patches() {
  local ksu_dir=$1

  # 补丁 1：fs/exec.c
  if ! grep -q "ksu_handle_execve" fs/exec.c 2>/dev/null; then
    python3 -c "
import re
with open('fs/exec.c') as f: c=f.read()
c=re.sub(r'(static int do_execveat_common\(int fd, struct filename \*filename,\s*struct user_arg_ptr argv,\s*struct user_arg_ptr envp,\s*int flags\)\s*\{)', r'''\1
#ifdef CONFIG_KSU
	ksu_handle_execve(filename, argv, envp);
#endif
''', c)
with open('fs/exec.c','w') as f: f.write(c)
"
  fi

  # 补丁 2：fs/open.c
  if ! grep -q "ksu_handle_faccessat" fs/open.c 2>/dev/null; then
    python3 -c "
import re
with open('fs/open.c') as f: c=f.read()
c=re.sub(r'(SYSCALL_DEFINE3\(faccessat, int, dfd, const char __user \*, filename, int, mode\)\s*\{)', r'''\1
#ifdef CONFIG_KSU
	ksu_handle_faccessat(dfd, filename, mode);
#endif
''', c)
with open('fs/open.c','w') as f: f.write(c)
"
  fi

  # 补丁 3：fs/read_write.c
  if ! grep -q "ksu_handle_vfs_read" fs/read_write.c 2>/dev/null; then
    python3 -c "
import re
with open('fs/read_write.c') as f: c=f.read()
c=re.sub(r'(ssize_t vfs_read\(struct file \*file, char __user \*buf, size_t count, loff_t \*pos\)\s*\{)', r'''\1
#ifdef CONFIG_KSU
	if (ksu_handle_vfs_read(file, buf, count, pos))
		return -EACCES;
#endif
''', c)
with open('fs/read_write.c','w') as f: f.write(c)
"
  fi

  # 补丁 4：fs/stat.c
  if ! grep -q "ksu_handle_vfs_stat" fs/stat.c 2>/dev/null; then
    python3 -c "
import re
with open('fs/stat.c') as f: c=f.read()
c=re.sub(r'(int vfs_fstatat\(int dfd, const char __user \*filename, struct kstat \*stat, int flags\)\s*\{)', r'''\1
#ifdef CONFIG_KSU
	ksu_handle_vfs_stat(dfd, filename, stat, flags);
#endif
''', c)
with open('fs/stat.c','w') as f: f.write(c)
"
  fi

  # 补丁 5：include/linux/sched.h
  if ! grep -q "ksu_flags" include/linux/sched.h 2>/dev/null; then
    python3 -c "
import re
with open('include/linux/sched.h') as f: c=f.read()
c=re.sub(r'(struct task_struct \{.*?)(\n\s*struct mm_struct \*mm;)', r'''\1
#ifdef CONFIG_KSU
	u32 ksu_flags;
#endif\2''', c, flags=re.DOTALL)
with open('include/linux/sched.h','w') as f: f.write(c)
"
  fi
}

# ============================================================
# 接入 Kbuild
# ============================================================
setup_kbuild() {
  local ksu_dir=$1
  grep -q "$ksu_dir" drivers/Makefile 2>/dev/null || \
    echo "obj-\$(CONFIG_KSU) += ${ksu_dir}/kernel/" >> drivers/Makefile
  grep -q "$ksu_dir" drivers/Kconfig 2>/dev/null || \
    echo "source \"drivers/${ksu_dir}/Kconfig\"" >> drivers/Kconfig
  cp "${ksu_dir}/kernel/Kconfig" "drivers/${ksu_dir}/Kconfig" 2>/dev/null || true
}

# ============================================================
# 写入 defconfig
# ============================================================
write_defconfig() {
  local p="arch/arm64/configs/${DEFCONFIG_NAME}"
  if [ -f "$p" ]; then
    sed -i '/CONFIG_KSU/d' "$p"
    printf "CONFIG_KSU=y\nCONFIG_KSU_DEBUG=n\nCONFIG_KSU_KPROBES_HOOK=n\n" >> "$p"
  fi
}

# ============================================================
# 方案一：KernelSU Next
# 支持分支参数，默认 next
# ============================================================
try_next() {
  local branch="${ROOT_VERSION:-next}"
  echo ">>> 使用 KernelSU Next (分支: $branch)"

  git clone --depth=1 --branch "$branch" \
    https://github.com/KernelSU-Next/KernelSU-Next.git KernelSU-Next 2>/dev/null || return 1

  [ -f "KernelSU-Next/kernel/ksu.c" ] || return 1
  setup_kbuild "KernelSU-Next"

  if [ "$KERNEL_VERSION" = "4.14" ] || [ "$KERNEL_VERSION" = "4.19" ]; then
    apply_manual_patches "KernelSU-Next" || return 1
  else
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/${branch}/kernel/setup.sh" | bash -s legacy 2>/dev/null || return 1
  fi

  write_defconfig
  return 0
}

# ============================================================
# 方案二：原版 KernelSU
# 4.14 / 4.19 锁 v0.9.5
# ============================================================
try_ksu() {
  local version="v0.9.5"
  echo ">>> 使用原版 KernelSU (版本: $version)"

  git clone --depth=1 --branch "$version" \
    https://github.com/tiann/KernelSU.git KernelSU 2>/dev/null || return 1

  [ -f "KernelSU/kernel/ksu.c" ] || return 1
  setup_kbuild "KernelSU"

  if [ "$KERNEL_VERSION" = "4.14" ] || [ "$KERNEL_VERSION" = "4.19" ]; then
    apply_manual_patches "KernelSU" || return 1
  else
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s "$version" 2>/dev/null || return 1
  fi

  write_defconfig
  return 0
}

# ============================================================
# 主流程
# ============================================================
INTEGRATED=false

if [ "${ROOT_TYPE:-kernelsu-next}" = "kernelsu" ]; then
  try_ksu && INTEGRATED=true
else
  if try_next; then
    INTEGRATED=true
  else
    echo ">>> Next 失败，回退原版"
    try_ksu && INTEGRATED=true && echo "ROOT_FALLBACK=true" >> "$GITHUB_ENV"
  fi
fi

if [ "$INTEGRATED" = "true" ]; then
  echo "ROOT_INTEGRATED=true" >> "$GITHUB_ENV"
else
  echo "ROOT_INTEGRATED=false" >> "$GITHUB_ENV"
  echo "ROOT_FAILED=true" >> "$GITHUB_ENV"
fi