#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base3-report.txt
PROGRESS=/root/blfs-kf6-base3-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Qml Qt6Quick Qt6QuickControls2 Qt6WaylandClient; do
  [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6GuiAddons KF6I18n KF6IdleTime; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6ItemModels KF6ItemViews KF6Plotting KF6WidgetsAddons KF6WindowSystem; do
  [[ ! -e "/opt/kf6/lib/cmake/$path" ]]
done
[[ -x /usr/bin/xfce4-terminal ]]
: >"$PROGRESS"
packages=(kitemmodels kitemviews kplotting kwidgetsaddons kwindowsystem)
for name in "${packages[@]}"; do
  archive="$name-6.17.0.tar.xz"; [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$name-6.17.0" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  mkdir "$SOURCES/$package_dir/build"; cd "$SOURCES/$package_dir/build"
  printf 'BUILD_BLFS_KF6_BASE3=%s\n' "$name"
  cmake_args=(
    -D CMAKE_INSTALL_PREFIX=/opt/kf6
    -D CMAKE_INSTALL_LIBEXECDIR=libexec
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
    -D CMAKE_SKIP_INSTALL_RPATH=ON
    -D CMAKE_BUILD_TYPE=Release
    -D BUILD_TESTING=OFF
    -D BUILD_PYTHON_BINDINGS=OFF
  )
  if [[ "$name" == kwindowsystem ]]; then
    cmake_args+=(
      -D KWINDOWSYSTEM_QML=ON
      -D KWINDOWSYSTEM_X11=ON
      -D KWINDOWSYSTEM_WAYLAND=ON
    )
  fi
  cmake -G Ninja "${cmake_args[@]}" -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$package_dir"
  printf 'BLFS_KF6_BASE3_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE3_BUILT=' "$PROGRESS")" -eq 5 ]]
for path in \
  /opt/kf6/lib/cmake/KF6ItemModels/KF6ItemModelsConfig.cmake \
  /opt/kf6/lib/cmake/KF6ItemViews/KF6ItemViewsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Plotting/KF6PlottingConfig.cmake \
  /opt/kf6/lib/cmake/KF6WidgetsAddons/KF6WidgetsAddonsConfig.cmake \
  /opt/kf6/lib/cmake/KF6WindowSystem/KF6WindowSystemConfig.cmake \
  /opt/kf6/lib/libKF6ItemModels.so \
  /opt/kf6/lib/libKF6ItemViews.so \
  /opt/kf6/lib/libKF6Plotting.so \
  /opt/kf6/lib/libKF6WidgetsAddons.so \
  /opt/kf6/lib/libKF6WindowSystem.so \
  /opt/kf6/lib/qml/org/kde/kitemmodels/qmldir \
  /opt/kf6/lib/qml/org/kde/kwindowsystem/qmldir; do [[ -e "$path" ]]; done
for name in kitemviews6widgets kplotting6widgets kwidgetsaddons6widgets; do
  find /opt/kf6/lib/plugins/designer -type f -name "$name.so" -print -quit | grep -q .
done
rm -rf /tmp/blfs-kf6-base3-smoke /tmp/blfs-kf6-base3-smoke-build /tmp/blfs-kf6-base3-runtime
mkdir -p /tmp/blfs-kf6-base3-smoke
cat >/tmp/blfs-kf6-base3-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base3_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets Qml Quick)
find_package(KF6ItemModels 6.17.0 REQUIRED CONFIG)
find_package(KF6ItemViews 6.17.0 REQUIRED CONFIG)
find_package(KF6Plotting 6.17.0 REQUIRED CONFIG)
find_package(KF6WidgetsAddons 6.17.0 REQUIRED CONFIG)
find_package(KF6WindowSystem 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base3-smoke main.cpp)
target_link_libraries(blfs-kf6-base3-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick
  KF6::ItemModels KF6::ItemViews KF6::Plotting KF6::WidgetsAddons KF6::WindowSystem)
EOF
cat >/tmp/blfs-kf6-base3-smoke/main.cpp <<'EOF'
#include <KDescendantsProxyModel>
#include <KPlotWidget>
#include <QApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
#include <memory>
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  KDescendantsProxyModel proxy;
  KPlotWidget plot;
  if (proxy.columnCount() != 0) return 1;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.kitemmodels 1.0\nimport org.kde.kwindowsystem 1.0\nItem { width: 24; height: 12 }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) qWarning("%s", error.toString().toUtf8().constData());
    return 2;
  }
  std::unique_ptr<QObject> object(component.create());
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 24.0 || item->height() != 12.0) return 3;
  std::printf("BLFS_KF6_BASE3_EXEC_OK=%s=%d\n", qVersion(), static_cast<int>(item->width()));
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base3-smoke -B /tmp/blfs-kf6-base3-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base3-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base3-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base3-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /tmp/blfs-kf6-base3-smoke-build/blfs-kf6-base3-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE3_EXEC_OK=6.9.2=24 ]]
readelf -h /tmp/blfs-kf6-base3-smoke-build/blfs-kf6-base3-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base3-smoke-build/blfs-kf6-base3-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE3_RESULT=ok\nPACKAGE_COUNT=5\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE3_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\n'
  printf 'PACKAGES=kitemmodels+kitemviews+kplotting+kwidgetsaddons+kwindowsystem\n'
  printf 'QML_SMOKE=native-offscreen-item-24x12-created\n'
  printf 'QML_MODULES=itemmodels+kwindowsystem\nDESIGNER_PLUGINS=3-built-not-run\n'
  printf 'X11_WAYLAND=compiled-in-runtime-not-tested\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'KDNSSD=deferred-avahi-backend\nKIMAGEFORMATS=deferred-plugin-validation\n'
  printf 'QT_DECLARATIVE=preserved-pipeline-28\nBASE2=preserved-pipeline-91\n'
  printf 'XFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base3-smoke /tmp/blfs-kf6-base3-smoke-build /tmp/blfs-kf6-base3-runtime
