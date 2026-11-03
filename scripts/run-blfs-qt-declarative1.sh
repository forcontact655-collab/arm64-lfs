#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-qt-declarative1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-qt-declarative1-sources/sources ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake" ]]
for path in KF6GuiAddons KF6I18n KF6IdleTime; do
  [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in Qt6ShaderTools Qt6Qml Qt6Quick Qt6QuickWidgets; do [[ ! -e "$LFS/opt/qt6/lib/cmake/$path" ]]; done
[[ -x "$LFS/usr/bin/xfce4-terminal" ]]
for name in qtshadertools qtdeclarative; do
  [[ -f "$HOST_SOURCES/$name-everywhere-src-6.9.2.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-qt-declarative1-chroot.sh" "$LFS/root/build-blfs-qt-declarative1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-qt-declarative1-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-qt-declarative1-$name.txt" >"$ARTIFACTS/blfs-qt-declarative1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-qt-declarative1-chroot.sh" \
  "$LFS/root/blfs-qt-declarative1-report.txt" "$LFS/root/blfs-qt-declarative1-progress.txt"
REPORT="$ARTIFACTS/blfs-qt-declarative1-report.txt"
for expected in \
  'BLFS_QT_DECLARATIVE1_RESULT=ok' 'PACKAGE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_QT_DECLARATIVE1_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'QT_MODULES=qtshadertools+qtdeclarative' \
  'QML_QUICK_SMOKE=native-offscreen-item-32x16-created' \
  'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'RENDERING=not-tested' \
  'KF6_BASE2=preserved' 'XFCE_BASE=preserved' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_QT_DECLARATIVE1_BUILT=' "$ARTIFACTS/blfs-qt-declarative1-progress.txt")" -eq 2 ]]
cat "$REPORT"
trap - EXIT
