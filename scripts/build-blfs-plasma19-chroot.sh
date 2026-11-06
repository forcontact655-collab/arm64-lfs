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
REPORT=/root/blfs-plasma19-report.txt
PROGRESS=/root/blfs-plasma19-progress.txt
KSYSTEMSTATS_CONFIG=/root/blfs-plasma19-ksystemstats-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
pkg-config --exists libnl-3.0 libudev
for path in \
  /usr/include/sensors/sensors.h \
  /usr/lib/libsensors.so \
  /usr/include/libnl3/netlink/socket.h \
  /usr/lib/libnl-3.so \
  /usr/include/libudev.h \
  /usr/lib/libudev.so \
  /opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake \
  /opt/kf6/lib/cmake/KF6KirigamiPlatform/KF6KirigamiPlatformConfig.cmake \
  /opt/kf6/lib/cmake/KF6ColorScheme/KF6ColorSchemeConfig.cmake \
  /opt/kf6/lib/cmake/KF6IconThemes/KF6IconThemesConfig.cmake \
  /opt/kf6/bin/plasma-systemmonitor \
  /opt/kf6/bin/kde-print-queue; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/cmake/QQC2BreezeStyle/QQC2BreezeStyleConfig.cmake \
  /opt/kf6/lib/qml/org/kde/breeze/qmldir \
  /opt/kf6/lib/qml/org/kde/breeze/impl/qmldir \
  /opt/kf6/lib/plugins/kf6/kirigami/platform/org.kde.breeze.so \
  /opt/kf6/lib/plugins/kf6/kirigami/platform/liborg.kde.breeze.so \
  /opt/kf6/bin/ksystemstats \
  /opt/kf6/bin/kstatsviewer \
  /opt/kf6/libexec/ksystemstats_intel_helper \
  /opt/kf6/lib/plugins/ksystemstats \
  /opt/kf6/share/dbus-1/services/org.kde.ksystemstats1.service; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
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

printf 'BUILD_BLFS_PLASMA19=qqc2-breeze-style\n'
extract_package qqc2-breeze-style-6.4.4.tar.xz qqc2-breeze-style-6.4.4
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
ninja
ninja install
cd /sources
rm -rf qqc2-breeze-style-6.4.4
printf 'BLFS_PLASMA19_BUILT=qqc2-breeze-style-6.4.4\n' >>"$PROGRESS"

printf 'BUILD_BLFS_PLASMA19=ksystemstats\n'
extract_package ksystemstats-6.4.4.tar.xz ksystemstats-6.4.4
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
  -D CMAKE_DISABLE_FIND_PACKAGE_Libcap=TRUE \
  -W no-dev ..
grep -Eq '^CMAKE_DISABLE_FIND_PACKAGE_Libcap(:[^=]+)?=TRUE$' CMakeCache.txt
grep -q 'ksystemstats_plugin_gpu' build.ninja
grep -q 'ksystemstats_intel_helper' build.ninja
grep -q 'ksystemstats_plugin_lmsensors' build.ninja
if grep -q 'CAP_PERFMON' plugins/gpu/cmake_install.cmake; then
  printf 'UNEXPECTED_KSYSTEMSTATS_CAPABILITY_INSTALL=present\n' >&2
  exit 1
fi
{
  grep -Ei '^(SENSORS_|NL_|UDEV|UDev|KF6NetworkManagerQt_DIR|CMAKE_DISABLE_FIND_PACKAGE_Libcap|CMAKE_INSTALL_PREFIX)' CMakeCache.txt || true
  printf 'GPU_PLUGIN=enabled-build-graph\nGPU_HELPER=enabled-build-graph\nLMSENSORS_PLUGIN=enabled-build-graph\nCAPABILITY_INSTALL=disabled\n'
} >"$KSYSTEMSTATS_CONFIG"
grep -Eq '^SENSORS_LIBRARIES(:[^=]+)?=/usr/lib/libsensors\.so$' "$KSYSTEMSTATS_CONFIG"
for expected in GPU_PLUGIN=enabled-build-graph GPU_HELPER=enabled-build-graph LMSENSORS_PLUGIN=enabled-build-graph CAPABILITY_INSTALL=disabled; do
  grep -qx "$expected" "$KSYSTEMSTATS_CONFIG"
done
ninja
ninja install
cd /sources
rm -rf ksystemstats-6.4.4
printf 'BLFS_PLASMA19_BUILT=ksystemstats-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA19_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ -f /opt/kf6/lib/cmake/QQC2BreezeStyle/QQC2BreezeStyleConfig.cmake ]]
QQC2_QML_PLUGIN_COUNT=0
check_qml_module() {
  local uri="$1" directory="$2"
  local -a plugins=()
  [[ -f "$directory/qmldir" ]]
  grep -qx "module $uri" "$directory/qmldir"
  mapfile -t plugins < <(find "$directory" -maxdepth 1 -type f -name '*.so' -print)
  [[ "${#plugins[@]}" -eq 1 ]]
  readelf -h "${plugins[0]}" | grep -q 'Machine:.*AArch64'
  QQC2_QML_PLUGIN_COUNT=$((QQC2_QML_PLUGIN_COUNT + 1))
}
check_qml_module org.kde.breeze /opt/kf6/lib/qml/org/kde/breeze
check_qml_module org.kde.breeze.impl /opt/kf6/lib/qml/org/kde/breeze/impl
[[ "$QQC2_QML_PLUGIN_COUNT" -eq 2 ]]
KIRIGAMI_PLUGIN_DIR=/opt/kf6/lib/plugins/kf6/kirigami/platform
mapfile -t KIRIGAMI_PLUGINS < <(find "$KIRIGAMI_PLUGIN_DIR" -maxdepth 1 -type f -name '*breeze*.so' -print)
[[ "${#KIRIGAMI_PLUGINS[@]}" -eq 1 ]]
KIRIGAMI_BASE="${KIRIGAMI_PLUGINS[0]##*/}"; KIRIGAMI_BASE="${KIRIGAMI_BASE#lib}"
[[ "$KIRIGAMI_BASE" == org.kde.breeze.so ]]
readelf -h "${KIRIGAMI_PLUGINS[0]}" | grep -q 'Machine:.*AArch64'

