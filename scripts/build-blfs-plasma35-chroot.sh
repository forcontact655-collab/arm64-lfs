#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma35-report.txt
PROGRESS=/root/blfs-plasma35-progress.txt
CONFIG=/root/blfs-plasma35-drkonqi-config.txt
MANIFEST=/root/blfs-plasma35-drkonqi-install-manifest.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config && -x /usr/bin/readelf ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
pkg-config --exists libsystemd
LIB_SYSTEMD_VERSION="$(pkg-config --modversion libsystemd)"
LIB_SYSTEMD_MAJOR="${LIB_SYSTEMD_VERSION%%.*}"
[[ "$LIB_SYSTEMD_MAJOR" =~ ^[0-9]+$ && "$LIB_SYSTEMD_MAJOR" -ge 254 ]]
[[ -e /usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake && -e /usr/lib/libpolkit-qt6-core-1.so ]]
for module in KF6I18n KF6CoreAddons KF6Config KF6Service KF6JobWidgets KF6KIO KF6Crash KF6WidgetsAddons KF6Wallet KF6Notifications KF6IdleTime KF6WindowSystem KF6SyntaxHighlighting KF6StatusNotifierItem; do
  [[ -e "/opt/kf6/lib/cmake/$module/${module}Config.cmake" ]]
done
for path in \
  /opt/kf6/lib/cmake/KF6Kirigami/KF6KirigamiConfig.cmake \
  /opt/kf6/lib/cmake/KF6ItemModels/KF6ItemModelsConfig.cmake \
  /opt/kf6/lib/qml/org/kde/kirigami/qmldir \
  /opt/kf6/lib/qml/org/kde/kitemmodels/qmldir \
  /opt/kf6/lib/qml/org/kde/syntaxhighlighting/qmldir; do
  [[ -e "$path" ]]
done
for path in /opt/kf6/libexec/drkonqi /opt/kf6/lib/libexec/drkonqi; do
  [[ ! -e "$path" ]]
done
: >"$PROGRESS"
ARCHIVE=/sources/drkonqi-6.4.4.tar.xz
[[ -f "$ARCHIVE" ]]
first="$(tar -tf "$ARCHIVE" | head -n1)" || true
[[ "${first%%/*}" == "drkonqi-6.4.4" ]]
rm -rf /sources/drkonqi-6.4.4
tar -xf "$ARCHIVE" -C /sources
cd /sources/drkonqi-6.4.4
printf 'BUILD_BLFS_PLASMA35=drkonqi\n'
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
  -D WITH_PYTHON_VENDORING=OFF \
  -W no-dev ..
TARGETS='drkonqi drkonqi-coredump-launcher drkonqi-coredump-processor drkonqi-coredump-gui drkonqi-coredump-cleanup drkonqi-polkit-helper'
for target in $TARGETS; do grep -q "$target" build.ninja; done
cp CMakeCache.txt "$CONFIG"
{
  printf '\nPROJECT=drkonqi\nPROJECT_VERSION=6.4.4\nREQUIRED_TARGETS=%s\n' "$TARGETS"
  printf 'LIB_SYSTEMD_VERSION=%s\n' "$LIB_SYSTEMD_VERSION"
  printf 'PYTHON_VENDORING=disabled-by-official-option\nBUILD_TESTING=OFF\n'
  printf 'COREDUMP_INTEGRATION=compiled\nSYSTEMD_UNITS=installed-not-enabled\n'
} >>"$CONFIG"
ninja -j2
ninja install
[[ -s install_manifest.txt ]]
cp install_manifest.txt "$MANIFEST"
cd /sources
rm -rf drkonqi-6.4.4
printf 'BLFS_PLASMA35_BUILT=drkonqi-6.4.4\n' >>"$PROGRESS"
/sbin/ldconfig
DRKONQI_BIN=''
for candidate in /opt/kf6/libexec/drkonqi /opt/kf6/lib/libexec/drkonqi; do
  if [[ -x "$candidate" ]]; then DRKONQI_BIN="$candidate"; break; fi
done
[[ -n "$DRKONQI_BIN" ]]
HELPER_PATHS=''
for name in drkonqi-coredump-launcher drkonqi-coredump-processor drkonqi-coredump-gui drkonqi-coredump-cleanup drkonqi-polkit-helper; do
  helper_path="$(grep -E "^/opt/kf6/(bin|libexec|libexec/kf6)/${name}\$" "$MANIFEST" | head -n1)" || true
  [[ -n "$helper_path" ]]
  [[ -f "$helper_path" ]]
  HELPER_PATHS="${HELPER_PATHS:+$HELPER_PATHS }$helper_path"
