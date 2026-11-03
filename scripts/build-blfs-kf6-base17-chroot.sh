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
REPORT=/root/blfs-kf6-base17-report.txt
PROGRESS=/root/blfs-kf6-base17-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Qml Qt6Quick Qt6QuickControls2 Qt6ShaderTools Qt6Network Qt6Test; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Prison KF6Baloo KF6KirigamiPlatform KF6Notifications KF6KIO; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6QQC2DesktopStyle KF6Holidays KF6Purpose KF6QuickCharts KF6CalendarCore; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
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
packages=(qqc2-desktop-style kholidays purpose kquickcharts)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE17=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D BUILD_PYTHON_BINDINGS=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE17_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE17_BUILT=' "$PROGRESS")" -eq 4 ]]
for path in \
  /opt/kf6/lib/cmake/KF6QQC2DesktopStyle/KF6QQC2DesktopStyleConfig.cmake \
  /opt/kf6/lib/cmake/KF6Holidays/KF6HolidaysConfig.cmake \
  /opt/kf6/lib/cmake/KF6Purpose/KF6PurposeConfig.cmake \
  /opt/kf6/lib/cmake/KF6QuickCharts/KF6QuickChartsConfig.cmake \
  /opt/kf6/lib/libKF6Holidays.so \
  /opt/kf6/lib/libKF6Purpose.so \
  /opt/kf6/lib/libQuickCharts.so \
  /opt/kf6/lib/qml/org/kde/desktop/qmldir \
  /opt/kf6/lib/qml/org/kde/kholidays/qmldir \
  /opt/kf6/lib/qml/org/kde/purpose/qmldir \
  /opt/kf6/lib/qml/org/kde/quickcharts/qmldir; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base17-smoke /tmp/blfs-kf6-base17-smoke-build /tmp/blfs-kf6-base17-runtime /tmp/blfs-kf6-base17-config
mkdir -p /tmp/blfs-kf6-base17-smoke /tmp/blfs-kf6-base17-config
cat >/tmp/blfs-kf6-base17-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base17_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick Widgets QuickControls2 ShaderTools Network Test DBus)
find_package(KF6QQC2DesktopStyle 6.17.0 REQUIRED CONFIG)
find_package(KF6Holidays 6.17.0 REQUIRED CONFIG)
find_package(KF6Purpose 6.17.0 REQUIRED CONFIG)
find_package(KF6QuickCharts 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base17-smoke main.cpp)
target_link_libraries(blfs-kf6-base17-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Widgets Qt6::Network Qt6::DBus
  KF6::Holidays KF6::Purpose KF6::QuickCharts)
EOF
cat >/tmp/blfs-kf6-base17-smoke/main.cpp <<'EOF'
#include <KHolidays/HolidayRegion>
#include <Purpose/AlternativesModel>
#include <QApplication>
#include <QDate>
#include <QJsonObject>
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
  QApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-kf6-base17-smoke"));
  KHolidays::HolidayRegion region(QStringLiteral("US_en-us"));
  if (!region.isValid() || !region.isHoliday(QDate(2026, 1, 1))) return 1;
  Purpose::AlternativesModel alternatives;
  QJsonObject input{{QStringLiteral("text"), QStringLiteral("native")}};
  alternatives.setInputData(input);
  if (alternatives.inputData() != input) return 2;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.desktop 1.0\nimport org.kde.kholidays 1.0\nimport org.kde.purpose 1.0\nimport org.kde.quickcharts 1.0\nItem { width: 24; height: 12; BarChart { width: 20; height: 10 } }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 3;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) return 4;
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 24.0) return 5;
  std::printf("BLFS_KF6_BASE17_EXEC_OK=%s=holidays=us=purpose=data=charts=24\n", qVersion());
  return 0;
}
EOF
QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
cmake -S /tmp/blfs-kf6-base17-smoke -B /tmp/blfs-kf6-base17-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6" -D KDE_INSTALL_FULL_QMLDIR=/opt/kf6/lib/qml
ninja -C /tmp/blfs-kf6-base17-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base17-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-kf6-base17-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base17-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /tmp/blfs-kf6-base17-smoke-build/blfs-kf6-base17-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE17_EXEC_OK=6.9.2=holidays=us=purpose=data=charts=24 ]]
readelf -h /tmp/blfs-kf6-base17-smoke-build/blfs-kf6-base17-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base17-smoke-build/blfs-kf6-base17-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE17_RESULT=ok\nPACKAGE_COUNT=4\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE17_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=qqc2-desktop-style+kholidays+purpose+kquickcharts\nDEPENDENCIES=none\n'
  printf 'QQC2=native-qml-desktop-import\nKHOLIDAYS=native-us-holiday\nPURPOSE=native-alternatives-model-no-start\nQUICKCHARTS=qml-barchart-unshown\n'
  printf 'SPIRV_OPT=absent-qsb-fallback\nKCALENDARCORE=deferred-libical-required\nNETWORK_RUNTIME=not-tested-no-job-start\nWINDOW_RUNTIME=not-tested-no-window-shown\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nBASE16=preserved-pipeline-129\nBASE15=preserved-pipeline-128\nBASE14=preserved-pipeline-126\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base17-smoke /tmp/blfs-kf6-base17-smoke-build /tmp/blfs-kf6-base17-runtime /tmp/blfs-kf6-base17-config
