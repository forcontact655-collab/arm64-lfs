#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-audio-deps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-audio-deps1-sources/sources ]]
for path in KF6ColorScheme KF6ConfigWidgets KF6Service KF6GlobalAccel KF6Package KF6Su; do
  [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in /usr/lib/libogg.so /usr/lib/libvorbis.so /usr/lib/libasound.so /usr/lib/libcanberra.so; do
  [[ ! -e "$LFS$path" ]]
done
[[ -x "$LFS/usr/bin/xfce4-terminal" ]]
for name in libogg-1.3.6.tar.xz libvorbis-1.3.7.tar.xz alsa-lib-1.2.14.tar.bz2 alsa-ucm-conf-1.2.14.tar.bz2 libcanberra-0.30.tar.xz libcanberra-0.30-wayland-1.patch; do
  [[ -f "$HOST_SOURCES/$name" ]]
done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-audio-deps1-chroot.sh" "$LFS/root/build-blfs-kf6-audio-deps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-audio-deps1-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-audio-deps1-$name.txt" >"$ARTIFACTS/blfs-kf6-audio-deps1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-audio-deps1-chroot.sh" \
  "$LFS/root/blfs-kf6-audio-deps1-report.txt" "$LFS/root/blfs-kf6-audio-deps1-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-audio-deps1-report.txt"
for expected in \
  'BLFS_KF6_AUDIO_DEPS1_RESULT=ok' 'PACKAGE_COUNT=4' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_AUDIO_DEPS1_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'PACKAGES=libogg+libvorbis+alsa-lib+libcanberra' 'VERSIONS=1.3.6+1.3.7+1.2.14+0.30' \
  'ALSA_UCM_CONF=1.2.14-installed' 'CANBERRA_ALSA=built' 'CANBERRA_GTK3=built-not-run' \
  'PULSEAUDIO=disabled' 'GSTREAMER=disabled' 'UDEV=disabled' 'TDB=disabled' \
  'LIBOGG_TEST_SUITE=passed' 'LIBVORBIS_TEST_SUITE=passed' 'ALSA_LIB_TEST_SUITE=passed' \
  'LIBCANBERRA_TEST_SUITE=absent' 'AUDIO_PLAYBACK=not-tested-no-device-access' \
  'ALSA_HARDWARE=not-tested' 'SOUND_THEME=not-installed' 'BASE6=preserved-pipeline-100' \
  'XFCE_BASE=preserved' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_AUDIO_DEPS1_BUILT=' "$ARTIFACTS/blfs-kf6-audio-deps1-progress.txt")" -eq 4 ]]
cat "$REPORT"
trap - EXIT
