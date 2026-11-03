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
REPORT=/root/blfs-kf6-base20-report.txt
PROGRESS=/root/blfs-kf6-base20-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/dbus-run-session ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui Qt6Widgets Qt6DBus Qt6Qml Qt6Quick Qt6Svg Qt6QuickControls2; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6WindowSystem KF6Archive KF6Config KF6ColorScheme KF6CoreAddons KF6GuiAddons KF6KirigamiPlatform; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e /opt/kf6/lib/cmake/KF6StatusNotifierItem && ! -e /opt/kf6/lib/cmake/KF6Svg ]]
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
build_kf6() {
  local name="$1"
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE20=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D BUILD_PYTHON_BINDINGS=OFF \
    -D BUILD_TOOLS=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE20_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
}
build_kf6 kstatusnotifieritem
build_kf6 ksvg
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE20_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6StatusNotifierItem/KF6StatusNotifierItemConfig.cmake \
  /opt/kf6/lib/libKF6StatusNotifierItem.so \
  /opt/kf6/lib/cmake/KF6Svg/KF6SvgConfig.cmake \
  /opt/kf6/lib/libKF6Svg.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base20-smoke /tmp/blfs-kf6-base20-smoke-build /tmp/blfs-kf6-base20-runtime
mkdir -p /tmp/blfs-kf6-base20-smoke
cat >/tmp/blfs-kf6-base20-smoke/native.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"><rect id="native" width="2" height="2" fill="#ff0000"/></svg>
EOF
cat >/tmp/blfs-kf6-base20-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base20_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets DBus)
find_package(KF6StatusNotifierItem 6.17.0 REQUIRED CONFIG)
find_package(KF6Config 6.17.0 REQUIRED CONFIG)
find_package(KF6Svg 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base20-smoke main.cpp)
target_link_libraries(blfs-kf6-base20-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::DBus KF6::StatusNotifierItem KF6::Svg)
EOF
cat >/tmp/blfs-kf6-base20-smoke/main.cpp <<'EOF'
#include <KStatusNotifierItem>
#include <KSvg/Svg>
#include <QApplication>
#include <QImage>
#include <QSize>
#include <QString>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  KStatusNotifierItem item(QStringLiteral("native"));
  item.setTitle(QStringLiteral("native"));
  item.setIconByName(QStringLiteral("dialog-information"));
  item.setStatus(KStatusNotifierItem::Active);
  if (item.title() != QStringLiteral("native") || item.iconName() != QStringLiteral("dialog-information") || item.status() != KStatusNotifierItem::Active) return 1;
  KSvg::Svg svg;
  svg.setImagePath(QStringLiteral("/tmp/blfs-kf6-base20-smoke/native.svg"));
  QImage image = svg.image(QSize(2, 2));
  if (image.isNull() || image.width() != 2 || image.height() != 2 || image.pixelColor(0, 0).red() < 200 || image.pixelColor(0, 0).alpha() < 200) return 2;
  std::printf("BLFS_KF6_BASE20_EXEC_OK=%s=notifier=properties=svg=render\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base20-smoke -B /tmp/blfs-kf6-base20-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-kf6-base20-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base20-runtime
OUTPUT="$(dbus-run-session -- env XDG_RUNTIME_DIR=/tmp/blfs-kf6-base20-runtime QT_QPA_PLATFORM=offscreen \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib /tmp/blfs-kf6-base20-smoke-build/blfs-kf6-base20-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE20_EXEC_OK=6.9.2=notifier=properties=svg=render ]]
printf 'NATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\n' "$OUTPUT"
readelf -h /tmp/blfs-kf6-base20-smoke-build/blfs-kf6-base20-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base20-smoke-build/blfs-kf6-base20-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE20_RESULT=ok\nPACKAGE_COUNT=2\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE20_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=kstatusnotifieritem+ksvg\nDEPENDENCIES=none\n'
  printf 'STATUS_NOTIFIER=native-properties-private-dbus\nSVG=native-offscreen-render\nDBUS_SESSION=smoke-only-stopped\n'
  printf 'NETWORK_RUNTIME=not-tested\nWINDOW_RUNTIME=not-tested-no-window-shown\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE19=preserved-pipeline-138\nBASE18=preserved-pipeline-136\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base20-smoke /tmp/blfs-kf6-base20-smoke-build /tmp/blfs-kf6-base20-runtime
