#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma1-report.txt
PROGRESS=/root/blfs-plasma1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake \
  /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Package/KF6PackageConfig.cmake \
  /opt/kf6/lib/cmake/KF6Kirigami/KF6KirigamiConfig.cmake; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake; do
  [[ ! -e "$path" ]]
done
: >"$PROGRESS"
packages=(kdecoration libkscreen libksysguard breeze breeze-gtk layer-shell-qt plasma-activities libplasma)
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
  printf 'BUILD_BLFS_PLASMA1=%s\n' "$name"
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
    -W no-dev ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_PLASMA1_BUILT=%s-6.4.4\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA1_BUILT=' "$PROGRESS")" -eq 8 ]]
for path in \
  /opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake; do
  [[ -e "$path" ]]
done
rm -rf /tmp/blfs-plasma1-smoke /tmp/blfs-plasma1-smoke-build \
  /tmp/blfs-plasma1-runtime /tmp/blfs-plasma1-config /tmp/blfs-plasma1-smoke-stderr.log
mkdir -p /tmp/blfs-plasma1-smoke /tmp/blfs-plasma1-config
cat >/tmp/blfs-plasma1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KDecoration3 6.4.4 REQUIRED CONFIG)
find_package(PlasmaActivities 6.4.4 REQUIRED CONFIG)
find_package(Plasma 6.4.4 REQUIRED CONFIG)
add_executable(blfs-plasma1-smoke main.cpp)
target_link_libraries(blfs-plasma1-smoke PRIVATE Qt6::Core Qt6::Gui Plasma::Activities KDecoration3::KDecoration Plasma::Plasma)
EOF
cat >/tmp/blfs-plasma1-smoke/main.cpp <<'EOF'
#include <QGuiApplication>
#include <QMarginsF>
#include <QString>
#include <KDecoration3/Decoration>
#include <Plasma/Theme>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-plasma1-smoke"));
  KDecoration3::DecorationState state;
  state.setBorders(QMarginsF(1.0, 2.0, 3.0, 4.0));
  if (state.borders() != QMarginsF(1.0, 2.0, 3.0, 4.0)) return 1;
  Plasma::Theme theme(QStringLiteral("default"));
  if (theme.themeName() != QStringLiteral("default")) return 2;
  std::printf("BLFS_PLASMA1_EXEC_OK=%s=6.4.4=default\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma1-smoke -B /tmp/blfs-plasma1-smoke-build -G Ninja \
  -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma1-smoke-build
install -d -m 0700 /tmp/blfs-plasma1-runtime
set +e
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-plasma1-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma1-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib \
  /tmp/blfs-plasma1-smoke-build/blfs-plasma1-smoke 2>/tmp/blfs-plasma1-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma1-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA1_EXEC_OK=6.9.2=6.4.4=default ]]
readelf -h /tmp/blfs-plasma1-smoke-build/blfs-plasma1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma1-smoke-build/blfs-plasma1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA1_RESULT=ok\nPACKAGE_COUNT=8\nSOURCE_COUNT=8\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA1_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=kdecoration+libkscreen+libksysguard+breeze+breeze-gtk+layer-shell-qt+plasma-activities+libplasma\n'
  printf 'KDECORATION=6.4.4\nLIBKSCREEN=6.4.4\nLIBKSYSGUARD=6.4.4\nBREEZE=6.4.4\nBREEZE_GTK=6.4.4\nLAYER_SHELL_QT=6.4.4\nPLASMA_ACTIVITIES=6.4.4\nLIBPLASMA=6.4.4\n'
  printf 'NATIVE_SMOKE=cmake-targets+decoration-state+plasma-theme-offscreen\nTEST_SUITES=not-run-BUILD_TESTING_OFF\nACTIVITIES_RUNTIME=not-tested-no-service\n'
  printf 'PLASMA=core-libraries-built-not-running\nPLASMA_DESKTOP=not-built\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma1-smoke /tmp/blfs-plasma1-smoke-build \
  /tmp/blfs-plasma1-runtime /tmp/blfs-plasma1-config /tmp/blfs-plasma1-smoke-stderr.log
