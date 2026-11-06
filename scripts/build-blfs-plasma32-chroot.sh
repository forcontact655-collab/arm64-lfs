#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --disable-static"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma32-report.txt
PROGRESS=/root/blfs-plasma32-progress.txt
DRIVER_CONFIG=/root/blfs-plasma32-driver-config.txt
TABLET_CONFIG=/root/blfs-plasma32-wacomtablet-config.txt
DRIVER_MANIFEST=/root/blfs-plasma32-driver-install-manifest.txt
TABLET_MANIFEST=/root/blfs-plasma32-wacomtablet-install-manifest.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/readelf && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /usr/bin/Xorg \
  /usr/lib/pkgconfig/xorg-server.pc \
  /usr/lib/libwacom.so \
  /usr/lib/pkgconfig/libwacom.pc \
  /usr/lib/libxcb-xinput.so \
  /usr/lib/libX11.so \
  /usr/lib/libXi.so \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Notifications/KF6NotificationsConfig.cmake \
  /opt/kf6/lib/cmake/KF6GlobalAccel/KF6GlobalAccelConfig.cmake \
  /opt/kf6/lib/cmake/KF6WindowSystem/KF6WindowSystemConfig.cmake \
  /opt/kf6/lib/cmake/KF6DocTools/KF6DocToolsConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Widgets/Qt6WidgetsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake \
  /opt/kf6/lib/libkbolt.so \
  /opt/kf6/lib/libkcm_firewall_core.so; do
  [[ -e "$path" ]]
done
for path in \
  /usr/lib/xorg/modules/input/wacom_drv.so \
  /usr/lib/pkgconfig/xorg-wacom.pc \
  /usr/bin/xsetwacom \
  /usr/bin/isdv4-serial-debugger \
  /usr/bin/isdv4-serial-inputattach \
  /opt/kf6/bin/kde_wacom_tabletfinder \
  /opt/kf6/lib/plugins/kf6/kded/wacomtablet.so \
  /opt/kf6/lib/plugins/plasma5support/dataengine/plasma_engine_wacomtablet.so \
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_wacomtablet.so; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
[[ -z "$(find /etc /usr -name 70-wacom.conf -print -quit)" ]]
pkg-config --exists 'xorg-server >= 1.13.0' x11 xi xrandr xinerama xproto xext kbproto inputproto randrproto libudev libwacom xcb-xinput
[[ "$(pkg-config --modversion xorg-server)" == 21.1.18 ]]
[[ "$(pkg-config --modversion libwacom)" == 2.16.1 ]]
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
remove_package() {
  cd /sources
  rm -rf "$EXTRACTED_DIR"
}

# Build the genuine Xorg Wacom dependency first. Its tools, driver, tests and
# udev/system service integration are not executed or activated.
find /usr /etc -xdev \( -type f -o -type l \) -print | sort >/tmp/blfs-plasma32-usr-etc-before.txt
extract_package xf86-input-wacom-1.2.3.tar.bz2 xf86-input-wacom-1.2.3
printf 'BUILD_BLFS_PLASMA32=xf86-input-wacom\n'
./configure $XORG_CONFIG --with-systemd-unit-dir=no --disable-unit-tests
make -j2
make install
remove_package
find /usr /etc -xdev \( -type f -o -type l \) -print | sort >/tmp/blfs-plasma32-usr-etc-after.txt
comm -13 /tmp/blfs-plasma32-usr-etc-before.txt /tmp/blfs-plasma32-usr-etc-after.txt >"$DRIVER_MANIFEST"
rm -f /tmp/blfs-plasma32-usr-etc-before.txt /tmp/blfs-plasma32-usr-etc-after.txt
[[ -s "$DRIVER_MANIFEST" ]]
for path in \
  /usr/lib/xorg/modules/input/wacom_drv.so \
  /usr/lib/pkgconfig/xorg-wacom.pc \
  /usr/bin/xsetwacom \
  /usr/bin/isdv4-serial-debugger \
  /usr/bin/isdv4-serial-inputattach; do
  grep -qxF "$path" "$DRIVER_MANIFEST"
done
grep -q '/70-wacom.conf$' "$DRIVER_MANIFEST"
grep -qx '/usr/lib/udev/rules.d/wacom.rules' "$DRIVER_MANIFEST"
[[ "$(pkg-config --modversion xorg-wacom)" == 1.2.3 ]]
[[ ! -e /usr/lib/systemd/system/wacom-inputattach@.service ]]
{
  printf 'XORG_WACOM_VERSION=%s\n' "$(pkg-config --modversion xorg-wacom)"
  printf 'XORG_SERVER_VERSION=%s\n' "$(pkg-config --modversion xorg-server)"
  printf 'DRIVER_TESTS=not-run-disabled\nDRIVER_SYSTEMD_UNIT=not-installed\nXORG_DRIVER=installed-not-loaded\nXSETWACOM=installed-not-executed\nUDEV_RULES=installed-not-reloaded\nTABLET_DEVICES=not-accessed\n'
} >"$DRIVER_CONFIG"
printf 'BLFS_PLASMA32_BUILT=xf86-input-wacom-1.2.3\n' >>"$PROGRESS"

