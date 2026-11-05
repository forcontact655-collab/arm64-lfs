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
REPORT=/root/blfs-plasma5-report.txt
PROGRESS=/root/blfs-plasma5-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /opt/qt6/bin/qt-configure-module ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6QuickWidgets/Qt6QuickWidgetsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Test/Qt6TestConfig.cmake \
  /opt/qt6/lib/cmake/Qt6QuickTest/Qt6QuickTestConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake \
  /opt/kf6/lib/cmake/KWinDBusInterface/KWinDBusInterfaceConfig.cmake \
  /opt/kf6/lib/cmake/ScreenSaverDBusInterface/ScreenSaverDBusInterfaceConfig.cmake \
  /opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake \
  /usr/lib/cmake/phonon4qt6/Phonon4Qt6Config.cmake \
  /usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake \
  /usr/lib/pkgconfig/libcanberra.pc \
  /opt/kf6/bin/kwin_x11 \
  /opt/kf6/bin/kwin_wayland; do
  [[ -e "$path" ]]
done
for path in \
  /opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake \
  /opt/kf6/bin/plasmashell \
  /opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
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
  printf 'BLFS_PLASMA5_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}

# plasma-workspace requires Qt Location and Positioning. Build their official
# Qt 6.9.2 submodule archive against the already accepted modular Qt prefix.
extract_package qtlocation-everywhere-src-6.9.2.tar.xz qtlocation-everywhere-src-6.9.2
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA5=qtlocation\n'
/opt/qt6/bin/qt-configure-module "$SOURCES/$EXTRACTED_DIR" -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_BUILD_EXAMPLES=OFF \
  -DQT_BUILD_TESTS=OFF \
  -DQT_BUILD_MANUAL_TESTS=OFF \
  -DQT_GENERATE_SBOM=OFF
ninja
ninja install
finish_package
find /opt/qt6 \( -name '*Location*.prl' -o -name '*Positioning*.prl' \) \
  -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' '{}' \;

# Keep X11 support, but do not install an SDDM Wayland session or run a shell.
extract_package plasma-workspace-6.4.4.tar.xz plasma-workspace-6.4.4
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA5=plasma-workspace\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_QT5=OFF \
  -D BUILD_TESTING=OFF \
  -D INSTALL_SDDM_WAYLAND_SESSION=OFF \
  -D WITH_X11=ON \
  -W no-dev ..
ninja
ninja install
finish_package
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA5_BUILT=' "$PROGRESS")" -eq 2 ]]

printf 'PLASMA5_POSTCHECK=qtlocation\n'
for path in \
  /opt/qt6/lib/libQt6Location.so \
  /opt/qt6/lib/libQt6Positioning.so \
  /opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake; do
  [[ -e "$path" ]]
done
printf 'PLASMA5_POSTCHECK=workspace-files\n'
for path in \
  /opt/kf6/bin/plasmashell \
  /opt/kf6/bin/plasmawindowed \
  /opt/kf6/bin/krunner \
  /opt/kf6/bin/ksmserver \
  /opt/kf6/bin/startplasma-x11 \
  /opt/kf6/bin/startplasma-wayland \
  /opt/kf6/lib/libkworkspace6.so \
  /opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake \
  /opt/kf6/include/kworkspace6/autostartscriptdesktopfile.h \
  /opt/kf6/bin/kwin_x11 \
  /opt/kf6/bin/kwin_wayland; do
  [[ -e "$path" ]]
done
[[ ! -d /opt/kf6/lib/systemd ]]
for program in \
  /opt/kf6/bin/plasmashell \
  /opt/kf6/bin/plasmawindowed \
  /opt/kf6/bin/krunner \
  /opt/kf6/bin/ksmserver \
  /opt/kf6/bin/startplasma-x11 \
  /opt/kf6/bin/startplasma-wayland; do
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

# Do not execute plasmashell or startplasma. In this exact source ShellCorona
# is constructed before plasmashell processes --version. Exercise only Qt
# Location/Positioning and a side-effect-free LibKWorkspace path query: no
# provider, shell, session, compositor, D-Bus, audio, camera or network.
rm -rf /tmp/blfs-plasma5-smoke /tmp/blfs-plasma5-smoke-build \
  /tmp/blfs-plasma5-smoke-home /tmp/blfs-plasma5-runtime \
  /tmp/blfs-plasma5-smoke-stderr.log
