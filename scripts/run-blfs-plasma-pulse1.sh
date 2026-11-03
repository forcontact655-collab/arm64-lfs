#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma-pulse1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma-pulse1-sources/sources ]]
[[ ! -e "$LFS/usr/include/sndfile.h" && ! -e "$LFS/usr/include/pulse" && ! -e "$LFS/opt/kf6/lib/cmake/KF6PulseAudioQt" ]]
for name in libsndfile-1.2.2.tar.xz pulseaudio-17.0.tar.xz pulseaudio-qt-1.7.0.tar.xz; do [[ -f "$HOST_SOURCES/$name" ]]; done
mkdir -p "$ARTIFACTS"
sudo -n true
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma-pulse1-chroot.sh" "$LFS/root/build-blfs-plasma-pulse1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma-pulse1-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-plasma-pulse1-$name.txt" >"$ARTIFACTS/blfs-plasma-pulse1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-plasma-pulse1-chroot.sh" \
  "$LFS/root/blfs-plasma-pulse1-report.txt" "$LFS/root/blfs-plasma-pulse1-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma-pulse1-report.txt"
for expected in \
  'BLFS_PLASMA_PULSE1_RESULT=ok' 'PACKAGE_COUNT=3' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=3' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA_PULSE1_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA_PULSE1_EXEC_OK=6.9.2=sndfile=wav=pulse=version=qt=volume' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'LIBSNDFILE=1.2.2' 'PULSEAUDIO=17.0' 'PULSEAUDIO_QT=1.7.0' 'PACKAGES=libsndfile+pulseaudio+pulseaudio-qt' 'DEPENDENCIES=existing-kf6-qt6-glib-dbus-alsa-xorg' \
  'LIBSNDFILE_TESTS=make-check-passed' 'LIBSNDFILE_SMOKE=native-wav-write-read-roundtrip' 'PULSEAUDIO_SMOKE=native-library-version-no-daemon' 'PULSEAUDIO_QT_SMOKE=native-volume-constants-no-daemon' \
  'PULSEAUDIO_TESTS=disabled-check-unavailable' 'PULSEAUDIO_QT_TESTS=not-run-BUILD_TESTING_OFF' 'AUDIO_RUNTIME=file-only-no-device' 'PULSE_DAEMON=not-started' \
  'PLASMA_DEPS2=preserved-pipeline-148' 'PLASMA_DEPS1=preserved-pipeline-147' 'KIRIGAMI_ADDONS=preserved-pipeline-145' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA_PULSE1_BUILT=' "$ARTIFACTS/blfs-plasma-pulse1-progress.txt")" -eq 3 ]]
cat "$REPORT"
trap - EXIT
