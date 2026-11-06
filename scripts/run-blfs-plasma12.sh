#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma12-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA12_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma12-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6PulseAudioQt/KF6PulseAudioQtConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6StatusNotifierItem/KF6StatusNotifierItemConfig.cmake" \
  "$LFS/opt/kf6/lib/libKF6PulseAudioQt.so" \
  "$LFS/usr/lib/libcanberra.so" \
  "$LFS/usr/bin/socat" \
  "$LFS/opt/kf6/lib/security/pam_kwallet5.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/libplasma-volume.so.6.4.4" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/audioshortcutsservice.so" \
  "$LFS/opt/kf6/lib/qml/org/kde/plasma/private/volume" \
  "$LFS/opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.volume.so"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -f "$HOST_SOURCES/plasma-pa-6.4.4.tar.xz" ]] || preflight_fail missing-source-plasma-pa
printf 'BLFS_PLASMA12_RUN_PRECONDITIONS=ok\n'
mkdir -p "$ARTIFACTS"
sudo -n true || preflight_fail sudo
cleanup() {
  set +e
  local path
  for path in "$LFS/sources" "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then sudo -n umount "$path"; fi
  done
  if [[ -d "$HOST_SOURCES" ]]; then sudo -n chown -R "$(id -u):$(id -g)" "$HOST_SOURCES"; fi
  set -e
}
trap cleanup EXIT
sudo -n chown -R root:root "$LFS"
sudo -n mkdir -p "$LFS"/{dev,proc,sys,run,sources}
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma12-chroot.sh" "$LFS/root/build-blfs-plasma12-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma12-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma12-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma12-$name.txt" >"$ARTIFACTS/blfs-plasma12-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA12_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma12-chroot.sh" \
  "$LFS/root/blfs-plasma12-report.txt" "$LFS/root/blfs-plasma12-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma12-report.txt"
for expected in \
  'BLFS_PLASMA12_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-audio-and-kcm-code' 'NEW_EXECUTABLES=none-audio-plugins-and-library-only' 'ELF_ARCH=AArch64' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=plasma-pa' 'PLASMA_PA=6.4.4' \
  'VOLUME_LIBRARY=built-elf-not-loaded' 'VOLUME_QML_PLUGIN=built-not-loaded' 'VOLUME_KCM=built-not-loaded' \
  'VOLUME_KDED=built-not-loaded' 'VOLUME_APPLET_PLUGIN=built-not-loaded' \
  'NATIVE_SMOKE=not-run-no-audio-backend' 'AUDIO=not-started' 'SOUND=not-played' \
  'PULSEAUDIO=not-connected' 'PIPEWIRE=not-connected' 'CANBERRA=linked-not-used' \
  'TEST_SUITES=not-run' 'TEST_TARGETS=not-executed' 'DOCUMENTATION=disabled-not-built' \
  'OPTIONAL_RUNTIME_MISSING=canberra-pulse+sound-theme-freedesktop+kirigami-addons+kitemmodels' \
  'VOLUME_FEEDBACK=not-tested-runtime-components-missing' 'KCM_RUNTIME=not-tested-optional-runtime-dependencies-missing' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' \
  'PLASMA11=preserved-pipeline-194' 'KWALLET_PAM=preserved-built-not-configured' 'KWRITED=preserved-not-rebuilt-not-executed' \
  'PLASMA_DESKTOP=preserved-not-rebuilt-not-running' 'ACTIVITY_SERVICE=preserved-not-started' \
  'KWIN=preserved-not-rebuilt-not-running' 'PLASMASHELL=not-started' \
  'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA12_BUILT=' "$ARTIFACTS/blfs-plasma12-progress.txt")" -eq 1 ]]
cat "$REPORT"
