#!/bin/sh
set -eu

TARGET="$1"
MCPU="$2"
ROOTDIR="$(pwd)"
ZIG_VERSION="$ZIG_VERSION_NAME"
ZIG="/usr/local/bin/zig"

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

mkdir -p "$ROOTDIR/out/build-zlib-$TARGET-$MCPU"
cd "$ROOTDIR/out/build-zlib-$TARGET-$MCPU"
cmake "$ROOTDIR/zlib" \
  -DCMAKE_INSTALL_PREFIX="$ROOTDIR/out/$TARGET-$MCPU" \
  -DCMAKE_PREFIX_PATH="$ROOTDIR/out/$TARGET-$MCPU" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$TARGET_OS_CMAKE" \
  -DCMAKE_C_COMPILER="$ZIG;cc;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_ASM_COMPILER="$ZIG;cc;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER="$ROOTDIR/out/host/bin/llvm-rc" \
  -DCMAKE_AR="$ROOTDIR/out/host/bin/llvm-ar" \
  -DCMAKE_RANLIB="$ROOTDIR/out/host/bin/llvm-ranlib"
cmake --build . --target install

mkdir -p "$ROOTDIR/out/$TARGET-$MCPU/lib"
cp "$ROOTDIR/zstd/lib/zstd.h" "$ROOTDIR/out/$TARGET-$MCPU/include/zstd.h"
cd "$ROOTDIR/out/$TARGET-$MCPU/lib"
$ZIG build-lib \
  --name zstd \
  -target $TARGET \
  -mcpu=$MCPU \
  -fstrip -OReleaseFast \
  -lc \
  $(find "$ROOTDIR/zstd/lib" -type f \( -name "*.c" -o -name "*.S" \))

mkdir -p "$ROOTDIR/out/build-llvm-$TARGET-$MCPU"
cd "$ROOTDIR/out/build-llvm-$TARGET-$MCPU"
cmake "$ROOTDIR/llvm" \
  -DCMAKE_INSTALL_PREFIX="$ROOTDIR/out/$TARGET-$MCPU" \
  -DCMAKE_PREFIX_PATH="$ROOTDIR/out/$TARGET-$MCPU" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$TARGET_OS_CMAKE" \
  -DCMAKE_C_COMPILER="$ZIG;cc;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_ASM_COMPILER="$ZIG;cc;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER="$ROOTDIR/out/host/bin/llvm-rc" \
  -DCMAKE_AR="$ROOTDIR/out/host/bin/llvm-ar" \
  -DCMAKE_RANLIB="$ROOTDIR/out/host/bin/llvm-ranlib" \
  -DLLVM_ENABLE_BACKTRACES=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_ZLIB=FORCE_ON \
  -DLLVM_ENABLE_ZSTD=FORCE_ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -DLLVM_TABLEGEN="$ROOTDIR/out/host/bin/llvm-tblgen" \
  -DCLANG_TABLEGEN="$ROOTDIR/out/build-llvm-host/bin/clang-tblgen" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET"
cmake --build . --target install

cd "$ROOTDIR/zig"
$ZIG build \
  --prefix "$ROOTDIR/out/zig-$TARGET-$MCPU" \
  --search-prefix "$ROOTDIR/out/$TARGET-$MCPU" \
  -Dflat \
  -Dstatic-llvm \
  -Doptimize=ReleaseFast \
  -Dstrip \
  -Dtarget="$TARGET" \
  -Dcpu="$MCPU" \
  -Dversion-string="$ZIG_VERSION"
