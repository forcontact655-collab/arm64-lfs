#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base10-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base10-sources/sources ]]
for path in KF6Declarative KF6KCMUtils KF6Kirigami KF6Wallet KF6KDED KF6KIO; do
  [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
[[ -e "$LFS/usr/lib/libsecret-1.so" && -f "$LFS/usr/lib/pkgconfig/libsecret-1.pc" ]]
for path in KF6Syndication KF6NewStuff KF6NewStuffCore KF6FrameworkIntegration; do [[ ! -e "$LFS/opt/kf6/lib/cmake/$path" ]]; done
[[ -x "$LFS/usr/bin/xfce4-terminal" && -f "$LFS/usr/lib/pkgconfig/libcanberra.pc" ]]
for name in syndication knewstuff frameworkintegration; do [[ -f "$HOST_SOURCES/$name-6.17.0.tar.xz" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base10-chroot.sh" "$LFS/root/build-blfs-kf6-base10-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base10-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base10-$name.txt" >"$ARTIFACTS/blfs-kf6-base10-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base10-chroot.sh" \
  "$LFS/root/blfs-kf6-base10-report.txt" "$LFS/root/blfs-kf6-base10-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base10-report.txt"
for expected in \
  'BLFS_KF6_BASE10_RESULT=ok' 'PACKAGE_COUNT=3' 'DEPENDENCY_COUNT=0' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE10_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'PACKAGES=syndication+knewstuff+frameworkintegration' 'DEPENDENCIES=none' \
  'SYNDICATION=local-atom-parse-no-network' 'KNEWSTUFF=native-entry-qml-import-no-download' \
  'FRAMEWORKINTEGRATION=native-kstyle-object' 'QML_IMPORTS=newstuff' 'KPACKAGE_HANDLER=present-not-run' \
  'NETWORK_RUNTIME=not-tested' 'PACKAGEKIT_RUNTIME=not-tested' 'APPSTREAM_RUNTIME=not-tested' 'WINDOW_RUNTIME=not-tested-no-window-shown' \
  'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'BASE9=preserved-pipeline-116' 'BASE8=preserved-pipeline-115' \
  'SECURITY_DEPS1=preserved-pipeline-109' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE10_BUILT=' "$ARTIFACTS/blfs-kf6-base10-progress.txt")" -eq 3 ]]
cat "$REPORT"
trap - EXIT
