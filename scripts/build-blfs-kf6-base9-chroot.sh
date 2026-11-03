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
REPORT=/root/blfs-kf6-base9-report.txt
PROGRESS=/root/blfs-kf6-base9-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Qml Qt6Quick Qt6QuickControls2 Qt6Svg Qt6ShaderTools; do
  [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6Wallet KF6KDED KF6KIO; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
[[ -e /usr/lib/libsecret-1.so && -f /usr/lib/pkgconfig/libsecret-1.pc ]]
for path in KF6Declarative KF6KCMUtils KF6Kirigami; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
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
packages=(kdeclarative kcmutils kirigami)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE9=%s\n' "$name"
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
  printf 'BLFS_KF6_BASE9_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE9_BUILT=' "$PROGRESS")" -eq 3 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Declarative/KF6DeclarativeConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Kirigami/KF6KirigamiConfig.cmake \
  /opt/kf6/lib/cmake/KF6KirigamiPlatform/KF6KirigamiPlatformConfig.cmake \
  /opt/kf6/lib/libKF6CalendarEvents.so \
  /opt/kf6/lib/libKF6KCMUtils.so \
  /opt/kf6/lib/libKF6KCMUtilsCore.so \
  /opt/kf6/lib/libKF6KCMUtilsQuick.so \
  /opt/kf6/lib/libKirigami.so \
  /opt/kf6/lib/libKirigamiPlatform.so \
  /opt/kf6/lib/qml/org/kde/kquickcontrolsaddons/qmldir \
  /opt/kf6/lib/qml/org/kde/kcmutils/qmldir \
  /opt/kf6/lib/qml/org/kde/kirigami/qmldir; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base9-smoke /tmp/blfs-kf6-base9-smoke-build /tmp/blfs-kf6-base9-runtime
mkdir -p /tmp/blfs-kf6-base9-smoke
cat >/tmp/blfs-kf6-base9-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base9_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick Widgets)
find_package(KF6Declarative 6.17.0 REQUIRED CONFIG)
find_package(KF6KCMUtils 6.17.0 REQUIRED CONFIG)
find_package(KF6Kirigami 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base9-smoke main.cpp)
target_link_libraries(blfs-kf6-base9-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Widgets
  KF6::CalendarEvents KF6::KCMUtils KF6::Kirigami)
EOF
cat >/tmp/blfs-kf6-base9-smoke/main.cpp <<'EOF'
#include <CalendarEvents/CalendarEventsPlugin>
#include <KCMultiDialog>
#include <QApplication>
#include <QDate>
#include <QDateTime>
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
  app.setApplicationName(QStringLiteral("blfs-kf6-base9-smoke"));
  CalendarEvents::EventData event;
  const QDateTime start(QDate(2026, 11, 3), QTime(0, 0));
  event.setStartDateTime(start);
  event.setTitle(QStringLiteral("native"));
  if (event.startDateTime() != start || event.title() != QStringLiteral("native")) return 1;
  KCMultiDialog dialog;
  dialog.setDefaultsIndicatorsVisible(false);
  dialog.clear();
  if (dialog.isVisible()) return 2;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\n"
    "import org.kde.kquickcontrolsaddons 2.0\n"
    "import org.kde.kcmutils 1.0\n"
    "import org.kde.kirigami 2.0 as Kirigami\n"
    "Kirigami.Heading { width: 32; height: 20; text: 'smoke' }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 3;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) return 4;
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 32.0 || item->property("text").toString() != QStringLiteral("smoke")) return 5;
  std::printf("BLFS_KF6_BASE9_EXEC_OK=%s=%s=%d\n", qVersion(),
              item->property("text").toString().toUtf8().constData(), static_cast<int>(item->width()));
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base9-smoke -B /tmp/blfs-kf6-base9-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base9-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base9-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base9-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /tmp/blfs-kf6-base9-smoke-build/blfs-kf6-base9-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE9_EXEC_OK=6.9.2=smoke=32 ]]
readelf -h /tmp/blfs-kf6-base9-smoke-build/blfs-kf6-base9-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base9-smoke-build/blfs-kf6-base9-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE9_RESULT=ok\nPACKAGE_COUNT=3\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE9_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=kdeclarative+kcmutils+kirigami\nDEPENDENCIES=none\n'
  printf 'KDECLARATIVE=native-event-data-qml-import-ok\nKCMUTILS=native-dialog-object-qml-import-ok\n'
  printf 'KIRIGAMI=native-offscreen-heading-ok\nQML_IMPORTS=kquickcontrolsaddons+kcmutils+kirigami\n'
  printf 'CALENDAR_RUNTIME=not-tested-no-provider\nKCM_RUNTIME=not-tested-no-module-loaded\nWINDOW_RUNTIME=not-tested-no-window-shown\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nBASE8=preserved-pipeline-115\nBASE7=preserved-pipeline-106\n'
  printf 'SECURITY_DEPS1=preserved-pipeline-109\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base9-smoke /tmp/blfs-kf6-base9-smoke-build /tmp/blfs-kf6-base9-runtime