mkdir -p /tmp/blfs-plasma5-smoke /tmp/blfs-plasma5-smoke-home/.config \
  /tmp/blfs-plasma5-smoke-home/.cache /tmp/blfs-plasma5-smoke-home/.local/share
install -d -m0700 /tmp/blfs-plasma5-runtime
cat >/tmp/blfs-plasma5-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma5_smoke LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Positioning Location)
find_package(KF6CoreAddons 6.17 REQUIRED)
find_package(KF6Config 6.17 REQUIRED)
find_package(LibKWorkspace 6.4.4 REQUIRED CONFIG)
add_executable(blfs-plasma5-smoke main.cpp)
target_link_libraries(blfs-plasma5-smoke PRIVATE
  Qt6::Core Qt6::Positioning Qt6::Location
  KF6::CoreAddons KF6::ConfigCore PW::KWorkspace)
EOF
cat >/tmp/blfs-plasma5-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <QDir>
#include <QGeoCoordinate>
#include <QGeoServiceProvider>
#include <QString>
#include <autostartscriptdesktopfile.h>
#include <cstdio>
#include <typeinfo>
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QGeoCoordinate coordinate(1.25, 2.5);
    if (!coordinate.isValid())
        return 1;
    if (typeid(QGeoServiceProvider).name() == nullptr)
        return 2;
    const QDir autostart = AutostartScriptDesktopFile::autostartLocation();
    if (!autostart.isAbsolute() || autostart.dirName() != QStringLiteral("autostart"))
        return 3;
    std::printf("BLFS_PLASMA5_EXEC_OK=%s=geo-coordinate=location-type=kworkspace-autostart-path\n", qVersion());
    return 0;
}
EOF
cmake -S /tmp/blfs-plasma5-smoke -B /tmp/blfs-plasma5-smoke-build -G Ninja \
  -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma5-smoke-build
for library in libkworkspace6.so libQt6Location.so libQt6Positioning.so; do
  readelf -d /tmp/blfs-plasma5-smoke-build/blfs-plasma5-smoke | grep -q "$library"
done
set +e
OUTPUT="$(env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
  HOME=/tmp/blfs-plasma5-smoke-home TERM=xterm LC_ALL=C.UTF-8 \
  QT_QPA_PLATFORM=offscreen NO_AT_BRIDGE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma5-runtime \
  XDG_CONFIG_HOME=/tmp/blfs-plasma5-smoke-home/.config \
  XDG_CACHE_HOME=/tmp/blfs-plasma5-smoke-home/.cache \
  XDG_DATA_HOME=/tmp/blfs-plasma5-smoke-home/.local/share \
  XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib \
  /tmp/blfs-plasma5-smoke-build/blfs-plasma5-smoke \
  2>/tmp/blfs-plasma5-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma5-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA5_EXEC_OK=6.9.2=geo-coordinate=location-type=kworkspace-autostart-path ]]
readelf -h /tmp/blfs-plasma5-smoke-build/blfs-plasma5-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma5-smoke-build/blfs-plasma5-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]

{
  printf 'BLFS_PLASMA5_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA5_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=qtlocation+plasma-workspace\n'
  printf 'QTLOCATION=6.9.2\nPLASMA_WORKSPACE=6.4.4\n'
  printf 'QT_LOCATION_SMOKE=native-coordinate-and-location-type-no-provider\n'
  printf 'KWORKSPACE_SMOKE=native-autostart-path-no-file-or-session\n'
  printf 'NATIVE_SMOKE=cmake-targets+execution-no-shell-or-session\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA4=preserved-pipeline-178\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMA=workspace-built-not-running\nPLASMASHELL=built-not-started\nSTARTPLASMA=built-not-run\n'
  printf 'PLASMA_SHELL=not-started\nPLASMA_DESKTOP=not-built\nCOMPOSITOR=not-started\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nSMOKE_NETWORK=not-used\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma5-smoke /tmp/blfs-plasma5-smoke-build \
  /tmp/blfs-plasma5-smoke-home /tmp/blfs-plasma5-runtime \
  /tmp/blfs-plasma5-smoke-stderr.log
