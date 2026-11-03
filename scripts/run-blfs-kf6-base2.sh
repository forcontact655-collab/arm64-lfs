#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base2-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base2-sources/sources ]]
for path in KF6Attica KF6Archive KF6Codecs KF6Config KF6CoreAddons KF6DBusAddons; do
  [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6GuiAddons KF6I18n KF6IdleTime; do [[ ! -e "$LFS/opt/kf6/lib/cmake/$path" ]]; done
[[ ! -e "$LFS/usr/lib/cmake/PlasmaWaylandProtocols" ]]
[[ ! -e "$LFS/opt/qt6/lib/cmake/Qt6WaylandClient" ]]
[[ -x "$LFS/usr/bin/xfce4-terminal" ]]
[[ -f "$HOST_SOURCES/qtwayland-everywhere-src-6.9.2.tar.xz" ]]
[[ -f "$HOST_SOURCES/plasma-wayland-protocols-1.18.0.tar.xz" ]]
for name in kguiaddons ki18n kidletime; do [[ -f "$HOST_SOURCES/$name-6.17.0.tar.xz" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base2-chroot.sh" "$LFS/root/build-blfs-kf6-base2-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base2-chroot.sh
cleanup
for name in report progress; do sudo -n cat "$LFS/root/blfs-kf6-base2-$name.txt" >"$ARTIFACTS/blfs-kf6-base2-$name.txt"; done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base2-chroot.sh" "$LFS/root/blfs-kf6-base2-report.txt" "$LFS/root/blfs-kf6-base2-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base2-report.txt"
for expected in \
  'BLFS_KF6_BASE2_RESULT=ok' 'PACKAGE_COUNT=3' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE2_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'DEPENDENCY_COUNT=2' 'QT_WAYLAND=6.9.2' 'PLASMA_WAYLAND_PROTOCOLS=1.18.0' 'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' \
  'PACKAGES=kguiaddons+ki18n+kidletime' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'KDNSSD=deferred-avahi-backend' 'ATTICA_BASE1=preserved' 'XFCE_BASE=preserved' \
  'QT_WAYLAND_RUNTIME=not-tested-no-compositor' 'PLASMA=absent' 'BOOTABLE=no'; do grep -qxF "$expected" "$REPORT"; done
[[ "$(grep -c '^BLFS_KF6_BASE2_BUILT=' "$ARTIFACTS/blfs-kf6-base2-progress.txt")" -eq 3 ]]
cat "$REPORT"
trap - EXIT
