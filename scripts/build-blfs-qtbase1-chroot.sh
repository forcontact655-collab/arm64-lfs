#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qtbase1-report.txt
PROGRESS=/root/blfs-qtbase1-progress.txt
CONFIG_SUMMARY=/root/blfs-qtbase1-config-summary.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -d /sources ]]
[[ -f /usr/lib/cmake/double-conversion/double-conversionConfig.cmake ]]
REQUIRED_PKG_MODULES=(
  xcb xcb-util xcb-image xcb-keysyms xcb-renderutil xcb-ewmh xcb-icccm
  xcb-cursor xkbcommon fontconfig freetype2 harfbuzz icu-uc egl gl
  libpng16 zlib libpcre2-8 dbus-1 openssl
)
for module in "${REQUIRED_PKG_MODULES[@]}"; do
  if ! pkg-config --exists "$module"; then
    printf 'MISSING_PKG_CONFIG=%s\n' "$module"
    exit 1
  fi
done
: >"$PROGRESS"

first="$(tar -tf "$SOURCES/qtbase-everywhere-src-6.9.2.tar.xz" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == qtbase-everywhere-src-6.9.2 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/qtbase-everywhere-src-6.9.2.tar.xz" -C "$SOURCES"
mkdir "$SOURCES/$PACKAGE_DIR/build"
cd "$SOURCES/$PACKAGE_DIR/build"
printf 'BUILD_BLFS_QTBASE1=qtbase\n'
../configure -prefix "$QT6PREFIX" \
             -sysconfdir /etc/xdg \
             -dbus-linked \
             -openssl-linked \
             -sqlite qt \
             -doubleconversion system \
             -pcre system \
             -zlib system \
             -harfbuzz system \
             -freetype system \
             -libpng system \
             -icu \
             -fontconfig \
             -xcb \
             -xkbcommon \
             -egl \
             -opengl desktop \
             -syslog \
             -nomake examples \
             -nomake tests \
             -no-rpath \
             -no-sbom
[[ -s config.summary ]]
ninja
ninja install
find "$QT6PREFIX" -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
cp config.summary "$CONFIG_SUMMARY"
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_QTBASE1_BUILT=qtbase-everywhere-src-6.9.2\n' >>"$PROGRESS"
unset PACKAGE_DIR

mkdir -p /etc/ld.so.conf.d
printf '/opt/qt6/lib\n' >/etc/ld.so.conf.d/qt6.conf
cat >/etc/profile.d/qt6.sh <<'EOF'
export QT6DIR=/opt/qt6
export PATH="$QT6DIR/bin:$PATH"
export PKG_CONFIG_PATH="$QT6DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="$QT6DIR:${CMAKE_PREFIX_PATH:-}"
EOF
/sbin/ldconfig

[[ "$(grep -c '^BLFS_QTBASE1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -x /opt/qt6/bin/qmake6 ]]
[[ -x /opt/qt6/bin/qtpaths6 ]]
[[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake ]]
QT_VERSION="$(/opt/qt6/bin/qmake6 -query QT_VERSION)"
[[ "$QT_VERSION" == 6.9.2 ]]
PLUGIN_DIR="$(/opt/qt6/bin/qtpaths6 --plugin-dir)"
[[ -f "$PLUGIN_DIR/libqxcb.so" ]]
[[ -f "$PLUGIN_DIR/libqoffscreen.so" ]]

rm -rf /tmp/blfs-qtbase1-smoke /tmp/blfs-qtbase1-smoke-build
mkdir -p /tmp/blfs-qtbase1-smoke
cat >/tmp/blfs-qtbase1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qtbase1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui)
add_executable(blfs-qtbase1-smoke main.cpp)
target_link_libraries(blfs-qtbase1-smoke PRIVATE Qt6::Core Qt6::Gui)
EOF
cat >/tmp/blfs-qtbase1-smoke/main.cpp <<'EOF'
#include <QGuiApplication>
#include <QImage>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QGuiApplication application(argc, argv);
  QImage image(2, 2, QImage::Format_RGB32);
  if (image.isNull()) return 1;
  image.fill(0xff336699u);
  if (image.pixel(0, 0) != 0xff336699u) return 2;
  std::printf("BLFS_QTBASE1_EXEC_OK=%s\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-qtbase1-smoke -B /tmp/blfs-qtbase1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qtbase1-smoke-build
OUTPUT="$(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp LIBGL_ALWAYS_SOFTWARE=1 \
  /tmp/blfs-qtbase1-smoke-build/blfs-qtbase1-smoke)"
[[ "$OUTPUT" == BLFS_QTBASE1_EXEC_OK=6.9.2 ]]
readelf -h /tmp/blfs-qtbase1-smoke-build/blfs-qtbase1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qtbase1-smoke-build/blfs-qtbase1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_QTBASE1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QTBASE1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QTBASE=%s\n' "$QT_VERSION"
  printf 'SQLITE=bundled\n'
  printf 'QT_SMOKE=%s\n' "$OUTPUT"
  printf 'XCB_PLUGIN=present\n'
  printf 'OFFSCREEN_PLUGIN=present\n'
  printf 'BOOTABLE=no\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qtbase1-smoke /tmp/blfs-qtbase1-smoke-build
