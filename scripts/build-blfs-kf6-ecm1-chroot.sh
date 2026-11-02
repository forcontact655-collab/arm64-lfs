#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-ecm1-report.txt
PROGRESS=/root/blfs-kf6-ecm1-progress.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/patch ]]
[[ -x "$QT6PREFIX/bin/qmake6" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake" ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=extra-cmake-modules-6.17.0.tar.xz
PATCH=extra-cmake-modules-6.17.0-upstream_fix-1.patch
[[ -f "$SOURCES/$ARCHIVE" ]]
[[ -f "$SOURCES/$PATCH" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == extra-cmake-modules-6.17.0 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
patch -Np1 -i "$SOURCES/$PATCH"
sed -i '/"lib64"/s/64//' kde-modules/KDEInstallDirsCommon.cmake
sed -e '/PACKAGE_INIT/i set(SAVE_PACKAGE_PREFIX_DIR "${PACKAGE_PREFIX_DIR}")' \
    -e '/^include/a set(PACKAGE_PREFIX_DIR "${SAVE_PACKAGE_PREFIX_DIR}")' \
    -i ECMConfig.cmake.in
mkdir build
cd build
printf 'BUILD_BLFS_KF6_ECM1=extra-cmake-modules\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_WITH_QT6=ON \
  -D BUILD_DOC=OFF \
  -D BUILD_TESTING=OFF \
  ..
ninja
ninja install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_KF6_ECM1_BUILT=extra-cmake-modules-6.17.0\n' >>"$PROGRESS"
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_KF6_ECM1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /usr/share/ECM/modules/ECMSetupVersion.cmake ]]
[[ -f /usr/share/ECM/kde-modules/KDEInstallDirs.cmake ]]

rm -rf /tmp/blfs-kf6-ecm1-smoke /tmp/blfs-kf6-ecm1-smoke-build
mkdir -p /tmp/blfs-kf6-ecm1-smoke
cat >/tmp/blfs-kf6-ecm1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_ecm1_smoke VERSION 1.0.0 LANGUAGES CXX)
set(PACKAGE_PREFIX_DIR "/opt/kf6")
find_package(ECM 6.17.0 REQUIRED NO_MODULE)
if(NOT PACKAGE_PREFIX_DIR STREQUAL "/opt/kf6")
  message(FATAL_ERROR "ECM changed PACKAGE_PREFIX_DIR to ${PACKAGE_PREFIX_DIR}")
endif()
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(ECMSetupVersion)
if(NOT KDE_INSTALL_LIBDIR STREQUAL "lib")
  message(FATAL_ERROR "Unexpected KDE_INSTALL_LIBDIR=${KDE_INSTALL_LIBDIR}")
endif()
ecm_setup_version(PROJECT
  VARIABLE_PREFIX BLFS_ECM
  VERSION_HEADER "${CMAKE_CURRENT_BINARY_DIR}/blfs_ecm_version.h"
)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core)
add_executable(blfs-kf6-ecm1-smoke main.cpp)
target_include_directories(blfs-kf6-ecm1-smoke PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(blfs-kf6-ecm1-smoke PRIVATE Qt6::Core)
EOF
cat >/tmp/blfs-kf6-ecm1-smoke/main.cpp <<'EOF'
#include <QtGlobal>
#include <cstdio>
#include <cstring>
#include "blfs_ecm_version.h"
int main() {
  if (std::strcmp(BLFS_ECM_VERSION_STRING, "1.0.0") != 0) return 1;
  if (BLFS_ECM_VERSION_MAJOR != 1 || BLFS_ECM_VERSION_MINOR != 0) return 2;
  std::printf("BLFS_KF6_ECM1_EXEC_OK=%s=%s\n", qVersion(), BLFS_ECM_VERSION_STRING);
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-ecm1-smoke -B /tmp/blfs-kf6-ecm1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-kf6-ecm1-smoke-build
OUTPUT="$(/tmp/blfs-kf6-ecm1-smoke-build/blfs-kf6-ecm1-smoke)"
[[ "$OUTPUT" == BLFS_KF6_ECM1_EXEC_OK=6.9.2=1.0.0 ]]
readelf -h /tmp/blfs-kf6-ecm1-smoke-build/blfs-kf6-ecm1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-ecm1-smoke-build/blfs-kf6-ecm1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_KF6_ECM1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_ECM1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\n'
  printf 'ECM=6.17.0\n'
  printf 'ECM_SMOKE=%s\n' "$OUTPUT"
  printf 'PACKAGE_PREFIX_DIR=preserved\n'
  printf 'KDE_INSTALL_LIBDIR=lib\n'
  printf 'KDE=ecm-only\n'
  printf 'KDE_FRAMEWORKS=absent\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-ecm1-smoke /tmp/blfs-kf6-ecm1-smoke-build
