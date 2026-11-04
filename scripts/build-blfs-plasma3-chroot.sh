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
REPORT=/root/blfs-plasma3-report.txt
PROGRESS=/root/blfs-plasma3-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config && -x /usr/bin/meson ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake \
  /opt/kf6/lib/cmake/KGlobalAccelD/KGlobalAccelDConfig.cmake \
  /opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake \
  /opt/kf6/lib/cmake/Aurorae/AuroraeConfig.cmake \
  /usr/lib64/libpam.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivitiesStats/PlasmaActivitiesStatsConfig.cmake \
  /opt/kf6/lib/cmake/KPipeWire/KPipeWireConfig.cmake; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
# kpipewire has an unconditional pkg-config requirement on libva and
# libva-drm.  Build the BLFS 12.4 dependency before the Plasma sources.
libva_archive=libva-2.22.0.tar.gz
libva_dir=libva-2.22.0
[[ -f "$SOURCES/$libva_archive" ]]
first="$(tar -tf "$SOURCES/$libva_archive" | head -n1)" || true
[[ "${first%%/*}" == "$libva_dir" ]]
rm -rf "$SOURCES/$libva_dir"
tar -xf "$SOURCES/$libva_archive" -C "$SOURCES"
cd "$SOURCES/$libva_dir"
# BLFS uses the source's existing build/ directory (gen_version.sh lives there).
cd build
printf 'BUILD_BLFS_PLASMA3=libva\n'
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
cd /sources
rm -rf "$libva_dir"
printf 'BLFS_PLASMA3_BUILT=libva-2.22.0\n' >>"$PROGRESS"
/sbin/ldconfig
pkg-config --exists libva libva-drm
[[ "$(pkg-config --modversion libva)" == 1.22.0 ]]
[[ "$(pkg-config --modversion libva-drm)" == 1.22.0 ]]
packages=(plasma5support plasma-activities-stats kpipewire)
for name in "${packages[@]}"; do
  archive="$name-6.4.4.tar.xz"
  package_dir="$name-6.4.4"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  [[ "${first%%/*}" == "$package_dir" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA3=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D WITH_X11=ON \
    -W no-dev ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_PLASMA3_BUILT=%s-6.4.4\n' "$name" >>"$PROGRESS"
done
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA3_BUILT=' "$PROGRESS")" -eq 4 ]]
printf 'PLASMA3_POSTCHECK=libva-pkg-config\n'
pkg-config --exists libva libva-drm
[[ "$(pkg-config --modversion libva)" == 1.22.0 ]]
[[ "$(pkg-config --modversion libva-drm)" == 1.22.0 ]]
printf 'PLASMA3_POSTCHECK=config-files\n'
for path in \
  /opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivitiesStats/PlasmaActivitiesStatsConfig.cmake \
  /opt/kf6/lib/cmake/KPipeWire/KPipeWireConfig.cmake; do
  [[ -e "$path" ]]
done
printf 'PLASMA3_POSTCHECK=libraries-and-qml\n'
for path in \
  /opt/kf6/lib/libPlasma5Support.so \
  /opt/kf6/lib/libPlasmaActivitiesStats.so \
  /opt/kf6/lib/libKPipeWire.so \
  /opt/kf6/lib/qml/org/kde/pipewire/qmldir; do
  [[ -e "$path" ]]
done
# Native display-free smoke: version and RTTI only.  No PipeWire stream,
# compositor, locker, DBus service or Plasma shell is started.
rm -rf /tmp/blfs-plasma3-smoke /tmp/blfs-plasma3-smoke-build /tmp/blfs-plasma3-smoke-stderr.log
mkdir -p /tmp/blfs-plasma3-smoke
cat >/tmp/blfs-plasma3-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma3_smoke LANGUAGES CXX)
find_package(PkgConfig REQUIRED)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui DBus Quick OpenGL QmlIntegration)
find_package(KF6 6.17.0 REQUIRED COMPONENTS Config CoreAddons GuiAddons I18n Notifications Solid Service IdleTime KIO)
find_package(KSysGuard CONFIG)
find_package(KF6NetworkManagerQt CONFIG)
find_package(PlasmaActivities 6.4.4 REQUIRED CONFIG)
find_package(Plasma5Support 6.4.4 REQUIRED CONFIG)
find_package(PlasmaActivitiesStats 6.4.4 REQUIRED CONFIG)
find_package(KPipeWire 6.4.4 REQUIRED CONFIG)
find_package(Threads REQUIRED)
find_package(EGL REQUIRED)
find_package(epoxy 1.3 REQUIRED)
find_package(Libdrm 2.4.62 REQUIRED)
pkg_check_modules(PipeWire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(GBM IMPORTED_TARGET gbm REQUIRED)
pkg_check_modules(LIBVA IMPORTED_TARGET libva REQUIRED)
pkg_check_modules(LIBVA-drm IMPORTED_TARGET libva-drm REQUIRED)
add_executable(blfs-plasma3-smoke main.cpp)
target_include_directories(blfs-plasma3-smoke PRIVATE ${PipeWire_INCLUDE_DIRS})
target_link_libraries(blfs-plasma3-smoke PRIVATE
  Qt6::Core Qt6::Gui Plasma::Plasma5Support Plasma::ActivitiesStats K::KPipeWire PkgConfig::PipeWire)
EOF
cat >/tmp/blfs-plasma3-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <plasma5support/version.h>
#include <PlasmaActivities/Stats/ResultSet>
#include <PipeWireSourceStream>
#include <cstdio>
#include <cstring>
#include <typeinfo>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const char *version = Plasma5Support::versionString();
  if (!version || std::strcmp(version, "6.4.4") != 0) return 1;
  if (std::strcmp(typeid(KActivities::Stats::ResultSet).name(), "") == 0 ||
      std::strcmp(typeid(PipeWireSourceStream).name(), "") == 0) return 2;
  std::printf("BLFS_PLASMA3_EXEC_OK=%s=6.4.4=plasma5support=activities-stats=kpipewire-type\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma3-smoke -B /tmp/blfs-plasma3-smoke-build -G Ninja \
  -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma3-smoke-build
set +e
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-plasma3-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma3-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib \
  /tmp/blfs-plasma3-smoke-build/blfs-plasma3-smoke 2>/tmp/blfs-plasma3-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma3-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA3_EXEC_OK=6.9.2=6.4.4=plasma5support=activities-stats=kpipewire-type ]]
