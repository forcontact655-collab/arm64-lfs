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
REPORT=/root/blfs-plasma9-report.txt
PROGRESS=/root/blfs-plasma9-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake \
  /opt/qt6/lib/cmake/Qt6QuickControls2/Qt6QuickControls2Config.cmake \
  /opt/qt6/lib/cmake/Qt6Test/Qt6TestConfig.cmake \
  /opt/kf6/lib/cmake/KF6Screen/KF6ScreenConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Sonnet/KF6SonnetConfig.cmake \
  /opt/kf6/bin/systemsettings \
  /opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/bin/kmenuedit \
  /opt/kf6/bin/kscreen-console \
  /opt/kf6/libexec/kscreen_osd_service; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
pkg-config --exists wayland-protocols x11 x11-xcb xcb xcb-atom
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
  printf 'BLFS_PLASMA9_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}
for name in kmenuedit kscreen; do
  extract_package "$name-6.4.4.tar.xz" "$name-6.4.4"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA9=%s\n' "$name"
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
[[ "$(grep -c '^BLFS_PLASMA9_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/bin/kmenuedit \
  /opt/kf6/share/applications/org.kde.kmenuedit.desktop \
  /opt/kf6/bin/kscreen-console \
  /opt/kf6/bin/hdrcalibrator \
  /opt/kf6/libexec/kscreen_osd_service \
  /opt/kf6/share/dbus-1/services/org.kde.kscreen.osdService.service \
  /opt/kf6/share/kglobalaccel/org.kde.kscreen.desktop; do
  [[ -e "$path" ]]
done
KSCREEN_KCM="$(find /opt/kf6/lib/plugins -type f -name kcm_kscreen.so -print -quit)"
KSCREEN_KDED="$(find /opt/kf6/lib/plugins/kf6/kded -type f -name kscreen.so -print -quit)"
[[ -n "$KSCREEN_KCM" && -n "$KSCREEN_KDED" ]]
[[ ! -d /opt/kf6/lib/systemd ]]
for binary in \
  /opt/kf6/bin/kmenuedit /opt/kf6/bin/kscreen-console \
  /opt/kf6/bin/hdrcalibrator /opt/kf6/libexec/kscreen_osd_service \
  "$KSCREEN_KCM" "$KSCREEN_KDED"; do
  readelf -h "$binary" | grep -q 'Machine:.*AArch64'
done
for binary in /opt/kf6/bin/kmenuedit /opt/kf6/bin/kscreen-console \
  /opt/kf6/bin/hdrcalibrator /opt/kf6/libexec/kscreen_osd_service; do
  readelf -l "$binary" | grep -q '/lib/ld-linux-aarch64.so.1'
done
printf 'PLASMA9_POSTCHECK=menu-and-screen-files\n'
INTERPRETER="$(readelf -l /opt/kf6/bin/kscreen-console | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA9_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-no-safe-version-only-entrypoint\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=kmenuedit+kscreen\nKMENUEDIT=6.4.4\nKSCREEN=6.4.4\n'
  printf 'KMENUEDIT_EXEC=not-run-dbus-service-before-cli-parse\nKMENUEDIT_WINDOW=not-created\n'
  printf 'KSCREEN_CONSOLE=not-run-would-request-display-backend\nKSCREEN_CONFIG=not-queried\n'
  printf 'KSCREEN_OSD=installed-not-started\nKSCREEN_KCM=built-not-loaded\nKSCREEN_KDED=built-not-loaded\n'
  printf 'TEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA8=preserved-pipeline-188\nSYSTEMSETTINGS=preserved-version-only-not-opened\n'
  printf 'PLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\n'
  printf 'KWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\n'
  printf 'DBUS_SESSION=not-started\nNETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
