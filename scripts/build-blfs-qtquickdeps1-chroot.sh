#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qtquickdeps1-report.txt
PROGRESS=/root/blfs-qtquickdeps1-progress.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -x "$QT6PREFIX/bin/qmake6" ]]
[[ -x "$QT6PREFIX/bin/qt-configure-module" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -d /sources ]]
: >"$PROGRESS"

build_module() {
  local module="$1"
  local archive="$module-everywhere-src-6.9.2.tar.xz"
  local first package_dir build_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"
  package_dir="${package_dir#./}"
  [[ "$package_dir" == "$module-everywhere-src-6.9.2" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  build_dir="$SOURCES/$package_dir/build"
  mkdir "$build_dir"
  cd "$build_dir"
  printf 'BUILD_BLFS_QTQUICKDEPS1=%s\n' "$module"
  /opt/qt6/bin/qt-configure-module "$SOURCES/$package_dir" -- \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_EXAMPLES=OFF \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_MANUAL_TESTS=OFF \
    -DQT_GENERATE_SBOM=OFF
  [[ -s config.summary ]]
  ninja
  ninja install
  cp config.summary "/root/blfs-qtquickdeps1-config-summary-$module.txt"
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_QTQUICKDEPS1_BUILT=%s\n' "$package_dir" >>"$PROGRESS"
}

build_module qtshadertools
build_module qtsvg
find "$QT6PREFIX" -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_QTQUICKDEPS1_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6SvgWidgets/Qt6SvgWidgetsConfig.cmake" ]]
[[ -f "$QT6PREFIX/plugins/imageformats/libqsvg.so" ]]
[[ -f "$QT6PREFIX/plugins/iconengines/libqsvgicon.so" ]]
mapfile -t QSB_CANDIDATES < <(find "$QT6PREFIX/bin" "$QT6PREFIX/libexec" -maxdepth 1 -type f -name qsb -perm -u+x 2>/dev/null)
[[ "${#QSB_CANDIDATES[@]}" -eq 1 ]]
QSB="${QSB_CANDIDATES[0]}"
QSB_VERSION="$($QSB --version)"
printf 'QSB_VERSION_OUTPUT=%s\n' "$QSB_VERSION"
[[ "$QSB_VERSION" == *6.9.2* ]]

rm -rf /tmp/blfs-qtquickdeps1-qsb
mkdir -p /tmp/blfs-qtquickdeps1-qsb
cat >/tmp/blfs-qtquickdeps1-qsb/smoke.vert <<'EOF'
#version 440
layout(location = 0) in vec2 position;
void main() {
    gl_Position = vec4(position, 0.0, 1.0);
}
EOF
"$QSB" --glsl 330 -o /tmp/blfs-qtquickdeps1-qsb/smoke.qsb /tmp/blfs-qtquickdeps1-qsb/smoke.vert
[[ -s /tmp/blfs-qtquickdeps1-qsb/smoke.qsb ]]
QSB_BYTES="$(stat -c %s /tmp/blfs-qtquickdeps1-qsb/smoke.qsb)"

rm -rf /tmp/blfs-qtquickdeps1-svg /tmp/blfs-qtquickdeps1-svg-build
mkdir -p /tmp/blfs-qtquickdeps1-svg
cat >/tmp/blfs-qtquickdeps1-svg/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qtquickdeps1_svg_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Svg)
add_executable(blfs-qtquickdeps1-svg-smoke main.cpp)
target_link_libraries(blfs-qtquickdeps1-svg-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Svg)
EOF
cat >/tmp/blfs-qtquickdeps1-svg/main.cpp <<'EOF'
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QSvgRenderer>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QGuiApplication application(argc, argv);
  const QByteArray svg("<svg xmlns='http://www.w3.org/2000/svg' width='8' height='8'><rect width='8' height='8' fill='#336699'/></svg>");
  QSvgRenderer renderer(svg);
  if (!renderer.isValid()) return 1;
  QImage image(8, 8, QImage::Format_ARGB32);
  image.fill(0x00000000u);
  QPainter painter(&image);
  renderer.render(&painter);
  painter.end();
  if (image.pixel(4, 4) != 0xff336699u) return 2;
  std::printf("BLFS_QTQUICKDEPS1_EXEC_OK=%s\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-qtquickdeps1-svg -B /tmp/blfs-qtquickdeps1-svg-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qtquickdeps1-svg-build
install -d -m 0700 /tmp/blfs-qtquickdeps1-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp/blfs-qtquickdeps1-runtime LIBGL_ALWAYS_SOFTWARE=1 \
  /tmp/blfs-qtquickdeps1-svg-build/blfs-qtquickdeps1-svg-smoke)"
[[ "$OUTPUT" == BLFS_QTQUICKDEPS1_EXEC_OK=6.9.2 ]]
readelf -h /tmp/blfs-qtquickdeps1-svg-build/blfs-qtquickdeps1-svg-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qtquickdeps1-svg-build/blfs-qtquickdeps1-svg-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_QTQUICKDEPS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=2\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QTQUICKDEPS1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QTBASE=6.9.2\n'
  printf 'QTSHADERTOOLS=6.9.2\n'
  printf 'QTSVG=6.9.2\n'
  printf 'QSB=%s\n' "$QSB"
  printf 'QSB_SMOKE_BYTES=%s\n' "$QSB_BYTES"
  printf 'SVG_SMOKE=%s\n' "$OUTPUT"
  printf 'SVG_IMAGE_PLUGIN=present\n'
  printf 'SVG_ICON_PLUGIN=present\n'
  printf 'BOOTABLE=no\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qtquickdeps1-qsb /tmp/blfs-qtquickdeps1-svg /tmp/blfs-qtquickdeps1-svg-build /tmp/blfs-qtquickdeps1-runtime
