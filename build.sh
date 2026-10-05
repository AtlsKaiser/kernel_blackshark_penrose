#!/bin/bash
# ============================================
# 黑鲨4 (penrose) 内核编译脚本
# Clang + LLD + KernelSU(backslashxx)
# 用法:
#   ./build.sh          # 增量编译
#   ./build.sh clean    # 清 out 全新编
# ============================================

set -e

# ---------- 0. 参数 ----------
if [ "$1" = "clean" ]; then
    echo ">>> 清理 out/"
    rm -rf out/
    mkdir out
fi

# ---------- 1. 环境变量 ----------
export PATH="$HOME/ZyC-Clang/bin:$PATH"

export ARCH=arm64
export SUBARCH=arm
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export LD=/usr/bin/ld.lld
export O=out

FLGS="--target=aarch64-linux-gnu \
      -Wno-implicit-function-declaration \
      -Wno-unused-but-set-variable \
      -Wno-unused-variable \
      -Wno-unused-function \
      -Wno-unused-label \
      -Wno-incompatible-pointer-types \
      -Wno-strict-prototypes \
      -Wno-implicit-int \
      -Wno-enum-conversion \
      -Wno-void-pointer-to-int-cast \
      -Wno-pointer-to-int-cast \
      -Wno-int-conversion \
      -Wno-implicit-fallthrough \
      -Wno-shift-negative-value \
      -Wno-deprecated-declarations \
      -Wno-missing-prototypes \
      -Wno-format \
      -Wno-constant-conversion"

# ---------- 2. 拉 KernelSU（只拉一次） ----------
if [ ! -d "drivers/kernelsu" ]; then
    echo ">>> 拉取 backslashxx KernelSU..."
    curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/master/kernel/setup.sh" | bash -s master
else
    echo ">>> KernelSU 已存在，跳过"
fi

# ---------- 3. 确认 defconfig 配置 ----------
DEFCONFIG="arch/arm64/configs/penrose_defconfig"

if ! grep -q "^CONFIG_KSU=y" "$DEFCONFIG"; then
    echo ">>> 写入 CONFIG_KSU=y"
    [ -n "$(tail -c 1 "$DEFCONFIG")" ] && echo "" >> "$DEFCONFIG"
    echo "CONFIG_KSU=y" >> "$DEFCONFIG"
fi

if ! grep -q "^CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y" "$DEFCONFIG"; then
    echo ">>> 写入 CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y"
    [ -n "$(tail -c 1 "$DEFCONFIG")" ] && echo "" >> "$DEFCONFIG"
    echo "CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y" >> "$DEFCONFIG"
fi

# ---------- 4. 生成 .config ----------
echo ">>> 生成 penrose_defconfig"
make -j$(nproc --all) O=out \
      CC="clang" \
      LD=ld.lld \
      CLANG_TRIPLE=aarch64-linux-gnu- \
      CROSS_COMPILE=aarch64-linux-gnu- \
      CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
      LLVM_IAS=1 \
      penrose_defconfig

# ---------- 5. 编译 ----------
echo ">>> 开始编译 Image.gz + dtbs"
make -j$(nproc --all) O=out \
      CC="clang" \
      LD=ld.lld \
      CLANG_TRIPLE=aarch64-linux-gnu- \
      CROSS_COMPILE=aarch64-linux-gnu- \
      CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
      LLVM_IAS=1 \
      KCFLAGS="$FLGS" \
      WERROR=0 \
      Image.gz dtbs 2>&1 | tee build_kernel.log

# ---------- 6. 结果 ----------
echo ""
echo "===== 编译完成 ====="
ls -lh out/arch/arm64/boot/Image.gz 2>/dev/null && echo "Image.gz OK"
echo ""
echo "penrose dtbo:"
find out -name "penrose*.dtbo" 2>/dev/null
echo ""