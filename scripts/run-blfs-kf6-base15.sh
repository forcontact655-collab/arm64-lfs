#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base15-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base15-sources/sources ]]
for path in Qt6Core Qt6DBus Qt6Qml Qt6Quick Qt6Test; do [[ -f "$LFS/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6FileMetaData KF6Runner KF6CoreAddons KF6KIO; do [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e "$LFS/opt/kf6/lib/cmake/KF6Baloo" && ! -e "$LFS/usr/include/lmdb.h" ]]
for name in LMDB_0.9.33.tar.gz baloo-6.17.0.tar.xz; do [[ -f "$HOST_SOURCES/$name" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base15-chroot.sh" "$LFS/root/build-blfs-kf6-base15-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base15-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base15-$name.txt" >"$ARTIFACTS/blfs-kf6-base15-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base15-chroot.sh" \
  "$LFS/root/blfs-kf6-base15-report.txt" "$LFS/root/blfs-kf6-base15-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base15-report.txt"
for expected in \
  'BLFS_KF6_BASE15_RESULT=ok' 'PACKAGE_COUNT=1' 'DEPENDENCY_COUNT=1' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE15_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'PACKAGES=baloo' 'DEPENDENCIES=lmdb' \
  'LMDB=native-temp-read-write' 'BALOO=native-query-no-indexer-exec' \
  'LMDB_TEST_SUITE=not-provided' 'BALOO_TEST_SUITE=not-run-BUILD_TESTING_OFF' 'INDEXER_RUNTIME=not-tested-no-daemon' \
  'FILE_IO=lmdb-temp-only-no-user-files' 'LMDB_SOURCE=upstream-github-tag-LMDB_0.9.33' \
  'BASE14=preserved-pipeline-126' 'BASE13=preserved-pipeline-123' 'BASE12=preserved-pipeline-121' \
  'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE15_BUILT=' "$ARTIFACTS/blfs-kf6-base15-progress.txt")" -eq 1 ]]
[[ "$(grep -c '^BLFS_KF6_BASE15_DEPENDENCY_BUILT=' "$ARTIFACTS/blfs-kf6-base15-progress.txt")" -eq 1 ]]
cat "$REPORT"
trap - EXIT
