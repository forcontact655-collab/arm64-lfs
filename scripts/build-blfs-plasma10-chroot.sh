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
REPORT=/root/blfs-plasma10-report.txt
PROGRESS=/root/blfs-plasma10-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake \
  /opt/qt6/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake \
  /opt/kf6/lib/cmake/KF6Pty/KF6PtyConfig.cmake \
  /opt/kf6/lib/cmake/KF6Notifications/KF6NotificationsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Runner/KF6RunnerConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/bin/kscreen-console \
  /opt/kf6/bin/systemsettings; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/bin/kwrited \
  /opt/kf6/lib/plugins/kf6/kded/kwrited.so \
  /opt/kf6/share/plasma/plasmoids/org.kde.milou \
  /opt/kf6/lib/qml/org/kde/milou; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
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
  printf 'BLFS_PLASMA10_BUILT=%s\n' "$EXTRACTED_DIR" >>"$PROGRESS"
  /sbin/ldconfig
}
for name in kwrited milou; do
  extract_package "$name-6.4.4.tar.xz" "$name-6.4.4"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA10=%s\n' "$name"
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
  finish_package
done
rm -rf /opt/kf6/lib/systemd
[[ "$(grep -c '^BLFS_PLASMA10_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ -x /opt/kf6/bin/kwrited ]]
KWRITED_BINARY=/opt/kf6/bin/kwrited
MILOU_PLUGIN="$(find /opt/kf6/lib/qml/org/kde/milou -type f -name '*milouqmlplugin.so' -print -quit)"
[[ -n "$MILOU_PLUGIN" ]]
for path in \
  "$KWRITED_BINARY" "$MILOU_PLUGIN" \
  /opt/kf6/lib/qml/org/kde/milou/qmldir \
  /opt/kf6/share/plasma/plasmoids/org.kde.milou/metadata.json \
  /opt/kf6/share/plasma/plasmoids/org.kde.milou/contents/ui/main.qml; do
  [[ -e "$path" ]]
done
[[ ! -d /opt/kf6/lib/systemd ]]
for binary in "$KWRITED_BINARY" "$MILOU_PLUGIN"; do
  readelf -h "$binary" | grep -q 'Machine:.*AArch64'
done
[[ "$(stat -c '%a' "$KWRITED_BINARY")" == 4755 ]]
readelf -l "$KWRITED_BINARY" | grep -q '/lib/ld-linux-aarch64.so.1'
printf 'PLASMA10_POSTCHECK=kwrited-and-milou-files\n'
{
  printf 'BLFS_PLASMA10_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-setuid-and-qml-code\nNEW_EXECUTABLES=kwrited-setuid-not-executed\nELF_ARCH=AArch64\n'
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=kwrited+milou\nKWRITED=6.4.4\nMILOU=6.4.4\n'
  printf 'KWRITED_MODE=executable-setuid-root-no-utempter\nKWRITED_EXEC=not-run-setuid-service\nKWRITED_SETUID_MODE=4755\nSETUID_FILES=kwrited-upstream-installed-not-executed\n'
  printf 'MILOU_QML_PLUGIN=built-not-loaded\nMILOU_PLASMOID=installed-not-loaded\n'
  printf 'KWALLET_PAM=deferred-requires-socat-not-built\nTEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA9=preserved-pipeline-189\nKSCREEN=preserved-build-and-elf-only-no-display-backend\n'
  printf 'PLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\n'
  printf 'KWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\n'
  printf 'DBUS_SESSION=not-started\nNETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