readelf -h /tmp/blfs-plasma3-smoke-build/blfs-plasma3-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma3-smoke-build/blfs-plasma3-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA3_RESULT=ok\nPACKAGE_COUNT=4\nSOURCE_COUNT=4\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA3_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=libva+plasma5support+plasma-activities-stats+kpipewire\n'
  printf 'LIBVA=2.22.0\nLIBVA_API=1.22.0\nPLASMA5SUPPORT=6.4.4\nPLASMA_ACTIVITIES_STATS=6.4.4\nKPIPEWIRE=6.4.4\n'
  printf 'LIBVA_SMOKE=pkg-config-libva-and-drm-no-hardware\nPLASMA5SUPPORT_SMOKE=native-version-string\nPLASMA_ACTIVITIES_STATS_SMOKE=native-typeinfo-no-database\nKPIPEWIRE_SMOKE=native-typeinfo-no-stream-no-session\n'
  printf 'NATIVE_SMOKE=cmake-targets+version+typeinfo-no-pipewire-session\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'PLASMA2=preserved-pipeline-171\nPLASMA=third-stage-libraries-built-not-running\nKWIN=not-built\nPLASMA_WORKSPACE=not-built\nPLASMA_DESKTOP=not-built\nPIPEWIRE_SESSION=not-tested\nPHONON_VLC=not-tested\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma3-smoke /tmp/blfs-plasma3-smoke-build \
  /tmp/blfs-plasma3-runtime /tmp/blfs-plasma3-config /tmp/blfs-plasma3-smoke-stderr.log
