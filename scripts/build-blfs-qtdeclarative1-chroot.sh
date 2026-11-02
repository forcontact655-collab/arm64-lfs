#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qtdeclarative1-report.txt
PROGRESS=/root/blfs-qtdeclarative1-progress.txt
CONFIG_SUMMARY=/root/blfs-qtdeclarative1-config-summary.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/python3 ]]
[[ -x "$QT6PREFIX/bin/qmake6" ]]
[[ -x "$QT6PREFIX/bin/qt-configure-module" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6ShaderToolsTools/Qt6ShaderToolsToolsConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake" ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=qtdeclarative-everywhere-src-6.9.2.tar.xz
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == qtdeclarative-everywhere-src-6.9.2 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
mkdir "$SOURCES/$PACKAGE_DIR/build"
cd "$SOURCES/$PACKAGE_DIR/build"
printf 'BUILD_BLFS_QTDECLARATIVE1=qtdeclarative\n'
/opt/qt6/bin/qt-configure-module "$SOURCES/$PACKAGE_DIR" -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_BUILD_EXAMPLES=OFF \
  -DQT_BUILD_TESTS=OFF \
  -DQT_BUILD_MANUAL_TESTS=OFF \
  -DQT_GENERATE_SBOM=OFF
[[ -s config.summary ]]
ninja
ninja install
cp config.summary "$CONFIG_SUMMARY"
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_QTDECLARATIVE1_BUILT=qtdeclarative-everywhere-src-6.9.2\n' >>"$PROGRESS"
find "$QT6PREFIX" -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_QTDECLARATIVE1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6QuickControls2/Qt6QuickControls2Config.cmake" ]]
[[ -d "$QT6PREFIX/qml/QtQuick" ]]
[[ -d "$QT6PREFIX/qml/QtQuick/Controls" ]]

rm -rf /tmp/blfs-qtdeclarative1-smoke /tmp/blfs-qtdeclarative1-smoke-build
mkdir -p /tmp/blfs-qtdeclarative1-smoke
cat >/tmp/blfs-qtdeclarative1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qtdeclarative1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
add_executable(blfs-qtdeclarative1-smoke main.cpp)
target_link_libraries(blfs-qtdeclarative1-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)
EOF
cat >/tmp/blfs-qtdeclarative1-smoke/main.cpp <<'EOF'
#include <QByteArray>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickItem>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
#include <memory>
int main(int argc, char **argv) {
  QGuiApplication application(argc, argv);
  QQmlEngine engine;
  QQmlComponent component(&engine);
  const QByteArray qml("import QtQuick\nimport QtQuick.Controls\nItem { width: 64; height: 64; Button { text: 'smoke'; anchors.centerIn: parent } }\n");
  component.setData(qml, QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 1;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) return 2;
  auto *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->childItems().isEmpty()) return 3;
  std::printf("BLFS_QTDECLARATIVE1_EXEC_OK=%s\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-qtdeclarative1-smoke -B /tmp/blfs-qtdeclarative1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qtdeclarative1-smoke-build
install -d -m 0700 /tmp/blfs-qtdeclarative1-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
  QML2_IMPORT_PATH=/opt/qt6/qml XDG_RUNTIME_DIR=/tmp/blfs-qtdeclarative1-runtime LIBGL_ALWAYS_SOFTWARE=1 \
  /tmp/blfs-qtdeclarative1-smoke-build/blfs-qtdeclarative1-smoke)"
[[ "$OUTPUT" == BLFS_QTDECLARATIVE1_EXEC_OK=6.9.2 ]]
readelf -h /tmp/blfs-qtdeclarative1-smoke-build/blfs-qtdeclarative1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qtdeclarative1-smoke-build/blfs-qtdeclarative1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_QTDECLARATIVE1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QTDECLARATIVE1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QTBASE=6.9.2\n'
  printf 'QTSHADERTOOLS=6.9.2\n'
  printf 'QTSVG=6.9.2\n'
  printf 'QTDECLARATIVE=6.9.2\n'
  printf 'QML_SMOKE=%s\n' "$OUTPUT"
  printf 'QUICK_CONTROLS=present\n'
  printf 'QML_IMPORT_DIR=%s\n' "$QT6PREFIX/qml"
  printf 'BOOTABLE=no\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qtdeclarative1-smoke /tmp/blfs-qtdeclarative1-smoke-build /tmp/blfs-qtdeclarative1-runtime
