#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qt-declarative1-report.txt
PROGRESS=/root/blfs-qt-declarative1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -f /opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake ]]
for path in KF6GuiAddons KF6I18n KF6IdleTime; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in Qt6ShaderTools Qt6Qml Qt6Quick Qt6QuickWidgets; do [[ ! -e "/opt/qt6/lib/cmake/$path" ]]; done
[[ -x /usr/bin/xfce4-terminal ]]
: >"$PROGRESS"
packages=(qtshadertools qtdeclarative)
for name in "${packages[@]}"; do
  archive="$name-everywhere-src-6.9.2.tar.xz"; [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$name-everywhere-src-6.9.2" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  mkdir "$SOURCES/$package_dir/build"; cd "$SOURCES/$package_dir/build"
  printf 'BUILD_BLFS_QT_DECLARATIVE1=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/qt6 \
    -D CMAKE_PREFIX_PATH=/opt/qt6 \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D QT_BUILD_EXAMPLES=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$package_dir"
  printf 'BLFS_QT_DECLARATIVE1_BUILT=%s-everywhere-src-6.9.2\n' "$name" >>"$PROGRESS"
  /sbin/ldconfig
done
[[ "$(grep -c '^BLFS_QT_DECLARATIVE1_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake \
  /opt/qt6/lib/cmake/Qt6QuickWidgets/Qt6QuickWidgetsConfig.cmake \
  /opt/qt6/lib/libQt6ShaderTools.so \
  /opt/qt6/lib/libQt6Qml.so \
  /opt/qt6/lib/libQt6Quick.so \
  /opt/qt6/lib/libQt6QuickWidgets.so; do [[ -e "$path" ]]; done
[[ -x /opt/qt6/bin/qsb && -x /opt/qt6/bin/qml ]]
rm -rf /tmp/blfs-qt-declarative1-smoke /tmp/blfs-qt-declarative1-smoke-build /tmp/blfs-qt-declarative1-runtime
mkdir -p /tmp/blfs-qt-declarative1-smoke
cat >/tmp/blfs-qt-declarative1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qt_declarative1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets ShaderTools Qml Quick QuickWidgets)
add_executable(blfs-qt-declarative1-smoke main.cpp)
target_link_libraries(blfs-qt-declarative1-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets Qt6::ShaderTools Qt6::Qml Qt6::Quick Qt6::QuickWidgets)
EOF
cat >/tmp/blfs-qt-declarative1-smoke/main.cpp <<'EOF'
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
#include <memory>
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral("import QtQuick\nItem { width: 32; height: 16 }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) qWarning("%s", error.toString().toUtf8().constData());
    return 2;
  }
  std::unique_ptr<QObject> object(component.create());
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 32.0 || item->height() != 16.0) return 3;
  std::printf("BLFS_QT_DECLARATIVE1_EXEC_OK=%s=%d\n", qVersion(), static_cast<int>(item->width()));
  return 0;
}
EOF
cmake -S /tmp/blfs-qt-declarative1-smoke -B /tmp/blfs-qt-declarative1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qt-declarative1-smoke-build
install -d -m 0700 /tmp/blfs-qt-declarative1-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-qt-declarative1-runtime QML2_IMPORT_PATH=/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/qt6/qml QT_PLUGIN_PATH=/opt/qt6/plugins QML_DISABLE_DISK_CACHE=1 \
  LD_LIBRARY_PATH=/opt/qt6/lib /tmp/blfs-qt-declarative1-smoke-build/blfs-qt-declarative1-smoke)"
[[ "$OUTPUT" == BLFS_QT_DECLARATIVE1_EXEC_OK=6.9.2=32 ]]
readelf -h /tmp/blfs-qt-declarative1-smoke-build/blfs-qt-declarative1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qt-declarative1-smoke-build/blfs-qt-declarative1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_QT_DECLARATIVE1_RESULT=ok\nPACKAGE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QT_DECLARATIVE1_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nQT_MODULES=qtshadertools+qtdeclarative\n'
  printf 'QML_QUICK_SMOKE=native-offscreen-item-32x16-created\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nRENDERING=not-tested\n'
  printf 'KF6_BASE2=preserved\nXFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qt-declarative1-smoke /tmp/blfs-qt-declarative1-smoke-build /tmp/blfs-qt-declarative1-runtime