# Build Wacom Tablet against the accepted libwacom and the new genuine SDK.
extract_package wacomtablet-6.4.4.tar.xz wacomtablet-6.4.4
printf 'BUILD_BLFS_PLASMA32=wacomtablet\n'
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
for target in kcm_wacomtablet kded_wacomtablet plasma_engine_wacomtablet kde_wacom_tabletfinder; do
  grep -q "$target" build.ninja
done
{
  grep -E '^(BUILD_TESTING|CMAKE_INSTALL_PREFIX|CMAKE_INSTALL_LIBDIR)' CMakeCache.txt
  printf 'LIBWACOM_VERSION=%s\n' "$(pkg-config --modversion libwacom)"
  printf 'XORGWACOM_VERSION=%s\n' "$(pkg-config --modversion xorg-wacom)"
  printf 'WACOMTABLET_RUNTIME=not-started\nQML_UI=not-started\nKDED_MODULES=installed-not-loaded\nDATAENGINE=installed-not-loaded\nTABLET_DEVICES=not-accessed\n'
} >"$TABLET_CONFIG"
grep -qx 'BUILD_TESTING:BOOL=OFF' "$TABLET_CONFIG"
grep -qx 'XORGWACOM_VERSION=1.2.3' "$TABLET_CONFIG"
ninja -j2
ninja install
[[ -s install_manifest.txt ]]
cp install_manifest.txt "$TABLET_MANIFEST"
cd /sources
rm -rf wacomtablet-6.4.4
printf 'BLFS_PLASMA32_BUILT=wacomtablet-6.4.4\n' >>"$PROGRESS"

/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA32_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ ! -e /usr/lib/systemd/system/wacom-inputattach@.service ]]
DRIVER_ELF=(
  /usr/lib/xorg/modules/input/wacom_drv.so
  /usr/bin/xsetwacom
  /usr/bin/isdv4-serial-debugger
  /usr/bin/isdv4-serial-inputattach
)
TABLET_ELF=(
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_wacomtablet.so
  /opt/kf6/lib/plugins/kf6/kded/wacomtablet.so
  /opt/kf6/lib/plugins/plasma5support/dataengine/plasma_engine_wacomtablet.so
  /opt/kf6/bin/kde_wacom_tabletfinder
)
for path in "${DRIVER_ELF[@]}"; do grep -qxF "$path" "$DRIVER_MANIFEST"; done
for path in "${TABLET_ELF[@]}"; do grep -qxF "$path" "$TABLET_MANIFEST"; done
for path in "${DRIVER_ELF[@]}" "${TABLET_ELF[@]}"; do
  [[ -f "$path" ]]
  readelf -h "$path" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l /opt/kf6/bin/kde_wacom_tabletfinder | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
ELF_COUNT=0
ELF_HEADER=/tmp/blfs-plasma32-elf-header.txt
for manifest in "$DRIVER_MANIFEST" "$TABLET_MANIFEST"; do
  while IFS= read -r path; do
    [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]
    case "$manifest:$path" in
      "$DRIVER_MANIFEST":/usr/*|"$DRIVER_MANIFEST":/etc/*|"$TABLET_MANIFEST":/opt/kf6/*) ;;
      *) printf 'unexpected-install-path=%s:%s\n' "$manifest" "$path" >&2; exit 1 ;;
    esac
    if readelf -h "$path" >"$ELF_HEADER" 2>/dev/null; then
      grep -q 'Machine:.*AArch64' "$ELF_HEADER"
      ELF_COUNT=$((ELF_COUNT + 1))
      ELF_INTERPRETER="$(readelf -l "$path" 2>/dev/null | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
      if [[ -n "$ELF_INTERPRETER" ]]; then [[ "$ELF_INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]; fi
    fi
  done <"$manifest"
done
rm -f "$ELF_HEADER"
[[ "$ELF_COUNT" -eq 8 ]]
printf 'PLASMA32_POSTCHECK=xorg-wacom-and-wacomtablet-eight-aarch64-elf-files-static-only\n'
{
  printf 'BLFS_PLASMA32_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-new-driver-tools-kcm-kded-dataengine-or-tabletfinder\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=xf86-input-wacom,wacomtablet\nXORG_WACOM=1.2.3\nWACOMTABLET=6.4.4\nELF_FILE_COUNT=%s\nBUILD_TESTING=OFF\n' "$ELF_COUNT"
  printf 'DRIVER_TESTS=not-run-disabled\nDRIVER_SYSTEMD_UNIT=not-installed\nXORG_DRIVER=installed-not-loaded\nXSETWACOM=installed-not-executed\nUDEV_RULES=installed-not-reloaded\n'
  printf 'WACOMTABLET_RUNTIME=not-started\nQML_APPLET=installed-not-loaded\nQML_UI=not-started\nKDED_MODULES=installed-not-loaded\nDATAENGINE=installed-not-loaded\nDBUS_SERVICES=installed-not-activated\nTABLET_DEVICES=not-accessed\nINPUT_RUNTIME=not-tested\n'
  printf 'OFFICIAL_PLASMA_ACTIVE=56\nOFFICIAL_PLASMA_BUILDABLE_COVERED=54\nOFFICIAL_PLASMA_DEFERRED=2\nOFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order\n'
  printf 'DRKONQI=deferred-requires-systemd-journal-and-coredumpd\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nPLASMA31=preserved-pipeline-222\n'
  printf 'TEST_SUITES=not-run\nNETWORK=not-used-by-built-programs\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
