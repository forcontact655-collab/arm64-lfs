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
REPORT=/root/blfs-plasma27-report.txt
PROGRESS=/root/blfs-plasma27-progress.txt
SCANNER_CONFIG=/root/blfs-plasma27-scanner-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/gzip ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake \
  /opt/kf6/lib/cmake/KF6Prison/KF6PrisonConfig.cmake \
  /opt/kf6/lib/libKF6Prison.so \
  /usr/include/qrencode.h \
  /opt/kf6/lib/liboxygenstyle6.so.6.4.4; do
  [[ -e "$path" ]]
done
for path in \
  /usr/lib/libZXing.so \
  /usr/lib/cmake/ZXing/ZXingConfig.cmake \
  /opt/kf6/lib/libKF6PrisonScanner.so \
  /opt/kf6/lib/libKF6PrisonScanner.so.6.17.0 \
  /opt/kf6/bin/spectacle; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
: >"$SCANNER_CONFIG"
extract_package() {
  local archive="$1" expected="$2" first top
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  top="${first%%/*}"; top="${top#./}"
  [[ "$top" == "$expected" ]]
  rm -rf "$SOURCES/$expected"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$expected"
}
printf 'BUILD_BLFS_PLASMA27=zxing-cpp\n'
extract_package zxing-cpp-2.3.0.tar.gz zxing-cpp-2.3.0
mkdir build
cd build
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_SHARED_LIBS=ON \
  -D ZXING_READERS=ON \
  -D ZXING_WRITERS=ON \
  -D ZXING_EXAMPLES=OFF \
  -D ZXING_UNIT_TESTS=OFF \
  -D ZXING_BLACKBOX_TESTS=OFF \
  -D ZXING_PYTHON_MODULE=OFF \
  -D ZXING_C_API=OFF \
  -D ZXING_DEPENDENCIES=LOCAL \
  -W no-dev ..
grep -E '^(ZXING_READERS|ZXING_WRITERS|ZXING_EXAMPLES|ZXING_UNIT_TESTS|ZXING_DEPENDENCIES|CMAKE_INSTALL_PREFIX)' CMakeCache.txt >>"$SCANNER_CONFIG"
grep -qx 'ZXING_WRITERS:STRING=ON' "$SCANNER_CONFIG"
grep -qx 'ZXING_EXAMPLES:BOOL=OFF' "$SCANNER_CONFIG"
ninja -j2
ninja install
cd /sources
rm -rf zxing-cpp-2.3.0
printf 'BLFS_PLASMA27_BUILT=zxing-cpp-2.3.0\n' >>"$PROGRESS"

printf 'BUILD_BLFS_PLASMA27=prison-scanner\n'
extract_package prison-6.17.0.tar.xz prison-6.17.0
mkdir build
cd build
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -D BUILD_PYTHON_BINDINGS=OFF \
  -D WITH_QUICK=ON \
  -D WITH_MULTIMEDIA=ON \
  -W no-dev ..
grep -q 'KF6PrisonScanner' build.ninja
grep -E '^(WITH_QUICK|WITH_MULTIMEDIA|ZXing_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt >>"$SCANNER_CONFIG"
{
  printf 'PRISON_SCANNER_RUNTIME=not-started\nCAMERA=not-accessed\nSPECTACLE=not-built-in-this-stage\n'
} >>"$SCANNER_CONFIG"
grep -qx 'WITH_MULTIMEDIA:BOOL=ON' "$SCANNER_CONFIG"
grep -qx 'PRISON_SCANNER_RUNTIME=not-started' "$SCANNER_CONFIG"
grep -qx 'CAMERA=not-accessed' "$SCANNER_CONFIG"
ninja -j2
ninja install
cd /sources
rm -rf prison-6.17.0
printf 'BLFS_PLASMA27_BUILT=prison-6.17.0-with-scanner\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA27_BUILT=' "$PROGRESS")" -eq 2 ]]
ZXING_LIBRARY=/usr/lib/libZXing.so.2.3.0
PRISON_LIBRARY=/opt/kf6/lib/libKF6Prison.so.6.17.0
SCANNER_LIBRARY=/opt/kf6/lib/libKF6PrisonScanner.so.6.17.0
for path in \
  "$ZXING_LIBRARY" "$PRISON_LIBRARY" "$SCANNER_LIBRARY" \
  /usr/lib/cmake/ZXing/ZXingConfig.cmake \
  /opt/kf6/lib/cmake/KF6Prison/KF6PrisonTargets.cmake; do
  [[ -f "$path" ]]
done
grep -q 'KF6::PrisonScanner' /opt/kf6/lib/cmake/KF6Prison/KF6PrisonTargets.cmake
for elf in "$ZXING_LIBRARY" "$PRISON_LIBRARY" "$SCANNER_LIBRARY"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
readelf -d "$SCANNER_LIBRARY" | grep -q 'Shared library: \[libZXing.so.3\]'
[[ ! -e /opt/kf6/bin/spectacle ]]
printf 'PLASMA27_POSTCHECK=zxing-prison-scanner-three-libraries-not-executed\n'
{
  printf 'BLFS_PLASMA27_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-zxing-prison-or-scanner\nNEW_EXECUTABLES=none-libraries-only\nELF_ARCH=AArch64\nDYNAMIC_LINKER=not-applicable-shared-libraries-only\n'
  printf 'PACKAGES=zxing-cpp+prison\nZXING=2.3.0\nPRISON=6.17.0\nELF_FILE_COUNT=3\n'
  printf 'ZXING_READERS=ON\nZXING_WRITERS=ON\nZXING_EXAMPLES=OFF\nPRISON_CORE=rebuilt-with-scanner\nPRISON_SCANNER=installed-not-run\nSCANNER_RUNTIME=not-started\n'
  printf 'SPECTACLE=deferred-ready-for-next-stage\nPLASMA25=failed-pipeline-215-cmake-no-install\nPLASMA26=failed-pipeline-216-zxing-writers-off-missing-bitmatrix\n'
  printf 'PLASMA24=preserved-pipeline-214\nOXYGEN=preserved-pipeline-214-not-applied\nPLASMA23=preserved-pipeline-213\nSOUND_THEMES=preserved-pipeline-213-not-played\n'
  printf 'PLASMA22=preserved-pipeline-211\nPLASMA21=preserved-pipeline-210\nPLASMA20=preserved-pipeline-209\n'
  printf 'WACOMTABLET=deferred-requires-xorg-wacom\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'TEST_SUITES=not-run\nNETWORK=not-used-by-build-or-built-programs\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
