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
REPORT=/root/blfs-plasma-kirigami-addons1-report.txt
PROGRESS=/root/blfs-plasma-kirigami-addons1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui Qt6Qml Qt6Quick Qt6QuickControls2; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Kirigami KF6GlobalAccel KF6I18n KF6Config KF6CoreAddons KF6GuiAddons; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e /opt/kf6/lib/cmake/KF6KirigamiAddons ]]
: >"$PROGRESS"
archive=kirigami-addons-1.9.0.tar.xz
package_dir=kirigami-addons-1.9.0
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
[[ "${first%%/*}" == "$package_dir" ]]
rm -rf "$SOURCES/$package_dir"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
cd "$SOURCES/$package_dir"
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_KIRIGAMI_ADDONS1=kirigami-addons\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -D BUILD_EXAMPLES=OFF \
  -W no-dev ..
ninja
ninja install
cd /sources; rm -rf "$package_dir"
printf 'BLFS_PLASMA_KIRIGAMI_ADDONS1_BUILT=kirigami-addons-1.9.0\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA_KIRIGAMI_ADDONS1_BUILT=' "$PROGRESS")" -eq 1 ]]
for path in \
  /opt/kf6/lib/cmake/KF6KirigamiAddons/KF6KirigamiAddonsConfig.cmake \
  /opt/kf6/lib/cmake/KF6KirigamiAddons/KirigamiAddonsTargets.cmake \
  /opt/kf6/lib/qml/org/kde/kirigamiaddons/components/qmldir \
  /opt/kf6/lib/qml/org/kde/kirigamiaddons/formcard/qmldir \
  /opt/kf6/lib/qml/org/kde/kirigamiaddons/delegates/qmldir; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-plasma-kirigami-addons1-smoke /tmp/blfs-plasma-kirigami-addons1-smoke-build \
  /tmp/blfs-plasma-kirigami-addons1-runtime /tmp/blfs-plasma-kirigami-addons1-config \
  /tmp/blfs-plasma-kirigami-addons1-smoke-stderr.log
mkdir -p /tmp/blfs-plasma-kirigami-addons1-smoke /tmp/blfs-plasma-kirigami-addons1-config
cat >/tmp/blfs-plasma-kirigami-addons1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma_kirigami_addons1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
find_package(KF6KirigamiAddons 1.9.0 REQUIRED CONFIG)
add_executable(blfs-plasma-kirigami-addons1-smoke main.cpp)
target_link_libraries(blfs-plasma-kirigami-addons1-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)
EOF
cat >/tmp/blfs-plasma-kirigami-addons1-smoke/main.cpp <<'EOF'
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickItem>
#include <QString>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
#include <memory>
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-plasma-kirigami-addons1-smoke"));
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.kirigamiaddons.components 1.0\nItem { width: 24; height: 12; SegmentedButton { width: 20; height: 10 } }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 1;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    std::fprintf(stderr, "QML_CREATE_FAILED\n");
    return 2;
  }
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 24.0) {
    std::fprintf(stderr, "QML_ITEM_FAILED item=%p width=%f\n", static_cast<void *>(item), item ? item->width() : -1.0);
    return 3;
  }
  std::printf("BLFS_PLASMA_KIRIGAMI_ADDONS1_EXEC_OK=%s=1.9.0=components=24\n", qVersion());
  return 0;
}
EOF
QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
cmake -S /tmp/blfs-plasma-kirigami-addons1-smoke -B /tmp/blfs-plasma-kirigami-addons1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D KDE_INSTALL_FULL_QMLDIR=/opt/kf6/lib/qml
ninja -C /tmp/blfs-plasma-kirigami-addons1-smoke-build
install -d -m 0700 /tmp/blfs-plasma-kirigami-addons1-runtime
set +e
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-plasma-kirigami-addons1-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma-kirigami-addons1-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib \
  /tmp/blfs-plasma-kirigami-addons1-smoke-build/blfs-plasma-kirigami-addons1-smoke \
  2>/tmp/blfs-plasma-kirigami-addons1-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma-kirigami-addons1-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA_KIRIGAMI_ADDONS1_EXEC_OK=6.9.2=1.9.0=components=24 ]]
readelf -h /tmp/blfs-plasma-kirigami-addons1-smoke-build/blfs-plasma-kirigami-addons1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma-kirigami-addons1-smoke-build/blfs-plasma-kirigami-addons1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA_KIRIGAMI_ADDONS1_RESULT=ok\nPACKAGE_COUNT=1\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA_KIRIGAMI_ADDONS1_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKIRIGAMI_ADDONS=1.9.0\nPACKAGES=kirigami-addons\nDEPENDENCIES=none\n'
  printf 'QML=native-components-import-unshown\nWINDOW_RUNTIME=not-tested-no-window-shown\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE21=preserved-pipeline-143\nPLASMA=not-built\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma-kirigami-addons1-smoke /tmp/blfs-plasma-kirigami-addons1-smoke-build \
  /tmp/blfs-plasma-kirigami-addons1-runtime /tmp/blfs-plasma-kirigami-addons1-config \
  /tmp/blfs-plasma-kirigami-addons1-smoke-stderr.log
