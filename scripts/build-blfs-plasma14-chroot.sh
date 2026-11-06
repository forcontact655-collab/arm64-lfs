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
REPORT=/root/blfs-plasma14-report.txt
PROGRESS=/root/blfs-plasma14-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
pkg-config --exists libudev xcb xcb-randr xcb-dpms wayland-client
for path in \
  /opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake \
  /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake \
  /opt/kf6/lib/cmake/KF6Screen/KF6ScreenConfig.cmake \
  /opt/kf6/lib/cmake/KF6Runner/KF6RunnerConfig.cmake \
  /opt/kf6/libexec/polkit-kde-authentication-agent-1; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/libexec/org_kde_powerdevil \
  /opt/kf6/lib/libpowerdevilcore.so.6.4.4 \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.battery \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.brightness; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
archive=powerdevil-6.4.4.tar.xz
package_dir=powerdevil-6.4.4
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
[[ "${first%%/*}" == "$package_dir" ]]
rm -rf "$SOURCES/$package_dir"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
cd "$SOURCES/$package_dir"
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA14=powerdevil\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_QT5=OFF \
  -D BUILD_TESTING=OFF \
  -W no-dev ..
ninja
ninja install
cd /sources
rm -rf "$package_dir"
printf 'BLFS_PLASMA14_BUILT=powerdevil-6.4.4\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA14_BUILT=' "$PROGRESS")" -eq 1 ]]
POWERDEVIL_DAEMON=/opt/kf6/libexec/org_kde_powerdevil
POWERDEVIL_CORE="$(find /opt/kf6/lib -maxdepth 1 -type f -name 'libpowerdevilcore.so.*' -print -quit)"
POWERDEVIL_KCM="$(find /opt/kf6/lib/plugins -type f -name kcm_powerdevilprofilesconfig.so -print -quit)"
POWERDEVIL_MOBILE_KCM="$(find /opt/kf6/lib/plugins -type f -name kcm_mobile_power.so -print -quit)"
POWERDEVIL_RUNNER=/opt/kf6/lib/plugins/kf6/krunner/krunner_powerdevil.so
BATTERY_QML="$(find /opt/kf6/lib/qml/org/kde/plasma/private/batterymonitor -type f -name '*.so' -print -quit)"
BRIGHTNESS_QML="$(find /opt/kf6/lib/qml/org/kde/plasma/private/brightnesscontrolplugin -type f -name '*.so' -print -quit)"
[[ -x "$POWERDEVIL_DAEMON" && -n "$POWERDEVIL_CORE" && -n "$POWERDEVIL_KCM" && -n "$POWERDEVIL_MOBILE_KCM" ]]
[[ -f "$POWERDEVIL_RUNNER" && -n "$BATTERY_QML" && -n "$BRIGHTNESS_QML" ]]
for path in \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.battery/metadata.json \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.brightness/metadata.json; do
  [[ -f "$path" ]]
done
HELPERS=()
for name in chargethresholdhelper discretegpuhelper backlighthelper; do
  helper="$(find /opt/kf6/libexec -type f -name "$name" -print -quit)"
  [[ -n "$helper" ]]
  HELPERS+=("$helper")
  stat -c 'POWERDEVIL_HELPER_MODE=%n=%a' "$helper"
done
for elf in "$POWERDEVIL_DAEMON" "$POWERDEVIL_CORE" "$POWERDEVIL_KCM" "$POWERDEVIL_MOBILE_KCM" \
  "$POWERDEVIL_RUNNER" "$BATTERY_QML" "$BRIGHTNESS_QML" "${HELPERS[@]}"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
for executable in "$POWERDEVIL_DAEMON" "${HELPERS[@]}"; do
  interpreter="$(readelf -l "$executable" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
  [[ "$interpreter" == /lib/ld-linux-aarch64.so.1 ]]
done
INTERPRETER="$(readelf -l "$POWERDEVIL_DAEMON" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
printf 'PLASMA14_POSTCHECK=powerdevil-daemon-core-kcm-qml-runner-and-helpers\n'
{
  printf 'BLFS_PLASMA14_RESULT=ok\nPACKAGE_COUNT=1\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-power-management-and-kauth-helpers\nNEW_EXECUTABLES=org_kde_powerdevil+3-kauth-helpers-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=powerdevil\nPOWERDEVIL=6.4.4\n'
  printf 'POWERDEVIL_DAEMON=built-elf-not-executed\nPOWERDEVIL_CORE=built-elf-not-loaded\nPOWERDEVIL_KCMS=built-not-loaded\nPOWERDEVIL_QML=built-not-loaded\nPOWERDEVIL_RUNNER=built-not-loaded\n'
  printf 'POWERDEVIL_PLASMOIDS=installed-not-loaded\nKAUTH_HELPERS=installed-not-executed\nKAUTH_HELPER_MODES=observed-in-host-log\n'
  printf 'UPOWER=not-connected\nPOWER_MANAGEMENT=not-activated\nBRIGHTNESS=not-changed\nSUSPEND=not-triggered\nDDCUTIL=not-tested\n'
  printf 'TEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA13=preserved-pipeline-197\nPOLKIT_AGENT=preserved-not-executed\nWALLPAPERS=preserved-not-applied\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'PLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
