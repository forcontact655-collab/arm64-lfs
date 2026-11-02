#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-ecm1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-ecm1-sources/sources ]]
[[ -x "$LFS/opt/qt6/bin/qmake6" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake" ]]
[[ -f "$HOST_SOURCES/extra-cmake-modules-6.17.0.tar.xz" ]]
[[ -f "$HOST_SOURCES/extra-cmake-modules-6.17.0-upstream_fix-1.patch" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-ecm1-chroot.sh" "$LFS/root/build-blfs-kf6-ecm1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-kf6-ecm1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-ecm1-$name.txt" >"$ARTIFACTS/blfs-kf6-ecm1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-ecm1-chroot.sh" \
  "$LFS/root/blfs-kf6-ecm1-report.txt" \
  "$LFS/root/blfs-kf6-ecm1-progress.txt"
grep -q '^BLFS_KF6_ECM1_RESULT=ok$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_KF6_ECM1_EXEC_OK$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^QT=6.9.2$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^ECM=6.17.0$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^ECM_SMOKE=BLFS_KF6_ECM1_EXEC_OK=6.9.2=1.0.0$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^PACKAGE_PREFIX_DIR=preserved$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^KDE_INSTALL_LIBDIR=lib$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^KDE=ecm-only$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^KDE_FRAMEWORKS=absent$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
[[ "$(grep -c '^BLFS_KF6_ECM1_BUILT=' "$ARTIFACTS/blfs-kf6-ecm1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-kf6-ecm1-report.txt"
trap - EXIT