KSYSTEMSTATS=/opt/kf6/bin/ksystemstats
KSTATSVIEWER=/opt/kf6/bin/kstatsviewer
GPU_HELPER=/opt/kf6/libexec/ksystemstats_intel_helper
DBUS_SERVICE=/opt/kf6/share/dbus-1/services/org.kde.ksystemstats1.service
for path in "$KSYSTEMSTATS" "$KSTATSVIEWER" "$GPU_HELPER" "$DBUS_SERVICE"; do
  [[ -f "$path" ]]
done
grep -qx 'Exec=/opt/kf6/bin/ksystemstats' "$DBUS_SERVICE"
for executable in "$KSYSTEMSTATS" "$KSTATSVIEWER" "$GPU_HELPER"; do
  readelf -h "$executable" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$KSYSTEMSTATS" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
for executable in "$KSTATSVIEWER" "$GPU_HELPER"; do
  OTHER_INTERPRETER="$(readelf -l "$executable" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
  [[ "$OTHER_INTERPRETER" == "$INTERPRETER" ]]
done
if command -v getcap >/dev/null 2>&1; then
  [[ -z "$(getcap "$GPU_HELPER")" ]]
fi
PLUGIN_DIR=/opt/kf6/lib/plugins/ksystemstats
mapfile -t KSYSTEMSTATS_PLUGINS < <(find "$PLUGIN_DIR" -maxdepth 1 -type f -name '*.so' -print)
[[ "${#KSYSTEMSTATS_PLUGINS[@]}" -eq 9 ]]
for plugin in "${KSYSTEMSTATS_PLUGINS[@]}"; do
  readelf -h "$plugin" | grep -q 'Machine:.*AArch64'
done
for expected in ksystemstats_plugin_osinfo ksystemstats_plugin_network ksystemstats_plugin_power ksystemstats_plugin_disk ksystemstats_plugin_cpu ksystemstats_plugin_memory ksystemstats_plugin_pressure ksystemstats_plugin_gpu ksystemstats_plugin_lmsensors; do
  FOUND=0
  for plugin in "${KSYSTEMSTATS_PLUGINS[@]}"; do
    base="${plugin##*/}"; base="${base#lib}"
    if [[ "$base" == "$expected.so" ]]; then FOUND=1; break; fi
  done
  [[ "$FOUND" -eq 1 ]]
done
[[ ! -e /opt/kf6/lib/systemd ]]
printf 'PLASMA19_POSTCHECK=style-and-ksystemstats-elf-plugins-not-executed\n'
{
  printf 'BLFS_PLASMA19_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-ksystemstats-kstatsviewer-or-gpu-helper\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=qqc2-breeze-style+ksystemstats\n'
  printf 'QQC2_BREEZE_STYLE=6.4.4\nQQC2_STYLE_QML=installed-not-loaded\nQQC2_QML_PLUGIN_COUNT=%s\nKIRIGAMI_BREEZE_PLUGIN=installed-not-loaded\nQQC2_STYLE_UI=not-opened\n' "$QQC2_QML_PLUGIN_COUNT"
  printf 'KSYSTEMSTATS=6.4.4\nKSYSTEMSTATS_DAEMON=installed-not-executed\nKSTATSVIEWER=installed-not-executed\nKSYSTEMSTATS_DBUS_SERVICE=installed-not-activated\n'
  printf 'KSYSTEMSTATS_PLUGIN_COUNT=%s\nSENSOR_PLUGINS=installed-not-loaded\nGPU_PLUGIN=installed-not-loaded\n' "${#KSYSTEMSTATS_PLUGINS[@]}"
  printf 'GPU_HELPER=installed-not-executed-capability-not-set\nLIBCAP_FIND_PACKAGE=disabled\nCAP_PERFMON=not-set\n'
  printf 'SENSORS=not-queried\nNETWORK_STATS=not-queried\nHARDWARE_GPU=not-accessed\nPROCESSES=not-listed-or-signalled\n'
  printf 'SYSTEMMONITOR=preserved-pipeline-206-not-opened\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\nTEST_SUITES=not-run\n'
  printf 'PLASMA18=preserved-pipeline-206\nPLASMA17=preserved-pipeline-204\nPLASMA16=preserved-pipeline-201\nSDDM=preserved-not-started\n'
  printf 'PLASMA_DESKTOP=preserved-pipeline-183-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nKDED=not-started\n'
  printf 'NETWORK=not-used-by-built-programs\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
