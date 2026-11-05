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
REPORT=/root/blfs-plasma4-report.txt
PROGRESS=/root/blfs-plasma4-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config && -x /usr/bin/meson ]]
[[ -x /usr/bin/Xvfb && -x /opt/qt6/bin/qt-configure-module ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake \
  /opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake \
  /opt/kf6/lib/cmake/KGlobalAccelD/KGlobalAccelDConfig.cmake \
  /opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6NewStuff/KF6NewStuffConfig.cmake \
  /opt/kf6/lib/cmake/KF6Declarative/KF6DeclarativeConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake \
  /opt/qt6/lib/cmake/Qt6UiTools/Qt6UiToolsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake \
  /usr/lib/liblcms2.so \
  /usr/lib/libcanberra.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake \
  /usr/lib/libinput.so \
  /opt/kf6/bin/kwin_x11 \
  /opt/kf6/bin/kwin_wayland \
  /opt/kf6/lib/cmake/KWinX11/KWinX11Config.cmake \
  /opt/kf6/lib/cmake/KWin/KWinConfig.cmake; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
pkg-config --atleast-version=2.4.118 libdrm
pkg-config --atleast-version=1.44 wayland-protocols
pkg-config --atleast-version=0.2.0 libdisplay-info
pkg-config --atleast-version=0.1.1 libxcvt
pkg-config --atleast-version=1.0.9 libpipewire-0.3
pkg-config --exists gbm lcms2 xkbcommon-x11
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
  printf 'BLFS_PLASMA4_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}

# KWin requires QtSensors, which was not needed by the earlier Qt stages.
extract_package qtsensors-everywhere-src-6.9.2.tar.xz qtsensors-everywhere-src-6.9.2
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA4=qtsensors\n'
/opt/qt6/bin/qt-configure-module "$SOURCES/$EXTRACTED_DIR" -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_BUILD_EXAMPLES=OFF \
  -DQT_BUILD_TESTS=OFF \
  -DQT_BUILD_MANUAL_TESTS=OFF \
  -DQT_GENERATE_SBOM=OFF
ninja
ninja install
finish_package
find /opt/qt6 -name '*Sensors*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;

# BLFS 12.4's libinput build: no hardware tests, GUI or libwacom backend.
extract_package libinput-1.29.0.tar.gz libinput-1.29.0
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA4=libinput\n'
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D debug-gui=false \
  -D tests=false \
  -D libwacom=false \
  -D udev-dir=/usr/lib/udev
ninja
ninja install
finish_package
[[ "$(pkg-config --modversion libinput)" == 1.29.0 ]]

# Preserve BLFS's internal package order: the X11 split precedes Wayland KWin.
for name in kwin-x11 kwin; do
  extract_package "$name-6.4.4.tar.xz" "$name-6.4.4"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA4=%s\n' "$name"
  extra=()
  if [[ "$name" == kwin-x11 ]]; then
    extra=(-D KWIN_BUILD_X11_BACKEND=ON)
  fi
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -D KWIN_BUILD_X11=ON \
    -D KWIN_BUILD_KCMS=ON \
    "${extra[@]}" \
    -W no-dev ..
  ninja
  ninja install
  finish_package
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA4_BUILT=' "$PROGRESS")" -eq 4 ]]
printf 'PLASMA4_POSTCHECK=dependency-versions\n'
[[ "$(pkg-config --modversion libinput)" == 1.29.0 ]]
pkg-config --atleast-version=1.26 libinput
printf 'PLASMA4_POSTCHECK=config-files-programs-libraries\n'
for path in \
  /opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake \
  /opt/qt6/lib/libQt6Sensors.so \
  /usr/lib/libinput.so \
  /usr/bin/libinput \
  /opt/kf6/bin/kwin_x11 \
  /opt/kf6/bin/kwin_wayland \
  /opt/kf6/bin/kwin_wayland_wrapper \
  /opt/kf6/lib/libkwin-x11.so \
  /opt/kf6/lib/libkwin.so \
  /opt/kf6/lib/cmake/KWinX11/KWinX11Config.cmake \
  /opt/kf6/lib/cmake/KWin/KWinConfig.cmake \
  /opt/kf6/lib/cmake/KWinX11DBusInterface/KWinX11DBusInterfaceConfig.cmake \
  /opt/kf6/lib/cmake/KWinDBusInterface/KWinDBusInterfaceConfig.cmake; do
  [[ -e "$path" ]]
done
for program in /opt/kf6/bin/kwin_x11 /opt/kf6/bin/kwin_wayland; do
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

# Native dependency smoke: construct a device-free libinput context and
# reference QtSensors RTTI. No input device or sensor backend is accessed.
rm -rf /tmp/blfs-plasma4-smoke /tmp/blfs-plasma4-smoke-build /tmp/blfs-plasma4-smoke-stderr.log
mkdir -p /tmp/blfs-plasma4-smoke
cat >/tmp/blfs-plasma4-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma4_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Sensors)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBINPUT REQUIRED IMPORTED_TARGET libinput>=1.26)
add_executable(blfs-plasma4-smoke main.cpp)
target_link_libraries(blfs-plasma4-smoke PRIVATE Qt6::Core Qt6::Sensors PkgConfig::LIBINPUT)
EOF
cat >/tmp/blfs-plasma4-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <QSensor>
#include <libinput.h>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <typeinfo>
static int open_restricted(const char *, int, void *) {
  errno = ENOSYS;
  return -1;
}
static void close_restricted(int, void *) {}
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  libinput_interface interface{open_restricted, close_restricted};
  libinput *input = libinput_new(&interface, nullptr);
  if (!input) return 1;
  libinput_unref(input);
  if (std::strcmp(typeid(QSensor).name(), "") == 0) return 2;
  std::printf("BLFS_PLASMA4_EXEC_OK=%s=libinput-context=sensors-type\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma4-smoke -B /tmp/blfs-plasma4-smoke-build -G Ninja \
  -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma4-smoke-build
set +e
OUTPUT="$(QT_QPA_PLATFORM=offscreen LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib \
  /tmp/blfs-plasma4-smoke-build/blfs-plasma4-smoke 2>/tmp/blfs-plasma4-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma4-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA4_EXEC_OK=6.9.2=libinput-context=sensors-type ]]
readelf -h /tmp/blfs-plasma4-smoke-build/blfs-plasma4-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma4-smoke-build/blfs-plasma4-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]

