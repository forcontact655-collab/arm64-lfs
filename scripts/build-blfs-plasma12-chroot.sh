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
REPORT=/root/blfs-plasma12-report.txt
PROGRESS=/root/blfs-plasma12-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ "$(pkg-config --modversion libcanberra)" == 0.30 ]]
pkg-config --exists libpulse libpulse-mainloop-glib gio-2.0
for path in \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/KF6PulseAudioQt/KF6PulseAudioQtConfig.cmake \
  /opt/kf6/lib/cmake/KF6StatusNotifierItem/KF6StatusNotifierItemConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/libKF6PulseAudioQt.so \
  /usr/lib/libcanberra.so \
  /usr/bin/socat \
  /opt/kf6/lib/security/pam_kwallet5.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/libplasma-volume.so.6.4.4 \
  /opt/kf6/lib/plugins/kf6/kded/audioshortcutsservice.so \
  /opt/kf6/lib/qml/org/kde/plasma/private/volume \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.volume; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
archive=plasma-pa-6.4.4.tar.xz
package_dir=plasma-pa-6.4.4
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
[[ "${first%%/*}" == "$package_dir" ]]
rm -rf "$SOURCES/$package_dir"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
cd "$SOURCES/$package_dir"
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA12=plasma-pa\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_QT5=OFF \
  -D BUILD_TESTING=OFF \
  -D BUILD_DOC=OFF \
  -W no-dev ..
ninja
ninja install
cd /sources
rm -rf "$package_dir"
printf 'BLFS_PLASMA12_BUILT=plasma-pa-6.4.4\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA12_BUILT=' "$PROGRESS")" -eq 1 ]]
VOLUME_LIBRARY="$(find /opt/kf6/lib -maxdepth 1 -type f -name 'libplasma-volume.so.*' -print -quit)"
VOLUME_QML_PLUGIN="$(find /opt/kf6/lib/qml/org/kde/plasma/private/volume -type f -name '*.so' -print -quit)"
VOLUME_KCM="$(find /opt/kf6/lib/plugins -type f -name kcm_pulseaudio.so -print -quit)"
VOLUME_KDED=/opt/kf6/lib/plugins/kf6/kded/audioshortcutsservice.so
[[ -n "$VOLUME_LIBRARY" && -n "$VOLUME_QML_PLUGIN" && -n "$VOLUME_KCM" && -f "$VOLUME_KDED" ]]
[[ -f /opt/kf6/lib/qml/org/kde/plasma/private/volume/qmldir ]]
[[ -f /opt/kf6/share/plasma/plasmoids/org.kde.plasma.volume/metadata.json ]]
for elf in "$VOLUME_LIBRARY" "$VOLUME_QML_PLUGIN" "$VOLUME_KCM" "$VOLUME_KDED"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
printf 'PLASMA12_POSTCHECK=volume-library-qml-kcm-kded-and-plasmoid\n'
{
  printf 'BLFS_PLASMA12_RESULT=ok\nPACKAGE_COUNT=1\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-audio-and-kcm-code\nNEW_EXECUTABLES=none-audio-plugins-and-library-only\nELF_ARCH=AArch64\n'
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=plasma-pa\nPLASMA_PA=6.4.4\n'
  printf 'VOLUME_LIBRARY=built-elf-not-loaded\nVOLUME_QML_PLUGIN=built-not-loaded\nVOLUME_KCM=built-not-loaded\nVOLUME_KDED=built-not-loaded\nVOLUME_PLASMOID=installed-not-loaded\n'
  printf 'NATIVE_SMOKE=not-run-no-audio-backend\nAUDIO=not-started\nSOUND=not-played\nPULSEAUDIO=not-connected\nPIPEWIRE=not-connected\nCANBERRA=linked-not-used\n'
  printf 'TEST_SUITES=not-run\nTEST_TARGETS=not-executed\nDOCUMENTATION=disabled-not-built\n'
  printf 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'PLASMA11=preserved-pipeline-194\nKWALLET_PAM=preserved-built-not-configured\nKWRITED=preserved-not-rebuilt-not-executed\n'
  printf 'PLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
