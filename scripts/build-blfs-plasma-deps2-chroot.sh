#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma-deps2-report.txt
PROGRESS=/root/blfs-plasma-deps2-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/autoreconf ]]
[[ -f /opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake && -e /usr/lib/libboost_filesystem.so && -e /usr/lib/libnl-3.so && -e /usr/lib/libqalculate.so ]]
[[ ! -e /usr/include/utf8cpp && ! -e /usr/include/taglib && ! -e /usr/include/sass && ! -e /usr/bin/xdotool ]]
: >"$PROGRESS"
extract_package() {
  local archive="$1" expected="$2" first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
}

extract_package utfcpp-4.0.6.tar.gz utfcpp-4.0.6
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS2=utfcpp\n'
cmake -G Ninja -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release ..
ninja install
cd /sources; rm -rf utfcpp-4.0.6
printf 'BLFS_PLASMA_DEPS2_BUILT=utfcpp-4.0.6\n' >>"$PROGRESS"

extract_package taglib-2.1.1.tar.gz taglib-2.1.1
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS2=taglib\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_SHARED_LIBS=ON \
  -D BUILD_TESTING=OFF \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_BINDINGS=ON \
  -D CMAKE_PREFIX_PATH=/usr \
  -W no-dev ..
ninja
ninja install
cd /sources; rm -rf taglib-2.1.1
printf 'BLFS_PLASMA_DEPS2_BUILT=taglib-2.1.1\n' >>"$PROGRESS"

extract_package libsass-3.6.6.tar.gz libsass-3.6.6
printf 'BUILD_BLFS_PLASMA_DEPS2=libsass\n'
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
cd /sources; rm -rf libsass-3.6.6
printf 'BLFS_PLASMA_DEPS2_BUILT=libsass-3.6.6\n' >>"$PROGRESS"

extract_package sassc-3.6.2.tar.gz sassc-3.6.2
printf 'BUILD_BLFS_PLASMA_DEPS2=sassc\n'
autoreconf -fi
./configure --prefix=/usr
make
make install
cd /sources; rm -rf sassc-3.6.2
printf 'BLFS_PLASMA_DEPS2_BUILT=sassc-3.6.2\n' >>"$PROGRESS"

extract_package xdotool-3.20211022.1.tar.gz xdotool-3.20211022.1
printf 'BUILD_BLFS_PLASMA_DEPS2=xdotool\n'
make WITHOUT_RPATH_FIX=1
make PREFIX=/usr INSTALLMAN=/usr/share/man install
cd /sources; rm -rf xdotool-3.20211022.1
printf 'BLFS_PLASMA_DEPS2_BUILT=xdotool-3.20211022.1\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA_DEPS2_BUILT=' "$PROGRESS")" -eq 5 ]]
for path in \
  /usr/include/utf8cpp/utf8.h \
  /usr/include/taglib/tstring.h \
  /usr/lib/libtag.so \
  /usr/lib/libtag_c.so \
  /usr/include/sass.h \
  /usr/lib/libsass.so \
  /usr/bin/sassc \
  /usr/bin/xdotool \
  /usr/lib/libxdo.so; do [[ -e "$path" ]]; done

rm -rf /tmp/blfs-plasma-deps2-smoke /tmp/blfs-plasma-deps2-smoke-build /tmp/blfs-plasma-deps2-smoke-stderr.log
mkdir -p /tmp/blfs-plasma-deps2-smoke
cat >/tmp/blfs-plasma-deps2-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma_deps2_smoke LANGUAGES CXX)
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
find_path(UTFCPP_INCLUDE_DIR NAMES utf8.h PATH_SUFFIXES utf8cpp REQUIRED)
add_executable(blfs-plasma-deps2-smoke main.cpp)
target_include_directories(blfs-plasma-deps2-smoke PRIVATE "${UTFCPP_INCLUDE_DIR}")
target_link_libraries(blfs-plasma-deps2-smoke PRIVATE PkgConfig::TAGLIB)
EOF
cat >/tmp/blfs-plasma-deps2-smoke/main.cpp <<'EOF'
#include <taglib/tstring.h>
#include <utf8.h>
#include <cstdio>
#include <string>
int main() {
  const std::string input("native");
  if (!utf8::is_valid(input.begin(), input.end())) {
    std::fprintf(stderr, "UTFCPP_SMOKE_FAILED\n");
    return 1;
  }
  const TagLib::String tag("native");
  if (tag.to8Bit() != "native") {
    std::fprintf(stderr, "TAGLIB_SMOKE_FAILED\n");
    return 2;
  }
  std::printf("BLFS_PLASMA_DEPS2_EXEC_OK=utf=valid=tag=native\n");
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma-deps2-smoke -B /tmp/blfs-plasma-deps2-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/usr
ninja -C /tmp/blfs-plasma-deps2-smoke-build
set +e
OUTPUT="$(LD_LIBRARY_PATH=/usr/lib /tmp/blfs-plasma-deps2-smoke-build/blfs-plasma-deps2-smoke \
  2>/tmp/blfs-plasma-deps2-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma-deps2-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA_DEPS2_EXEC_OK=utf=valid=tag=native ]]
cat >/tmp/blfs-plasma-deps2-smoke/input.scss <<'EOF'
$color: #123456;
.native { color: $color; }
EOF
sassc /tmp/blfs-plasma-deps2-smoke/input.scss /tmp/blfs-plasma-deps2-smoke/output.css
grep -q '.native' /tmp/blfs-plasma-deps2-smoke/output.css
grep -q '#123456' /tmp/blfs-plasma-deps2-smoke/output.css
XDO_VERSION_OUTPUT="$(xdotool --version)"
[[ "$XDO_VERSION_OUTPUT" == *3.20211022.1* ]]
readelf -h /tmp/blfs-plasma-deps2-smoke-build/blfs-plasma-deps2-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma-deps2-smoke-build/blfs-plasma-deps2-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA_DEPS2_RESULT=ok\nPACKAGE_COUNT=5\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=5\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS2_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'UTFCPP=4.0.6\nTAGLIB=2.1.1\nLIBSASS=3.6.6\nSASSC=3.6.2\nXDOTOOL=3.20211022.1\nPACKAGES=utfcpp+taglib+libsass+sassc+xdotool\nDEPENDENCIES=none\n'
  printf 'UTFCPP_SMOKE=native-valid-utf8\nTAGLIB_SMOKE=native-string-roundtrip\nSASSC_SMOKE=native-scss-compile\nXDOTOOL_SMOKE=%s-no-x-server\n' "$XDO_VERSION_OUTPUT"
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nPLASMA_DEPS1=preserved-pipeline-147\nKIRIGAMI_ADDONS=preserved-pipeline-145\nPLASMA=not-built\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma-deps2-smoke /tmp/blfs-plasma-deps2-smoke-build /tmp/blfs-plasma-deps2-smoke-stderr.log
