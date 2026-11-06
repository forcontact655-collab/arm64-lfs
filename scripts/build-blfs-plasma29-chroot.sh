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
REPORT=/root/blfs-plasma29-report.txt
PROGRESS=/root/blfs-plasma29-progress.txt
SPECTACLE_CONFIG=/root/blfs-plasma29-spectacle-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/gzip ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/KPipeWire/KPipeWireConfig.cmake \
  /opt/kf6/lib/cmake/LayerShellQt/LayerShellQtConfig.cmake \
  /opt/kf6/lib/cmake/KF6Prison/KF6PrisonConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake \
  /opt/kf6/lib/libKF6PrisonScanner.so.6.17.0 \
  /usr/lib/libZXing.so.2.3.0 \
  /usr/lib/cmake/opencv4/OpenCVConfig.cmake \
  /opt/kf6/lib/liboxygenstyle6.so.6.4.4 \
  /opt/kf6/share/sounds/oxygen/index.theme; do
  [[ -e "$path" ]]
done
SPECTACLE=/opt/kf6/bin/spectacle
KCONF_DIR=/opt/kf6/lib/kconf_update_bin
KCONF_TOOLS=(
  spectacle-24.02.0-video_format
  spectacle-24.02.0-keep_old_save_location
  spectacle-24.02.0-rename_settings
  spectacle-24.02.0-keep_old_filename_templates
  spectacle-24.02.0-change_placeholder_format
)
for path in "$SPECTACLE" \
  /opt/kf6/share/applications/org.kde.spectacle.desktop \
  /opt/kf6/share/dbus-1/services/org.kde.spectacle.service \
  /opt/kf6/share/dbus-1/services/org.kde.Spectacle.service \
  /opt/kf6/share/dbus-1/interfaces/org.kde.Spectacle.xml \
  /opt/kf6/share/kconf_update/spectacle.upd; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
for tool in "${KCONF_TOOLS[@]}"; do [[ ! -e "$KCONF_DIR/$tool" ]]; done
grep -q 'KF6::PrisonScanner' /opt/kf6/lib/cmake/KF6Prison/KF6PrisonTargets.cmake
: >"$PROGRESS"
printf 'BUILD_BLFS_PLASMA29=spectacle\n'
archive=spectacle-6.4.4.tar.xz
package=spectacle-6.4.4
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
top="${first%%/*}"; top="${top#./}"
[[ "$top" == "$package" ]]
rm -rf "$SOURCES/$package"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
cd "$SOURCES/$package"
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
  -W no-dev ..
grep -q 'spectacle-24.02.0-video_format' build.ninja
grep -q 'Gui/SpectacleWindow.qml' build.ninja
{
  grep -E '^(BUILD_TESTING|CMAKE_INSTALL_PREFIX|KPipeWire_DIR|OpenCV_DIR|Qt6Multimedia_DIR)' CMakeCache.txt
  printf 'SPECTACLE_RUNTIME=not-started\nSCREENSHOT=not-captured\nSCREEN_RECORDING=not-started\nKCONF_UPDATE_TOOLS=not-executed\n'
} >"$SPECTACLE_CONFIG"
grep -qx 'BUILD_TESTING:BOOL=OFF' "$SPECTACLE_CONFIG"
grep -qx 'SPECTACLE_RUNTIME=not-started' "$SPECTACLE_CONFIG"
grep -qx 'SCREENSHOT=not-captured' "$SPECTACLE_CONFIG"
grep -qx 'SCREEN_RECORDING=not-started' "$SPECTACLE_CONFIG"
grep -qx 'KCONF_UPDATE_TOOLS=not-executed' "$SPECTACLE_CONFIG"
ninja -j2
ninja install
cd /sources
rm -rf "$package"
printf 'BLFS_PLASMA29_BUILT=spectacle-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA29_BUILT=' "$PROGRESS")" -eq 1 ]]
for tool in "${KCONF_TOOLS[@]}"; do [[ -f "$KCONF_DIR/$tool" ]]; done
for path in \
  /opt/kf6/share/applications/org.kde.spectacle.desktop \
  /opt/kf6/share/dbus-1/services/org.kde.spectacle.service \
  /opt/kf6/share/dbus-1/services/org.kde.Spectacle.service \
  /opt/kf6/share/dbus-1/interfaces/org.kde.Spectacle.xml \
  /opt/kf6/share/kconf_update/spectacle.upd \
  /opt/kf6/share/metainfo/org.kde.spectacle.appdata.xml; do
  [[ -f "$path" ]]
done
[[ -L /opt/kf6/share/kglobalaccel/org.kde.spectacle.desktop ]]
for elf in "$SPECTACLE" "${KCONF_TOOLS[@]/#/$KCONF_DIR/}"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$SPECTACLE" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
printf 'PLASMA29_POSTCHECK=spectacle-six-elf-files-static-services-not-executed\n'
{
  printf 'BLFS_PLASMA29_RESULT=ok\nPACKAGE_COUNT=1\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-spectacle-or-kconf-update-tools\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=spectacle\nSPECTACLE=6.4.4\nELF_FILE_COUNT=6\nBUILD_TESTING=OFF\n'
  printf 'SPECTACLE_RUNTIME=not-started\nQML_UI=not-started\nSCREENSHOT=not-captured\nSCREEN_RECORDING=not-started\nPIPEWIRE_STREAM=not-started\n'
  printf 'KPIPEWIRE_RECORD=build-dependency-no-stream\nXCB_BACKEND=compiled-not-used\nKCONF_UPDATE_TOOLS=installed-not-executed\nDBUS_SERVICES=installed-not-activated\n'
  printf 'WACOMTABLET=deferred-requires-xorg-wacom\nTEST_SUITES=not-run\nNETWORK=not-used-by-built-programs\n'
  printf 'PLASMA28=failed-pipeline-218-restore-key-mismatch-no-install\n'
  printf 'PLASMA27=preserved-pipeline-217\nZXING=preserved-pipeline-217\nPRISON_SCANNER=preserved-pipeline-217-not-run\n'
  printf 'PLASMA26=failed-pipeline-216-zxing-writers-off-missing-bitmatrix\nPLASMA25=failed-pipeline-215-cmake-no-install\n'
  printf 'PLASMA24=preserved-pipeline-214\nOXYGEN=preserved-pipeline-214-not-applied\nPLASMA23=preserved-pipeline-213\nSOUND_THEMES=preserved-pipeline-213-not-played\n'
  printf 'PLASMA22=preserved-pipeline-211\nKDEPLASMA_ADDONS=preserved-pipeline-211-not-loaded\nPLASMA_WELCOME=preserved-pipeline-211-not-opened\n'
  printf 'PLASMA21=preserved-pipeline-210\nBLUEDEVIL=preserved-pipeline-210-not-started\nPLASMA20=preserved-pipeline-209\n'
  printf 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nSDDM=preserved-not-started\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
