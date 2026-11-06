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
REPORT=/root/blfs-plasma21-report.txt
PROGRESS=/root/blfs-plasma21-progress.txt
BLUEDEVIL_CONFIG=/root/blfs-plasma21-bluedevil-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6BluezQt/KF6BluezQtConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6KIO/KF6KIOConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/qml/org/kde/bluezqt/qmldir \
  /opt/kf6/lib/plugins/plasma/kcms/kinfocenter/kcm_disks.so \
  /opt/kf6/lib/plugins/kf6/kded/gtkconfig.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_bluetooth.so \
  /opt/kf6/lib/plugins/kf6/kded/bluedevil.so \
  /opt/kf6/lib/plugins/kf6/kio/kio_bluetooth.so \
  /opt/kf6/lib/plugins/kf6/kio/kio_obexftp.so \
  /opt/kf6/bin/bluedevil-sendfile \
  /opt/kf6/bin/bluedevil-wizard \
  /opt/kf6/lib/qml/org/kde/plasma/private/bluetooth \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.bluetooth; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
printf 'BUILD_BLFS_PLASMA21=bluedevil\n'
archive=bluedevil-6.4.4.tar.xz
package=bluedevil-6.4.4
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
{
  grep -E '^(KF6BluezQt_DIR|Plasma_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt
  printf 'BLUEZ_RUNTIME=not-started\nBLUETOOTH=not-queried\n'
} >"$BLUEDEVIL_CONFIG"
grep -Eq '^KF6BluezQt_DIR:PATH=/opt/kf6/lib/cmake/KF6BluezQt$' "$BLUEDEVIL_CONFIG"
grep -qx 'BLUEZ_RUNTIME=not-started' "$BLUEDEVIL_CONFIG"
grep -qx 'BLUETOOTH=not-queried' "$BLUEDEVIL_CONFIG"
ninja
ninja install
cd /sources
rm -rf "$package"
printf 'BLFS_PLASMA21_BUILT=bluedevil-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA21_BUILT=' "$PROGRESS")" -eq 1 ]]
KCM=/opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_bluetooth.so
KDED_PLUGIN=/opt/kf6/lib/plugins/kf6/kded/bluedevil.so
KIO_BLUETOOTH=/opt/kf6/lib/plugins/kf6/kio/kio_bluetooth.so
KIO_OBEXFTP=/opt/kf6/lib/plugins/kf6/kio/kio_obexftp.so
SENDFILE=/opt/kf6/bin/bluedevil-sendfile
WIZARD=/opt/kf6/bin/bluedevil-wizard
QML_DIR=/opt/kf6/lib/qml/org/kde/plasma/private/bluetooth
APPLET_DIR=/opt/kf6/share/plasma/plasmoids/org.kde.plasma.bluetooth
mapfile -t QML_PLUGINS < <(find "$QML_DIR" -maxdepth 1 -type f -name '*.so' -print)
[[ "${#QML_PLUGINS[@]}" -eq 1 ]]
QML_PLUGIN="${QML_PLUGINS[0]}"
for path in "$KCM" "$KDED_PLUGIN" "$KIO_BLUETOOTH" "$KIO_OBEXFTP" "$SENDFILE" "$WIZARD" \
  "$QML_DIR/qmldir" "$APPLET_DIR/metadata.json" "$APPLET_DIR/contents/ui/main.qml"; do
  [[ -f "$path" ]]
done
grep -q '"Id": "org.kde.plasma.bluetooth"' "$APPLET_DIR/metadata.json"
for elf in "$KCM" "$KDED_PLUGIN" "$KIO_BLUETOOTH" "$KIO_OBEXFTP" "$SENDFILE" "$WIZARD" "$QML_PLUGIN"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$SENDFILE" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
OTHER_INTERPRETER="$(readelf -l "$WIZARD" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$OTHER_INTERPRETER" == "$INTERPRETER" ]]
printf 'PLASMA21_POSTCHECK=bluedevil-seven-elf-files-qml-applet-not-executed\n'
{
  printf 'BLFS_PLASMA21_RESULT=ok\nPACKAGE_COUNT=1\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-bluedevil-tools-or-plugins\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=bluedevil\nBLUEDEVIL=6.4.4\nELF_FILE_COUNT=7\n'
  printf 'BLUETOOTH_KCM=installed-not-opened\nBLUETOOTH_APPLET=installed-not-added\nBLUETOOTH_QML_MODULE=installed-not-imported\nBLUETOOTH_QML_PLUGIN_COUNT=1\n'
  printf 'KDED_BLUEDEVIL=installed-not-loaded\nKIO_BLUETOOTH=installed-not-used\nKIO_OBEXFTP=installed-not-used\n'
  printf 'BLUEDEVIL_SENDFILE=installed-not-executed\nBLUEDEVIL_WIZARD=installed-not-executed\n'
  printf 'BLUEZQT=preserved-kf6-base14-no-manager\nBLUEZ_DAEMON=not-started\nBLUETOOTH=not-queried\nBLUETOOTH_DEVICES=not-accessed\nPAIRING=not-attempted\nOBEX=not-used\n'
  printf 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nNETWORK=not-used-by-built-programs\n'
  printf 'PLASMA20=preserved-pipeline-209\nPLASMA_DISKS=preserved-pipeline-209-not-opened\nKDE_GTK_CONFIG=preserved-pipeline-209-not-applied\n'
  printf 'KSYSTEMSTATS=preserved-pipeline-207-not-executed\nQQC2_BREEZE_STYLE=preserved-pipeline-207-not-loaded\nSYSTEMMONITOR=preserved-pipeline-206-not-opened\n'
  printf 'TEST_SUITES=not-run\nPLASMA19=preserved-pipeline-207\nPLASMA18=preserved-pipeline-206\nPLASMA17=preserved-pipeline-204\nSDDM=preserved-not-started\n'
  printf 'PLASMA_DESKTOP=preserved-pipeline-183-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