done
readelf -h "$DRKONQI_BIN" | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l "$DRKONQI_BIN" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
grep -q 'libsystemd' <(readelf -d "$DRKONQI_BIN" | tr 'A-Z' 'a-z') || grep -q 'libelogind' <(readelf -d "$DRKONQI_BIN" | tr 'A-Z' 'a-z')
SYSTEMD_LINK=''
if readelf -d "$DRKONQI_BIN" | grep -qi 'libsystemd'; then SYSTEMD_LINK='libsystemd'; fi
if readelf -d "$DRKONQI_BIN" | grep -qi 'libelogind'; then SYSTEMD_LINK="${SYSTEMD_LINK:+$SYSTEMD_LINK+}libelogind"; fi
[[ -n "$SYSTEMD_LINK" ]]
grep -qxF 'WITH_PYTHON_VENDORING:BOOL=OFF' "$CONFIG"
grep -qxF 'BUILD_TESTING:BOOL=OFF' "$CONFIG"
grep -qxF 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6' "$CONFIG"
grep -q '^/opt/kf6/share/applications/org.kde.drkonqi.desktop$' "$MANIFEST"
grep -Eq '^/opt/kf6/lib(exec)?/drkonqi.*$' "$MANIFEST"
UNIT_COUNT="$(grep -c 'systemd' "$MANIFEST" || true)"
ELF_COUNT=0
ELF_HEADER=/tmp/blfs-plasma35-elf-header.txt
while IFS= read -r path; do
  [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]
  if readelf -h "$path" >"$ELF_HEADER" 2>/dev/null; then
    grep -q 'Machine:.*AArch64' "$ELF_HEADER"
    ELF_COUNT=$((ELF_COUNT + 1))
    ELF_INTERPRETER="$(readelf -l "$path" 2>/dev/null | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
    if [[ -n "$ELF_INTERPRETER" ]]; then [[ "$ELF_INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]; fi
  fi
done <"$MANIFEST"
rm -f "$ELF_HEADER"
[[ "$ELF_COUNT" -ge 6 ]]
printf 'PLASMA35_POSTCHECK=drkonqi-and-coredump-helpers-aarch64-files-static-only\n'
{
  printf 'BLFS_PLASMA35_RESULT=ok\nPACKAGE_COUNT=1\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-new-installed-tools-post-install\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PACKAGES=drkonqi\nDRKONQI=6.4.4\nKF6_VERSION=6.17.0\nPLASMA_VERSION=6.4.4\n'
  printf 'LIB_SYSTEMD_VERSION=%s\nSYSTEMD_LINK=%s\nSYSTEMD_UNITS=installed-not-enabled\nSYSTEMD_UNIT_FILE_COUNT=%s\n' "$LIB_SYSTEMD_VERSION" "$SYSTEMD_LINK" "$UNIT_COUNT"
  printf 'COREDUMP_INTEGRATION=compiled-not-started\nPYTHON_VENDORING=disabled-by-official-option\nCMAKE_BUILD_TESTING=OFF\nBUILD_TESTING=OFF\n'
  printf 'ELF_FILE_COUNT=%s\nDRKONQI_BINARY=%s\n' "$ELF_COUNT" "$DRKONQI_BIN"
  printf 'HELPER_PATHS=%s\n' "$HELPER_PATHS"
  printf 'DRKONQI_RUNTIME=not-started\nCOREDUMPD_RUNTIME=not-started\nJOURNAL_READ=not-performed\nCRASH_DIALOG=not-shown\nQML_UI=not-started\nDBUS_SERVICES=installed-not-activated\nGDB=not-executed\nCOREDUMPCTL=not-executed\n'
  printf 'OFFICIAL_PLASMA_ACTIVE=56\nOFFICIAL_PLASMA_BUILDABLE_COVERED=56\nOFFICIAL_PLASMA_DEFERRED=0\nOFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order\n'
  printf 'PLASMA_NM=preserved-pipeline-230\nPLASMA33=preserved-pipeline-229\nPLASMA32=preserved-pipeline-223\n'
  printf 'NETWORK=not-used-by-built-programs\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
