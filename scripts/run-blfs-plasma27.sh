#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma27-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA27_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma27-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Prison/KF6PrisonConfig.cmake" \
  "$LFS/opt/kf6/lib/libKF6Prison.so" \
  "$LFS/usr/include/qrencode.h" \
  "$LFS/opt/kf6/lib/liboxygenstyle6.so.6.4.4"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/usr/lib/libZXing.so" \
  "$LFS/usr/lib/cmake/ZXing/ZXingConfig.cmake" \
  "$LFS/opt/kf6/lib/libKF6PrisonScanner.so" \
  "$LFS/opt/kf6/lib/libKF6PrisonScanner.so.6.17.0" \
  "$LFS/opt/kf6/bin/spectacle"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for source in zxing-cpp-2.3.0.tar.gz prison-6.17.0.tar.xz; do
  [[ -f "$HOST_SOURCES/$source" ]] || preflight_fail "missing-source-$source"
done
printf 'BLFS_PLASMA27_RUN_PRECONDITIONS=ok\n'
mkdir -p "$ARTIFACTS"
sudo -n true || preflight_fail sudo
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma27-chroot.sh" "$LFS/root/build-blfs-plasma27-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma27-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress scanner-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma27-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma27-$name.txt" >"$ARTIFACTS/blfs-plasma27-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA27_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma27-chroot.sh" \
  "$LFS/root/blfs-plasma27-report.txt" "$LFS/root/blfs-plasma27-progress.txt" \
  "$LFS/root/blfs-plasma27-scanner-config.txt"
REPORT="$ARTIFACTS/blfs-plasma27-report.txt"
for expected in \
  'BLFS_PLASMA27_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-zxing-prison-or-scanner' 'NEW_EXECUTABLES=none-libraries-only' 'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=not-applicable-shared-libraries-only' \
  'PACKAGES=zxing-cpp+prison' 'ZXING=2.3.0' 'PRISON=6.17.0' 'ELF_FILE_COUNT=3' \
  'ZXING_READERS=ON' 'ZXING_WRITERS=ON' 'ZXING_EXAMPLES=OFF' 'PRISON_CORE=rebuilt-with-scanner' 'PRISON_SCANNER=installed-not-run' 'SCANNER_RUNTIME=not-started' \
  'SPECTACLE=deferred-ready-for-next-stage' 'PLASMA25=failed-pipeline-215-cmake-no-install' 'PLASMA26=failed-pipeline-216-zxing-writers-off-missing-bitmatrix' \
  'PLASMA24=preserved-pipeline-214' 'OXYGEN=preserved-pipeline-214-not-applied' 'PLASMA23=preserved-pipeline-213' 'SOUND_THEMES=preserved-pipeline-213-not-played' \
  'PLASMA22=preserved-pipeline-211' 'PLASMA21=preserved-pipeline-210' 'PLASMA20=preserved-pipeline-209' \
  'WACOMTABLET=deferred-requires-xorg-wacom' 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' \
  'TEST_SUITES=not-run' 'NETWORK=not-used-by-build-or-built-programs' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA27_BUILT=' "$ARTIFACTS/blfs-plasma27-progress.txt")" -eq 2 ]]
grep -qx 'BLFS_PLASMA27_BUILT=zxing-cpp-2.3.0' "$ARTIFACTS/blfs-plasma27-progress.txt"
grep -qx 'BLFS_PLASMA27_BUILT=prison-6.17.0-with-scanner' "$ARTIFACTS/blfs-plasma27-progress.txt"
grep -qx 'ZXING_WRITERS:STRING=ON' "$ARTIFACTS/blfs-plasma27-scanner-config.txt"
grep -qx 'ZXING_EXAMPLES:BOOL=OFF' "$ARTIFACTS/blfs-plasma27-scanner-config.txt"
grep -qx 'WITH_MULTIMEDIA:BOOL=ON' "$ARTIFACTS/blfs-plasma27-scanner-config.txt"
grep -qx 'PRISON_SCANNER_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma27-scanner-config.txt"
grep -qx 'CAMERA=not-accessed' "$ARTIFACTS/blfs-plasma27-scanner-config.txt"
cat "$REPORT"
