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
REPORT=/root/blfs-plasma8-report.txt
PROGRESS=/root/blfs-plasma8-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6Widgets/Qt6WidgetsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake \
  /opt/qt6/lib/cmake/Qt6QuickWidgets/Qt6QuickWidgetsConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Runner/KF6RunnerConfig.cmake \
  /opt/kf6/lib/cmake/KF6DocTools/KF6DocToolsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Su/KF6SuConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so \
  /opt/kf6/libexec/kactivitymanagerd \
  /opt/kf6/bin/knetattach \
  /opt/kf6/bin/plasmashell; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/bin/kmimetypefinder \
  /opt/kf6/bin/systemsettings; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
pkg-config --exists x11 xcb
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
  printf 'BLFS_PLASMA8_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}
for name in kde-cli-tools systemsettings; do
  extract_package "$name-6.4.4.tar.xz" "$name-6.4.4"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA8=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -D WITH_X11=ON \
    -W no-dev ..
  ninja
  ninja install
  finish_package
done
rm -rf /opt/kf6/lib/systemd
[[ "$(grep -c '^BLFS_PLASMA8_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/bin/kmimetypefinder \
  /opt/kf6/bin/kstart \
  /opt/kf6/libexec/kf6/kdesu \
  /opt/kf6/bin/systemsettings \
  /opt/kf6/share/applications/systemsettings.desktop \
  /opt/kf6/share/applications/kdesystemsettings.desktop \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so; do
  [[ -e "$path" ]]
done
[[ ! -d /opt/kf6/lib/systemd ]]
for binary in /opt/kf6/bin/kmimetypefinder /opt/kf6/bin/kstart \
  /opt/kf6/libexec/kf6/kdesu /opt/kf6/bin/systemsettings; do
  readelf -h "$binary" | grep -q 'Machine:.*AArch64'
  readelf -l "$binary" | grep -q '/lib/ld-linux-aarch64.so.1'
done
printf 'PLASMA8_POSTCHECK=cli-and-systemsettings-files\n'

# MIME matching needs no GUI. System Settings processes --version before its
# KDBusService and SettingsBase window are constructed; use offscreen QPA only.
rm -rf /tmp/blfs-plasma8-home /tmp/blfs-plasma8-runtime \
  /tmp/blfs-plasma8-mime-stderr.log /tmp/blfs-plasma8-version-stderr.log
mkdir -p /tmp/blfs-plasma8-home/.config /tmp/blfs-plasma8-home/.cache \
  /tmp/blfs-plasma8-home/.local/share
install -d -m0700 /tmp/blfs-plasma8-runtime
printf 'Plasma native MIME smoke\n' >/tmp/blfs-plasma8-sample.txt
native_env() {
  env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
    HOME=/tmp/blfs-plasma8-home LC_ALL=C.UTF-8 NO_AT_BRIDGE=1 \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde \
    QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
    XDG_RUNTIME_DIR=/tmp/blfs-plasma8-runtime \
    XDG_CONFIG_HOME=/tmp/blfs-plasma8-home/.config \
    XDG_CACHE_HOME=/tmp/blfs-plasma8-home/.cache \
    XDG_DATA_HOME=/tmp/blfs-plasma8-home/.local/share \
    XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
    QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
    LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib64:/usr/lib "$@"
}
set +e
KMIMETYPEFINDER_OUTPUT="$(native_env /opt/kf6/bin/kmimetypefinder -f \
  /tmp/blfs-plasma8-sample.txt 2>/tmp/blfs-plasma8-mime-stderr.log)"
KMIMETYPEFINDER_STATUS=$?
SYSTEMSETTINGS_VERSION_OUTPUT="$(native_env /opt/kf6/bin/systemsettings --version \
  2>/tmp/blfs-plasma8-version-stderr.log)"
SYSTEMSETTINGS_VERSION_STATUS=$?
set -e
cat /tmp/blfs-plasma8-mime-stderr.log /tmp/blfs-plasma8-version-stderr.log
printf 'KMIMETYPEFINDER_STATUS=%s\nKMIMETYPEFINDER_OUTPUT=%s\n' \
  "$KMIMETYPEFINDER_STATUS" "$KMIMETYPEFINDER_OUTPUT"
printf 'SYSTEMSETTINGS_VERSION_STATUS=%s\nSYSTEMSETTINGS_VERSION_OUTPUT=%s\n' \
  "$SYSTEMSETTINGS_VERSION_STATUS" "$SYSTEMSETTINGS_VERSION_OUTPUT"
[[ "$KMIMETYPEFINDER_STATUS" -eq 0 && "$KMIMETYPEFINDER_OUTPUT" == text/plain ]]
[[ "$SYSTEMSETTINGS_VERSION_STATUS" -eq 0 && "$SYSTEMSETTINGS_VERSION_OUTPUT" == 'systemsettings 6.4.4' ]]
INTERPRETER="$(readelf -l /opt/kf6/bin/systemsettings | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA8_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=kmimetypefinder-mime+systemsettings-version\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'KMIMETYPEFINDER_STATUS=0\nKMIMETYPEFINDER_OUTPUT=%s\n' "$KMIMETYPEFINDER_OUTPUT"
  printf 'SYSTEMSETTINGS_VERSION_STATUS=0\nSYSTEMSETTINGS_VERSION_OUTPUT=%s\n' "$SYSTEMSETTINGS_VERSION_OUTPUT"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=kde-cli-tools+systemsettings\nKDE_CLI_TOOLS=6.4.4\nSYSTEMSETTINGS=6.4.4\n'
  printf 'KMIMETYPEFINDER_SMOKE=native-extension-mime-no-gui-or-dbus\n'
  printf 'SYSTEMSETTINGS_SMOKE=native-offscreen-version-no-window-dbus-or-kcm\n'
  printf 'SYSTEMSETTINGS_WINDOW=not-created\nKCM_MODULES=not-loaded-version-only\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA7=preserved-pipeline-186\nPLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\n'
  printf 'KWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\n'
  printf 'DBUS_SESSION=not-started\nNETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma8-home /tmp/blfs-plasma8-runtime /tmp/blfs-plasma8-sample.txt \
  /tmp/blfs-plasma8-mime-stderr.log /tmp/blfs-plasma8-version-stderr.log
