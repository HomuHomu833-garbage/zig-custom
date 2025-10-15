#!/bin/sh
set -eu

export ZIG_TARGET="$1"
ROOTDIR="$(pwd)"
TOOLCHAIN="$ROOTDIR/zig-as-llvm"
ZIG_VERSION="$ZIG_VERSION_NAME"
ZIG="$(whereis zig)"

TARGET_OS_AND_ABI=${TARGET#*-}
TARGET_OS_CMAKE=${TARGET_OS_AND_ABI%-*}
case $TARGET_OS_CMAKE in
  macos*) TARGET_OS_CMAKE="Darwin";;
  freebsd*) TARGET_OS_CMAKE="FreeBSD";;
  netbsd*) TARGET_OS_CMAKE="NetBSD";;
  windows*) TARGET_OS_CMAKE="Windows";;
  linux*) TARGET_OS_CMAKE="Linux";;
  native) TARGET_OS_CMAKE="";;
esac

git clone https://github.com/HomuHomu833/zig-as-llvm $TOOLCHAIN

mkdir -p "$ROOTDIR/out/build-zlib-$ZIG_TARGET"
cd "$ROOTDIR/out/build-zlib-$ZIG_TARGET"
cmake "$ROOTDIR/zlib" \
  -DCMAKE_INSTALL_PREFIX="$ROOTDIR/out/$ZIG_TARGET" \
  -DCMAKE_PREFIX_PATH="$ROOTDIR/out/$ZIG_TARGET" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$TARGET_OS_CMAKE" \
  -DCMAKE_C_COMPILER="$TOOLCHAIN/bin/cc" \
  -DCMAKE_CXX_COMPILER="$TOOLCHAIN/bin/c++" \
  -DCMAKE_C_FLAGS="-fno-sanitize=all -s -mcpu=baseline"
  -DCMAKE_CXX_FLAGS="-fno-sanitize=all -s -mcpu=baseline"
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER="$TOOLCHAIN/bin/rc" \
  -DCMAKE_AR="$TOOLCHAIN/bin/ar" \
  -DCMAKE_RANLIB="$TOOLCHAIN/bin/ranlib"
cmake --build . --target install

mkdir -p "$ROOTDIR/out/$ZIG_TARGET/lib"
cp "$ROOTDIR/zstd/lib/zstd.h" "$ROOTDIR/out/$ZIG_TARGET/include/zstd.h"
cd "$ROOTDIR/out/$ZIG_TARGET/lib"
$ZIG build-lib \
  --name zstd \
  -target $ZIG_TARGET \
  -mcpu=baseline
  -fstrip -OReleaseFast \
  -lc \
  $(find "$ROOTDIR/zstd/lib" -type f \( -name "*.c" -o -name "*.S" \))

mkdir -p "$ROOTDIR/out/build-llvm-$ZIG_TARGET"
cd "$ROOTDIR/out/build-llvm-$ZIG_TARGET"
cmake "$ROOTDIR/llvm" \
  -DCMAKE_INSTALL_PREFIX="$ROOTDIR/out/$ZIG_TARGET" \
  -DCMAKE_PREFIX_PATH="$ROOTDIR/out/$ZIG_TARGET" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$TARGET_OS_CMAKE" \
  -DCMAKE_C_COMPILER="$TOOLCHAIN/bin/cc" \
  -DCMAKE_CXX_COMPILER="$TOOLCHAIN/bin/c++" \
  -DCMAKE_ASM_COMPILER="$TOOLCHAIN/bin/c++" \
  -DCMAKE_C_FLAGS="-fno-sanitize=all -s -mcpu=baseline"
  -DCMAKE_CXX_FLAGS="-fno-sanitize=all -s -mcpu=baseline"
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER="$TOOLCHAIN/bin/rc" \
  -DCMAKE_AR="$TOOLCHAIN/bin/ar" \
  -DCMAKE_RANLIB="$TOOLCHAIN/bin/ranlib"
  -DLLVM_ENABLE_BACKTRACES=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_ZLIB=FORCE_ON \
  -DLLVM_ENABLE_ZSTD=FORCE_ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -DLLVM_DEFAULT_TARGET_TRIPLE="$ZIG_TARGET"
cmake --build . --target install

cd "$ROOTDIR/zig"
$ZIG build \
  --prefix "$ROOTDIR/out/zig-$ZIG_TARGET" \
  --search-prefix "$ROOTDIR/out/$ZIG_TARGET" \
  -Dflat \
  -Dstatic-llvm \
  -Doptimize=ReleaseFast \
  -Dstrip \
  -Dtarget="$ZIG_TARGET" \
  -Dcpu="baseline" \
  -Dversion-string="$ZIG_VERSION"