# Execute only --version. kwin_x11 gets a disposable Xvfb because it forces
# Qt's xcb plugin before parsing options. Neither window manager is started.
install -d -m1777 /tmp/.ICE-unix /tmp/.X11-unix
rm -rf /tmp/blfs-plasma4-home /tmp/blfs-plasma4-runtime
mkdir -p /tmp/blfs-plasma4-home/.config /tmp/blfs-plasma4-home/.cache
install -d -m0700 /tmp/blfs-plasma4-runtime
rm -f /tmp/blfs-plasma4-display /tmp/blfs-plasma4-xvfb.log \
  /tmp/blfs-plasma4-kwin-x11-stderr.log /tmp/blfs-plasma4-kwin-wayland-stderr.log
XVFB_PID=''
cleanup_version_smoke() {
  set +e
  if [[ -n "$XVFB_PID" ]]; then
    kill "$XVFB_PID" 2>/dev/null
    wait "$XVFB_PID" 2>/dev/null
    XVFB_PID=''
  fi
  rm -rf /tmp/blfs-plasma4-home /tmp/blfs-plasma4-runtime
  rm -f /tmp/blfs-plasma4-display
  set -e
}
trap cleanup_version_smoke EXIT
LIBGL_ALWAYS_SOFTWARE=1 Xvfb -displayfd 3 -screen 0 640x480x24 -nolisten tcp -ac \
  3>/tmp/blfs-plasma4-display >/tmp/blfs-plasma4-xvfb.log 2>&1 &
XVFB_PID=$!
for _ in {1..100}; do
  [[ -s /tmp/blfs-plasma4-display ]] && break
  kill -0 "$XVFB_PID" 2>/dev/null || { cat /tmp/blfs-plasma4-xvfb.log; exit 1; }
  sleep 0.1
done
[[ -s /tmp/blfs-plasma4-display ]]
DISPLAY_NUMBER="$(cat /tmp/blfs-plasma4-display)"
[[ "$DISPLAY_NUMBER" =~ ^[0-9]+$ ]]
[[ -S "/tmp/.X11-unix/X$DISPLAY_NUMBER" ]]
SMOKE_ENV=(env HOME=/tmp/blfs-plasma4-home TERM=xterm LC_ALL=C.UTF-8 \
  LIBGL_ALWAYS_SOFTWARE=1 QT_QUICK_BACKEND=software NO_AT_BRIDGE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma4-runtime \
  XDG_CONFIG_HOME=/tmp/blfs-plasma4-home/.config \
  XDG_CACHE_HOME=/tmp/blfs-plasma4-home/.cache \
  XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib)
