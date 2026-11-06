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
REPORT=/root/blfs-plasma6-report.txt
PROGRESS=/root/blfs-plasma6-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config && -x /usr/bin/meson && -x /usr/bin/python3 ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6QuickWidgets/Qt6QuickWidgetsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Sql/Qt6SqlConfig.cmake \
  /opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake \
  /opt/kf6/lib/cmake/LibNotificationManager/LibNotificationManagerConfig.cmake \
  /opt/kf6/lib/cmake/LibTaskManager/LibTaskManagerConfig.cmake \
  /opt/kf6/lib/cmake/LibColorCorrect/LibColorCorrectConfig.cmake \
  /opt/kf6/lib/cmake/KRunnerAppDBusInterface/KRunnerAppDBusInterfaceConfig.cmake \
  /opt/kf6/lib/cmake/KSMServerDBusInterface/KSMServerDBusInterfaceConfig.cmake \
  /opt/kf6/lib/cmake/KWinDBusInterface/KWinDBusInterfaceConfig.cmake \
  /opt/kf6/lib/cmake/ScreenSaverDBusInterface/ScreenSaverDBusInterfaceConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivitiesStats/PlasmaActivitiesStatsConfig.cmake \
  /opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake \
  /opt/kf6/lib/cmake/KF6ItemModels/KF6ItemModelsConfig.cmake \
  /opt/kf6/lib/cmake/KF6KDED/KF6KDEDConfig.cmake \
  /opt/kf6/bin/plasmashell \
  /usr/lib/libX11.so \
  /usr/lib/libX11-xcb.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/share/plasma/shells/org.kde.plasma.desktop \
  /opt/kf6/bin/knetattach \
  /usr/lib/libwacom.so; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
pkg-config --exists xkbregistry xcb xcb-shm xcb-image libcanberra libevdev gudev-1.0 glib-2.0
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
finish_package() {
  cd /sources
  rm -rf "$EXTRACTED_DIR"
  printf 'BLFS_PLASMA6_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}

# Plasma Desktop's Tablet KCM requires libwacom. Keep that feature and use
# the BLFS build with advanced hardware/Python tests disabled.
extract_package libwacom-2.16.1.tar.xz libwacom-2.16.1
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA6=libwacom\n'
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D documentation=disabled \
  -D tests=disabled \
  -D udev-dir=/usr/lib/udev
ninja
ninja install
finish_package
[[ "$(pkg-config --modversion libwacom)" == 2.16.1 ]]
for path in /usr/lib/libwacom.so /usr/lib/pkgconfig/libwacom.pc \
  /usr/bin/libwacom-list-devices /usr/share/libwacom; do
  [[ -e "$path" ]]
done

extract_package plasma-desktop-6.4.4.tar.xz plasma-desktop-6.4.4
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA6=plasma-desktop\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_QT5=OFF \
  -D BUILD_TESTING=OFF \
  -D BUILD_KCM_MOUSE_KWIN_WAYLAND=ON \
  -D BUILD_KCM_MOUSE_X11=ON \
  -D BUILD_KCM_TOUCHPAD_KWIN_WAYLAND=ON \
  -D BUILD_KCM_TOUCHPAD_X11=ON \
  -D BUILD_KCM_TABLET=ON \
  -W no-dev ..
ninja
ninja install
finish_package
rm -rf /opt/kf6/lib/systemd
[[ "$(grep -c '^BLFS_PLASMA6_BUILT=' "$PROGRESS")" -eq 2 ]]

printf 'PLASMA6_POSTCHECK=shell-and-applets\n'
TABLET_KCM="$(find /opt/kf6/lib/plugins -type f -name kcm_tablet.so -print -quit)"
[[ -n "$TABLET_KCM" ]]
readelf -h "$TABLET_KCM" | grep -q 'Machine:.*AArch64'
readelf -d "$TABLET_KCM" | grep -q 'libwacom.so'
printf 'PLASMA6_POSTCHECK=tablet-kcm-libwacom\n'
for path in \
  /opt/kf6/share/plasma/shells/org.kde.plasma.desktop/metadata.json \
  /opt/kf6/share/plasma/shells/org.kde.plasma.desktop/contents/main.js \
  /opt/kf6/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.taskmanager/metadata.json \
  /opt/kf6/lib/qml/org/kde/plasma/private/taskmanager/qmldir \
  /opt/kf6/bin/knetattach \
  /opt/kf6/bin/plasma-emojier \
  /opt/kf6/bin/plasmashell \
  /opt/kf6/bin/startplasma-x11; do
  [[ -e "$path" ]]
done
[[ ! -d /opt/kf6/lib/systemd ]]
for program in /opt/kf6/bin/knetattach /opt/kf6/bin/plasma-emojier; do
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

# knetattach parses --version and exits before its wizard is constructed.
# Thus this executes a new Plasma Desktop binary without a wizard, network,
# shell, session, compositor, D-Bus registration or real display.
rm -rf /tmp/blfs-plasma6-home /tmp/blfs-plasma6-runtime \
  /tmp/blfs-plasma6-knetattach-stderr.log
mkdir -p /tmp/blfs-plasma6-home/.config /tmp/blfs-plasma6-home/.cache \
  /tmp/blfs-plasma6-home/.local/share
install -d -m0700 /tmp/blfs-plasma6-runtime
set +e
KNETATTACH_VERSION_OUTPUT="$(env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
  HOME=/tmp/blfs-plasma6-home TERM=xterm LC_ALL=C.UTF-8 \
  QT_QPA_PLATFORM=offscreen NO_AT_BRIDGE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma6-runtime \
  XDG_CONFIG_HOME=/tmp/blfs-plasma6-home/.config \
  XDG_CACHE_HOME=/tmp/blfs-plasma6-home/.cache \
  XDG_DATA_HOME=/tmp/blfs-plasma6-home/.local/share \
  XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib \
  /opt/kf6/bin/knetattach --version 2>/tmp/blfs-plasma6-knetattach-stderr.log)"
