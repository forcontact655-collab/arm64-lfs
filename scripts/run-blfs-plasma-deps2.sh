#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma-deps2-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma-deps2-sources/sources ]]
[[ ! -e "$LFS/usr/include/utf8cpp" && ! -e "$LFS/usr/include/taglib" && ! -e "$LFS/usr/include/sass" && ! -e "$LFS/usr/bin/xdotool" ]]
for name in utfcpp-4.0.6.tar.gz taglib-2.1.1.tar.gz libsass-3.6.6.tar.gz sassc-3.6.2.tar.gz xdotool-3.20211022.1.tar.gz; do [[ -f "$HOST_SOURCES/$name" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma-deps2-chroot.sh" "$LFS/root/build-blfs-plasma-deps2-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma-deps2-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-plasma-deps2-$name.txt" >"$ARTIFACTS/blfs-plasma-deps2-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-plasma-deps2-chroot.sh" \
  "$LFS/root/blfs-plasma-deps2-report.txt" "$LFS/root/blfs-plasma-deps2-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma-deps2-report.txt"
for expected in \
  'BLFS_PLASMA_DEPS2_RESULT=ok' 'PACKAGE_COUNT=5' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=5' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS2_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA_DEPS2_EXEC_OK=utf=valid=tag=native' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'UTFCPP=4.0.6' 'TAGLIB=2.1.1' 'LIBSASS=3.6.6' 'SASSC=3.6.2' 'XDOTOOL=3.20211022.1' 'PACKAGES=utfcpp+taglib+libsass+sassc+xdotool' 'DEPENDENCIES=none' \
  'UTFCPP_SMOKE=native-valid-utf8' 'TAGLIB_SMOKE=native-string-roundtrip' 'SASSC_SMOKE=native-scss-compile' \
  'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'PLASMA_DEPS1=preserved-pipeline-147' 'KIRIGAMI_ADDONS=preserved-pipeline-145' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA_DEPS2_BUILT=' "$ARTIFACTS/blfs-plasma-deps2-progress.txt")" -eq 5 ]]
grep -q '^XDOTOOL_SMOKE=xdotool version 3.20211022.1-no-x-server$' "$REPORT"
cat "$REPORT"
trap - EXIT
