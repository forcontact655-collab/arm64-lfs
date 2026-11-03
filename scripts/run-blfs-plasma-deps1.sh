#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma-deps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma-deps1-sources/sources ]]
[[ -x "$LFS/opt/qt6/bin/qt-configure-module" && -f "$LFS/opt/qt6/lib/cmake/Qt6/Qt6Config.cmake" ]]
for path in Qt6Core Qt6Network Qt6DBus Qt6Qml Qt6Quick Qt6Test; do [[ -f "$LFS/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e "$LFS/opt/qt6/lib/cmake/Qt6WebSockets" && ! -e "$LFS/opt/qt6/lib/cmake/QCoro6" ]]
[[ ! -e "$LFS/usr/include/boost/version.hpp" && ! -e "$LFS/usr/include/libnl3" && ! -e "$LFS/usr/include/libqalculate" ]]
for name in qtwebsockets-everywhere-src-6.9.2.tar.xz qcoro-0.12.0.tar.gz boost-1.89.0-b2-nodocs.tar.xz libnl-3.11.0.tar.gz libqalculate-5.7.0.tar.gz; do [[ -f "$HOST_SOURCES/$name" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma-deps1-chroot.sh" "$LFS/root/build-blfs-plasma-deps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma-deps1-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-plasma-deps1-$name.txt" >"$ARTIFACTS/blfs-plasma-deps1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-plasma-deps1-chroot.sh" \
  "$LFS/root/blfs-plasma-deps1-report.txt" "$LFS/root/blfs-plasma-deps1-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma-deps1-report.txt"
for expected in \
  'BLFS_PLASMA_DEPS1_RESULT=ok' 'PACKAGE_COUNT=5' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=5' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS1_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA_DEPS1_EXEC_OK=6.9.2=websockets=listen=qcoro=42=boost=path=libnl=alloc=qalculate=4' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'QCORO=0.12.0' 'BOOST=1.89.0' 'LIBNL=3.11.0' 'LIBQALCULATE=5.7.0' 'PACKAGES=qtwebsockets+qcoro+boost+libnl+libqalculate' 'DEPENDENCIES=none' \
  'QTWEBSOCKETS=native-loopback-listen' 'QCORO_SMOKE=native-coroutine-42' 'BOOST_SMOKE=native-filesystem-path' 'LIBNL_SMOKE=native-socket-alloc-free' 'QALCULATE_SMOKE=native-2-plus-2' \
  'NETWORK_RUNTIME=loopback-only-no-external' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'KIRIGAMI_ADDONS=preserved-pipeline-145' 'BASE21=preserved-pipeline-143' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA_DEPS1_BUILT=' "$ARTIFACTS/blfs-plasma-deps1-progress.txt")" -eq 5 ]]
cat "$REPORT"
trap - EXIT
