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
REPORT=/root/blfs-plasma31-report.txt
PROGRESS=/root/blfs-plasma31-progress.txt
BOLT_CONFIG=/root/blfs-plasma31-thunderbolt-config.txt
FIREWALL_CONFIG=/root/blfs-plasma31-firewall-config.txt
BOLT_MANIFEST=/root/blfs-plasma31-thunderbolt-install-manifest.txt
FIREWALL_MANIFEST=/root/blfs-plasma31-firewall-install-manifest.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/readelf ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Notifications/KF6NotificationsConfig.cmake \
  /opt/kf6/lib/cmake/KF6DBusAddons/KF6DBusAddonsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake \
  /opt/kf6/lib/cmake/KF6I18n/KF6I18nConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Test/Qt6TestConfig.cmake \
  /opt/kf6/bin/spectacle \
  /opt/kf6/lib/libKF6PrisonScanner.so.6.17.0 \
  /opt/kf6/lib/liboxygenstyle6.so.6.4.4; do
  [[ -e "$path" ]]
done
for name in libkbolt.so kcm_bolt.so kded_bolt.so libkcm_firewall_core.so kcm_firewall.so kde_ufw_plugin_helper; do
  [[ -z "$(find /opt/kf6 -type f -name "$name" -print -quit)" ]]
done
: >"$PROGRESS"

build_one() {
  local label="$1" archive="$2" package="$3"
  local first top
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  top="${first%%/*}"; top="${top#./}"
  [[ "$top" == "$package" ]]
  rm -rf "$SOURCES/$package"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package"
  printf 'BUILD_BLFS_PLASMA31=%s\n' "$label"
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
}

