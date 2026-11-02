#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-graphics1-report.txt
PROGRESS=/root/blfs-graphics1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -d /sources ]]
pkg-config --exists fontconfig wayland-client xkbcommon xkbcommon-x11
: >"$PROGRESS"
extract() {
  local archive="$1" first
  set +o pipefail
  first="$(tar -tf "$SOURCES/$archive" | head -n1)"
  set -o pipefail
  PACKAGE_DIR="${first%%/*}"
  PACKAGE_DIR="${PACKAGE_DIR#./}"
  [[ "$PACKAGE_DIR" =~ ^[A-Za-z0-9._+-]+$ ]]
  rm -rf "$SOURCES/$PACKAGE_DIR"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$PACKAGE_DIR"
}
finish_package() {
  cd /sources
  rm -rf "$PACKAGE_DIR"
  printf 'BLFS_GRAPHICS1_BUILT=%s\n' "$PACKAGE_DIR" >>"$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}

printf 'BUILD_BLFS_GRAPHICS1=libyaml\n'
extract yaml-0.2.5.tar.gz
./configure --prefix=/usr --disable-static
make
make install
finish_package

printf 'BUILD_BLFS_GRAPHICS1=cython\n'
extract cython-3.1.3.tar.gz
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$PWD"
pip3 install --no-index --find-links dist --no-user Cython
finish_package

printf 'BUILD_BLFS_GRAPHICS1=pyyaml\n'
extract pyyaml-6.0.2.tar.gz
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$PWD"
pip3 install --no-index --find-links dist --no-user PyYAML
finish_package

printf 'BUILD_BLFS_GRAPHICS1=mako\n'
extract mako-1.3.10.tar.gz
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$PWD"
pip3 install --no-index --find-links dist --no-user Mako
finish_package

printf 'BUILD_BLFS_GRAPHICS1=libdrm\n'
extract libdrm-2.4.125.tar.xz
mkdir build
cd build
meson setup --prefix=/usr       \
            --libdir=lib        \
            --buildtype=release \
            -D udev=true        \
            -D valgrind=disabled \
            ..
ninja
ninja install
finish_package

printf 'BUILD_BLFS_GRAPHICS1=llvm-and-clang\n'
extract llvm-20.1.8.src.tar.xz
tar -xf /sources/llvm-cmake-20.1.8.src.tar.xz
tar -xf /sources/llvm-third-party-20.1.8.src.tar.xz
sed '/LLVM_COMMON_CMAKE_UTILS/s@../cmake@cmake-20.1.8.src@' \
    -i CMakeLists.txt
sed '/LLVM_THIRD_PARTY_DIR/s@../third-party@third-party-20.1.8.src@' \
    -i cmake/modules/HandleLLVMOptions.cmake
tar -xf /sources/clang-20.1.8.src.tar.xz -C tools
mv tools/clang-20.1.8.src tools/clang
grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/'
sed 's/utility/tool/' -i utils/FileCheck/CMakeLists.txt
mkdir -v build
cd build
CC=gcc CXX=g++                               \
cmake -D CMAKE_INSTALL_PREFIX=/usr           \
      -D CMAKE_SKIP_INSTALL_RPATH=ON         \
      -D LLVM_ENABLE_FFI=ON                  \
      -D CMAKE_BUILD_TYPE=Release            \
      -D LLVM_BUILD_LLVM_DYLIB=ON            \
      -D LLVM_LINK_LLVM_DYLIB=ON             \
      -D LLVM_ENABLE_RTTI=ON                 \
      -D LLVM_TARGETS_TO_BUILD="host;AMDGPU" \
      -D LLVM_BINUTILS_INCDIR=/usr/include   \
      -D LLVM_INCLUDE_BENCHMARKS=OFF         \
      -D CLANG_DEFAULT_PIE_ON_LINUX=ON       \
      -D CLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang \
      -W no-dev -G Ninja ..
ninja
ninja install
finish_package

[[ "$(grep -c '^BLFS_GRAPHICS1_BUILT=' "$PROGRESS")" -eq 6 ]]
pkg-config --exists yaml-0.1 libdrm
python3 - <<'PY'
import Cython
import mako
import yaml
assert yaml.__with_libyaml__
assert Cython.__version__ == '3.1.3'
assert mako.__version__ == '1.3.10'
assert yaml.__version__ == '6.0.2'
print('GRAPHICS1_PYTHON_MODULES=ok')
PY
cat >/tmp/blfs-graphics1-smoke.c <<'EOF'
#include <stdio.h>
int main(void) {
  puts("BLFS_GRAPHICS1_EXEC_OK");
  return 0;
}
EOF
clang /tmp/blfs-graphics1-smoke.c -o /tmp/blfs-graphics1-smoke
OUTPUT="$(/tmp/blfs-graphics1-smoke)"
[[ "$OUTPUT" == BLFS_GRAPHICS1_EXEC_OK ]]
readelf -h /tmp/blfs-graphics1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-graphics1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_GRAPHICS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=6\n'
  printf 'SOURCE_ARCHIVES=9\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'LIBDRM=%s\n' "$(pkg-config --modversion libdrm)"
  printf 'LLVM=%s\n' "$(llvm-config --version)"
  printf 'CLANG=%s\n' "$(clang --version | sed -n '1p')"
  printf 'PYYAML_LIBYAML=yes\n'
  printf 'BOOTABLE=no\n'
  printf 'MESA=absent\n'
  printf 'QT=absent\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-graphics1-smoke /tmp/blfs-graphics1-smoke.c
