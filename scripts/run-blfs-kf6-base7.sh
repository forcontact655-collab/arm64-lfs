#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base7-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base7-sources/sources ]]
for path in KF6ColorScheme KF6ConfigWidgets KF6Service KF6GlobalAccel KF6Package KF6Su; do
  [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6IconThemes KF6Notifications KF6JobWidgets KF6TextWidgets KF6XmlGui KF6Bookmarks; do
  [[ ! -e "$LFS/opt/kf6/lib/cmake/$path" ]]
done
[[ ! -e "$LFS/usr/lib/cmake/KF6BreezeIcons" ]]
[[ -x "$LFS/usr/bin/xfce4-terminal" && -f "$LFS/usr/lib/pkgconfig/libcanberra.pc" ]]
for name in breeze-icons kiconthemes knotifications kjobwidgets ktextwidgets kxmlgui kbookmarks; do
  [[ -f "$HOST_SOURCES/$name-6.17.0.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base7-chroot.sh" "$LFS/root/build-blfs-kf6-base7-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base7-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base7-$name.txt" >"$ARTIFACTS/blfs-kf6-base7-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base7-chroot.sh" \
  "$LFS/root/blfs-kf6-base7-report.txt" "$LFS/root/blfs-kf6-base7-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base7-report.txt"
for expected in \
  'BLFS_KF6_BASE7_RESULT=ok' 'PACKAGE_COUNT=6' 'DEPENDENCY_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE7_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'DEPENDENCIES=breeze-icons' 'BREEZE_TEST_SUITE=absent-BUILD_TESTING_OFF' \
  'PACKAGES=kiconthemes+knotifications+kjobwidgets+ktextwidgets+kxmlgui+kbookmarks' \
  'KICONTHEMES=native-breeze-icon-ok' 'KNOTIFICATIONS=object-only-no-send' \
  'KJOBWIDGETS=native-tracker-object' 'KTEXTWIDGETS=native-text-edit-ok' \
  'KXMLGUI=native-action-collection-ok' 'KBOOKMARKS=native-dom-bookmark-ok' \
  'TEXT_TO_SPEECH=disabled-qtspeech-not-built' 'NOTIFICATION_RUNTIME=not-tested-no-daemon' \
  'JOB_RUNTIME=not-tested-no-job' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'AUDIO_PLAYBACK=not-tested' 'AUDIO_DEPS=preserved-pipeline-102' \
  'BASE6=preserved-pipeline-100' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE7_BUILT=' "$ARTIFACTS/blfs-kf6-base7-progress.txt")" -eq 6 ]]
[[ "$(grep -c '^BLFS_KF6_BASE7_DEPENDENCY_BUILT=breeze-icons-6.17.0$' "$ARTIFACTS/blfs-kf6-base7-progress.txt")" -eq 1 ]]
cat "$REPORT"
trap - EXIT