KNETATTACH_VERSION_STATUS=$?
set -e
cat /tmp/blfs-plasma6-knetattach-stderr.log
printf 'KNETATTACH_VERSION_STATUS=%s\nKNETATTACH_VERSION_OUTPUT=%s\n' \
  "$KNETATTACH_VERSION_STATUS" "$KNETATTACH_VERSION_OUTPUT"
[[ "$KNETATTACH_VERSION_STATUS" -eq 0 ]]
[[ "$KNETATTACH_VERSION_OUTPUT" == 'knetattach 6.4.4' ]]
INTERPRETER="$(readelf -l /opt/kf6/bin/knetattach | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]

{
  printf 'BLFS_PLASMA6_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=knetattach-version\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'KNETATTACH_VERSION_STATUS=0\nKNETATTACH_VERSION_OUTPUT=%s\n' "$KNETATTACH_VERSION_OUTPUT"
  printf 'KNETATTACH_SMOKE=native-version-no-wizard-or-network\n'
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=libwacom+plasma-desktop\nLIBWACOM=2.16.1\nPLASMA_DESKTOP=6.4.4\n'
  printf 'TABLET_KCM=built-with-libwacom-no-hardware\nLIBWACOM_TESTS=disabled\nINPUT_RUNTIME=not-tested-no-devices\n'
  printf 'SHELL_PACKAGE=org.kde.plasma.desktop-installed-not-started\n'
  printf 'TASKMANAGER_APPLET=installed-not-loaded\n'
  printf 'PLASMA_DESKTOP_TESTS=not-run-BUILD_TESTING_OFF\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA5=preserved-pipeline-180\nPLASMA_WORKSPACE=preserved-pipeline-180\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMA=desktop-built-not-running\nPLASMA_SHELL=not-started\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\n'
  printf 'NETWORK=not-used-by-version-smoke\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma6-home /tmp/blfs-plasma6-runtime \
  /tmp/blfs-plasma6-knetattach-stderr.log
