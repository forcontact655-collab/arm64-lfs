#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --disable-static"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qtdeps1-report.txt
PROGRESS=/root/blfs-qtdeps1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/cmake ]]
[[ -d /sources ]]
pkg-config --exists xcb x11 icu-uc egl gl
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
  printf 'BLFS_QTDEPS1_BUILT=%s\n' "$PACKAGE_DIR" >>"$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}

for archive in \
  xcb-util-0.4.1.tar.xz \
  xcb-util-image-0.4.1.tar.xz \
  xcb-util-keysyms-0.4.1.tar.xz \
  xcb-util-renderutil-0.3.10.tar.xz \
  xcb-util-wm-0.4.2.tar.xz \
  xcb-util-cursor-0.1.5.tar.xz
do
  packagedir="${archive%.tar.?z*}"
  printf 'BUILD_BLFS_QTDEPS1=%s\n' "$packagedir"
  extract "$archive"
  ./configure $XORG_CONFIG --docdir="/usr/share/doc/$packagedir"
  make
  make install
  finish_package
done

printf 'BUILD_BLFS_QTDEPS1=double-conversion\n'
extract double-conversion-3.3.1.tar.gz
mkdir build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr        \
      -D CMAKE_INSTALL_LIBDIR=lib         \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_SHARED_LIBS=ON             \
      -D BUILD_TESTING=ON                 \
      ..
make
make test
make install
finish_package

[[ "$(grep -c '^BLFS_QTDEPS1_BUILT=' "$PROGRESS")" -eq 7 ]]
pkg-config --exists xcb-util xcb-image xcb-keysyms xcb-renderutil \
  xcb-ewmh xcb-icccm xcb-cursor
[[ -f /usr/include/double-conversion/double-conversion.h ]]
[[ -f /usr/lib/cmake/double-conversion/double-conversionConfig.cmake ]]

cat >/tmp/blfs-qtdeps1-smoke.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(void) {
  const char *libraries[] = {
    "libxcb-util.so",
    "libxcb-image.so",
    "libxcb-keysyms.so",
    "libxcb-render-util.so",
    "libxcb-ewmh.so",
    "libxcb-icccm.so",
    "libxcb-cursor.so",
    "libdouble-conversion.so"
  };
  const unsigned long count = sizeof(libraries) / sizeof(libraries[0]);
  for (unsigned long i = 0; i < count; ++i) {
    void *handle = dlopen(libraries[i], RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
      fprintf(stderr, "%s\n", dlerror());
      return (int)i + 1;
    }
    dlclose(handle);
  }
  puts("BLFS_QTDEPS1_EXEC_OK");
  return 0;
}
EOF
gcc /tmp/blfs-qtdeps1-smoke.c -o /tmp/blfs-qtdeps1-smoke -ldl
OUTPUT="$(/tmp/blfs-qtdeps1-smoke)"
[[ "$OUTPUT" == BLFS_QTDEPS1_EXEC_OK ]]
readelf -h /tmp/blfs-qtdeps1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qtdeps1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_QTDEPS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=7\n'
  printf 'XCB_PACKAGES=6\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'ICU_EXISTING=%s\n' "$(pkg-config --modversion icu-uc)"
  printf 'MESA_EXISTING=%s\n' "$(pkg-config --modversion egl)"
  printf 'DOUBLE_CONVERSION_ARCHIVE=3.3.1\n'
  printf 'BOOTABLE=no\n'
  printf 'QT=absent\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-qtdeps1-smoke /tmp/blfs-qtdeps1-smoke.c