set +e
KWIN_X11_VERSION_OUTPUT="$("${SMOKE_ENV[@]}" DISPLAY=":$DISPLAY_NUMBER" \
  /opt/kf6/bin/kwin_x11 --version 2>/tmp/blfs-plasma4-kwin-x11-stderr.log)"
KWIN_X11_VERSION_STATUS=$?
KWIN_WAYLAND_VERSION_OUTPUT="$("${SMOKE_ENV[@]}" \
  /opt/kf6/bin/kwin_wayland --version 2>/tmp/blfs-plasma4-kwin-wayland-stderr.log)"
KWIN_WAYLAND_VERSION_STATUS=$?
set -e
cat /tmp/blfs-plasma4-kwin-x11-stderr.log
cat /tmp/blfs-plasma4-kwin-wayland-stderr.log
cat /tmp/blfs-plasma4-xvfb.log
printf 'KWIN_X11_VERSION_STATUS=%s\nKWIN_X11_VERSION_OUTPUT=%s\n' "$KWIN_X11_VERSION_STATUS" "$KWIN_X11_VERSION_OUTPUT"
printf 'KWIN_WAYLAND_VERSION_STATUS=%s\nKWIN_WAYLAND_VERSION_OUTPUT=%s\n' "$KWIN_WAYLAND_VERSION_STATUS" "$KWIN_WAYLAND_VERSION_OUTPUT"
[[ "$KWIN_X11_VERSION_STATUS" -eq 0 && "$KWIN_X11_VERSION_OUTPUT" == 'kwin 6.4.4' ]]
[[ "$KWIN_WAYLAND_VERSION_STATUS" -eq 0 && "$KWIN_WAYLAND_VERSION_OUTPUT" == 'kwin 6.4.4' ]]
cleanup_version_smoke
trap - EXIT
{
  printf 'BLFS_PLASMA4_RESULT=ok\nPACKAGE_COUNT=4\nSOURCE_COUNT=4\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA4_EXEC_OK+kwin-version\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=qtsensors+libinput+kwin-x11+kwin\n'
  printf 'QT_SENSORS=6.9.2\nLIBINPUT=1.29.0\nKWIN_X11=6.4.4\nKWIN_WAYLAND=6.4.4\n'
  printf 'QT_SENSORS_SMOKE=native-typeinfo-no-backend\nLIBINPUT_SMOKE=native-context-no-device\n'
  printf 'KWIN_X11_VERSION_STATUS=0\nKWIN_X11_VERSION_OUTPUT=%s\nKWIN_X11_SMOKE=native-version-under-Xvfb-no-window-manager-start\n' "$KWIN_X11_VERSION_OUTPUT"
  printf 'KWIN_WAYLAND_VERSION_STATUS=0\nKWIN_WAYLAND_VERSION_OUTPUT=%s\nKWIN_WAYLAND_SMOKE=native-version-no-compositor-start\n' "$KWIN_WAYLAND_VERSION_OUTPUT"
  printf 'QT_SENSORS_TEST_SUITE=not-run-QT_BUILD_TESTS_OFF\nLIBINPUT_TEST_SUITE=disabled-no-hardware-test-stack\nKWIN_TEST_SUITE=not-run-BUILD_TESTING_OFF\n'
  printf 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable\nINPUT_RUNTIME=not-tested-no-devices\nSENSOR_RUNTIME=not-tested-no-backend\n'
  printf 'PLASMA3=preserved-pipeline-176\nPLASMA=kwin-built-not-running\nKWIN=built-version-only-not-running\nCOMPOSITOR=not-started\nPLASMA_WORKSPACE=not-built\nPLASMA_DESKTOP=not-built\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma4-smoke /tmp/blfs-plasma4-smoke-build \
  /tmp/blfs-plasma4-smoke-stderr.log /tmp/blfs-plasma4-xvfb.log \
  /tmp/blfs-plasma4-kwin-x11-stderr.log /tmp/blfs-plasma4-kwin-wayland-stderr.log