build_one thunderbolt plasma-thunderbolt-6.4.4.tar.xz plasma-thunderbolt-6.4.4
# KCMUtils embeds these files in the plugin; do not look for installed QML paths.
[[ -f src/kcm/kcm_bolt.qrc ]]
[[ "$(grep -c 'alias="[^"]*\.qml"' src/kcm/kcm_bolt.qrc)" -eq 3 ]]
grep -q 'alias="main.qml"' src/kcm/kcm_bolt.qrc
grep -q 'alias="DeviceList.qml"' src/kcm/kcm_bolt.qrc
grep -q 'alias="DeviceView.qml"' src/kcm/kcm_bolt.qrc
grep -q 'kded_bolt.cpp' build.ninja
grep -q 'manager.cpp' build.ninja
{
  grep -E '^(BUILD_TESTING|CMAKE_INSTALL_PREFIX|CMAKE_INSTALL_LIBDIR|boltd_EXECUTABLE)' CMakeCache.txt || true
  printf 'BOLT_QML_RESOURCES=3-embedded-not-run\nBOLT_RUNTIME=not-started\nTHUNDERBOLT_DEVICES=not-accessed\nKDED_MODULE=installed-not-loaded\n'
} >"$BOLT_CONFIG"
grep -qx 'BUILD_TESTING:BOOL=OFF' "$BOLT_CONFIG"
grep -qx 'BOLT_QML_RESOURCES=3-embedded-not-run' "$BOLT_CONFIG"
ninja -j2
ninja install
[[ -s install_manifest.txt ]]
cp install_manifest.txt "$BOLT_MANIFEST"
cd /sources
rm -rf plasma-thunderbolt-6.4.4
printf 'BLFS_PLASMA31_BUILT=plasma-thunderbolt-6.4.4\n' >>"$PROGRESS"

build_one firewall plasma-firewall-6.4.4.tar.xz plasma-firewall-6.4.4
[[ -f kcm/kcm_firewall.qrc ]]
[[ "$(grep -c 'alias="[^"]*\.qml"' kcm/kcm_firewall.qrc)" -eq 12 ]]
grep -q 'alias="main.qml"' kcm/kcm_firewall.qrc
grep -q 'alias="RuleEdit.qml"' kcm/kcm_firewall.qrc
grep -q 'alias="ConnectionsView.qml"' kcm/kcm_firewall.qrc
grep -q 'kde_ufw_plugin_helper' build.ninja
grep -q 'firewalldclient.cpp' build.ninja
{
  grep -E '^(BUILD_TESTING|BUILD_FIREWALLD_BACKEND|BUILD_UFW_BACKEND|CMAKE_INSTALL_PREFIX|CMAKE_INSTALL_LIBDIR)' CMakeCache.txt
  printf 'FIREWALL_QML_RESOURCES=12-embedded-not-run\nFIREWALLD_BACKEND=compiled-not-contacted\nUFW_BACKEND=compiled-not-used\nFIREWALL_RULES=not-read-or-changed\nPOLKIT_HELPER=installed-not-executed\nPYTHON_HELPER=installed-not-executed\n'
} >"$FIREWALL_CONFIG"
grep -qx 'BUILD_TESTING:BOOL=OFF' "$FIREWALL_CONFIG"
grep -qx 'BUILD_FIREWALLD_BACKEND:BOOL=ON' "$FIREWALL_CONFIG"
grep -qx 'BUILD_UFW_BACKEND:BOOL=ON' "$FIREWALL_CONFIG"
ninja -j2
ninja install
[[ -s install_manifest.txt ]]
cp install_manifest.txt "$FIREWALL_MANIFEST"
cd /sources
rm -rf plasma-firewall-6.4.4
printf 'BLFS_PLASMA31_BUILT=plasma-firewall-6.4.4\n' >>"$PROGRESS"

/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA31_BUILT=' "$PROGRESS")" -eq 2 ]]
for name in libkbolt.so kcm_bolt.so kded_bolt.so libkcm_firewall_core.so kcm_firewall.so kde_ufw_plugin_helper; do
  [[ "$(find /opt/kf6 -type f -name "$name" | wc -l)" -eq 1 ]]
done
ELF_COUNT=0
ELF_HEADER=/tmp/blfs-plasma31-elf-header.txt
for manifest in "$BOLT_MANIFEST" "$FIREWALL_MANIFEST"; do
  while IFS= read -r path; do
    [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]
    if readelf -h "$path" >"$ELF_HEADER" 2>/dev/null; then
      grep -q 'Machine:.*AArch64' "$ELF_HEADER"
      ELF_COUNT=$((ELF_COUNT + 1))
      INTERPRETER="$(readelf -l "$path" 2>/dev/null | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
      if [[ -n "$INTERPRETER" ]]; then [[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]; fi
    fi
  done <"$manifest"
done
rm -f "$ELF_HEADER"
[[ "$ELF_COUNT" -eq 6 ]]
printf 'PLASMA31_POSTCHECK=two-packages-six-aarch64-elf-files-static-only\n'
{
  printf 'BLFS_PLASMA31_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-new-kcm-kded-library-or-helper-programs\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=plasma-thunderbolt,plasma-firewall\nPLASMA_THUNDERBOLT=6.4.4\nPLASMA_FIREWALL=6.4.4\nELF_FILE_COUNT=%s\nBUILD_TESTING=OFF\n' "$ELF_COUNT"
  printf 'QML_RESOURCES=15-embedded-not-run\nQML_UI=not-started\nBOLT_RUNTIME=not-started\nTHUNDERBOLT_DEVICES=not-accessed\nKDED_MODULES=installed-not-loaded\n'
  printf 'FIREWALLD_BACKEND=compiled-not-contacted\nUFW_BACKEND=compiled-not-used\nFIREWALL_RULES=not-read-or-changed\nPOLKIT_HELPERS=installed-not-executed\nPYTHON_HELPERS=installed-not-executed\nDBUS_ACTIVATION=not-performed\n'
  printf 'DRKONQI=deferred-requires-systemd-journal-and-coredumpd\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nWACOMTABLET=deferred-requires-xorg-wacom\n'
  printf 'OFFICIAL_PLASMA_ACTIVE=56\nOFFICIAL_PLASMA_BUILDABLE_COVERED=53\nOFFICIAL_PLASMA_DEFERRED=3\nOFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order\n'
  printf 'TEST_SUITES=not-run\nNETWORK=not-used-by-built-programs\nPLASMA30=preserved-pipeline-220\nSPECTACLE=preserved-pipeline-220-not-started\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
