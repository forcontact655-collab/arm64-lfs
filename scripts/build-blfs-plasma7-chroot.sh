#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma7-report.txt
PROGRESS=/root/blfs-plasma7-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6Core/Qt6CoreConfig.cmake \
  /opt/qt6/lib/cmake/Qt6DBus/Qt6DBusConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Sql/Qt6SqlConfig.cmake \
  /opt/qt6/lib/cmake/Qt6QuickControls2/Qt6QuickControls2Config.cmake \
  /opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake \
  /opt/kf6/lib/cmake/KF6ColorScheme/KF6ColorSchemeConfig.cmake \
  /opt/kf6/lib/cmake/KF6StatusNotifierItem/KF6StatusNotifierItemConfig.cmake \
  /opt/kf6/lib/cmake/KF6KIO/KF6KIOConfig.cmake \
  /opt/kf6/lib/cmake/KF6XmlGui/KF6XmlGuiConfig.cmake \
  /opt/kf6/lib/cmake/KF6GlobalAccel/KF6GlobalAccelConfig.cmake \
  /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake \
  /usr/include/boost/config.hpp \
  /opt/kf6/bin/knetattach \
  /opt/kf6/share/plasma/shells/org.kde.plasma.desktop/metadata.json; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/libexec/kactivitymanagerd \
  /opt/kf6/lib/libkactivitymanagerd_plugin.so \
  /opt/kf6/share/dbus-1/services/org.kde.ActivityManager.service \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
pkg-config --exists wayland-client xcb x11 xcursor
: >"$PROGRESS"
EXTRACTED_DIR=''
extract_package() {
  local archive="$1" expected="$2" first
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  EXTRACTED_DIR="${first%%/*}"
  EXTRACTED_DIR="${EXTRACTED_DIR#./}"
  [[ "$EXTRACTED_DIR" == "$expected" ]]
  rm -rf "$SOURCES/$EXTRACTED_DIR"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$EXTRACTED_DIR"
}
finish_package() {
  cd /sources
  rm -rf "$EXTRACTED_DIR"
  printf 'BLFS_PLASMA7_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}
for name in kactivitymanagerd plasma-integration; do
  extract_package "$name-6.4.4.tar.xz" "$name-6.4.4"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA7=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -W no-dev ..
  ninja
  ninja install
  finish_package
done
rm -rf /opt/kf6/lib/systemd
[[ "$(grep -c '^BLFS_PLASMA7_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/libexec/kactivitymanagerd \
  /opt/kf6/lib/libkactivitymanagerd_plugin.so \
  /opt/kf6/share/dbus-1/services/org.kde.ActivityManager.service \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so \
  /opt/kf6/bin/knetattach \
  /opt/kf6/bin/plasmashell; do
  [[ -e "$path" ]]
done
[[ ! -d /opt/kf6/lib/systemd ]]
for binary in \
  /opt/kf6/libexec/kactivitymanagerd \
  /opt/kf6/lib/libkactivitymanagerd_plugin.so \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so; do
  readelf -h "$binary" | grep -q 'Machine:.*AArch64'
done
readelf -l /opt/kf6/libexec/kactivitymanagerd | grep -q '/lib/ld-linux-aarch64.so.1'
printf 'PLASMA7_POSTCHECK=service-and-integration-files\n'

# kactivitymanagerd has no version-only mode: its main() immediately initializes
# the service and D-Bus registration. Do not execute it here. Instead load and
# instantiate only the new Qt platform-theme plugin under QCoreApplication.
rm -rf /tmp/blfs-plasma7-smoke /tmp/blfs-plasma7-smoke-build \
  /tmp/blfs-plasma7-home /tmp/blfs-plasma7-runtime /tmp/blfs-plasma7-smoke-stderr.log
mkdir -p /tmp/blfs-plasma7-smoke /tmp/blfs-plasma7-home/.config \
  /tmp/blfs-plasma7-home/.cache /tmp/blfs-plasma7-home/.local/share
cat >/tmp/blfs-plasma7-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma7_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core)
add_executable(blfs-plasma7-smoke main.cpp)
target_link_libraries(blfs-plasma7-smoke PRIVATE Qt6::Core)
EOF
cat >/tmp/blfs-plasma7-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QPluginLoader>
#include <QObject>
#include <QtGlobal>
#include <cstdio>
#include <cstring>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  if (argc != 2) return 1;
  QPluginLoader loader(QString::fromLocal8Bit(argv[1]));
  const QJsonObject metadata = loader.metaData().value(QStringLiteral("MetaData")).toObject();
  if (!metadata.value(QStringLiteral("Keys")).toArray().contains(QJsonValue(QStringLiteral("kde")))) return 2;
  if (!loader.load()) return 3;
  QObject *instance = loader.instance();
  if (!instance) return 4;
  const char *className = instance->metaObject()->className();
  if (std::strcmp(className, "KdePlatformThemePlugin") != 0) return 5;
  std::printf("BLFS_PLASMA7_EXEC_OK=%s=%s=kde\n", qVersion(), className);
  if (!loader.unload()) return 6;
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma7-smoke -B /tmp/blfs-plasma7-smoke-build -G Ninja \
  -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma7-smoke-build
install -d -m0700 /tmp/blfs-plasma7-runtime
set +e
NATIVE_SMOKE_OUTPUT="$(env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
  HOME=/tmp/blfs-plasma7-home LC_ALL=C.UTF-8 NO_AT_BRIDGE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma7-runtime \
  XDG_CONFIG_HOME=/tmp/blfs-plasma7-home/.config \
  XDG_CACHE_HOME=/tmp/blfs-plasma7-home/.cache \
  XDG_DATA_HOME=/tmp/blfs-plasma7-home/.local/share \
  XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib \
  /tmp/blfs-plasma7-smoke-build/blfs-plasma7-smoke \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so \
  2>/tmp/blfs-plasma7-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma7-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$NATIVE_SMOKE_OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$NATIVE_SMOKE_OUTPUT" == BLFS_PLASMA7_EXEC_OK=6.9.2=KdePlatformThemePlugin=kde ]]
readelf -h /tmp/blfs-plasma7-smoke-build/blfs-plasma7-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma7-smoke-build/blfs-plasma7-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA7_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA7_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$NATIVE_SMOKE_OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=kactivitymanagerd+plasma-integration\nKACTIVITYMANAGERD=6.4.4\nPLASMA_INTEGRATION=6.4.4\n'
  printf 'NATIVE_SMOKE=native-qpluginloader-instance-no-gui-display-or-dbus\n'
  printf 'ACTIVITY_SERVICE=installed-not-started-no-dbus\nKACTIVITYMANAGERD_EXEC=not-run-service-has-no-version-only-mode\n'
  printf 'PLATFORM_THEME_PLUGIN=native-load-and-instance-only-no-theme-session\nQT5=not-built-BUILD_QT5_OFF\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA6=preserved-pipeline-183\nPLASMA_DESKTOP=preserved-not-rebuilt-not-running\n'
  printf 'KWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\n'
  printf 'DBUS_SESSION=not-started\nNETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma7-smoke /tmp/blfs-plasma7-smoke-build \
  /tmp/blfs-plasma7-home /tmp/blfs-plasma7-runtime /tmp/blfs-plasma7-smoke-stderr.log
