#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-power-deps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-power-deps1-sources/sources ]]
[[ -x "$LFS/usr/bin/xfce4-appfinder" ]]
[[ -e "$LFS/usr/lib/libgudev-1.0.so" ]]
[[ ! -e "$LFS/usr/lib/libusb-1.0.so" ]]
[[ ! -x "$LFS/usr/bin/upower" ]]
for archive in libusb-1.0.29.tar.bz2 upower-v1.90.9.tar.bz2; do
  [[ -f "$HOST_SOURCES/$archive" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-power-deps1-chroot.sh" "$LFS/root/build-blfs-xfce-power-deps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-power-deps1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-power-deps1-$name.txt" >"$ARTIFACTS/blfs-xfce-power-deps1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-power-deps1-upower-testlog.txt" >"$ARTIFACTS/blfs-xfce-power-deps1-upower-testlog.txt"
sudo -n cat "$LFS/root/blfs-xfce-power-deps1-smoke.c" >"$ARTIFACTS/blfs-xfce-power-deps1-smoke.c"
sudo -n rm -f "$LFS/root/build-blfs-xfce-power-deps1-chroot.sh" \
  "$LFS/root/blfs-xfce-power-deps1-report.txt" \
  "$LFS/root/blfs-xfce-power-deps1-progress.txt" \
  "$LFS/root/blfs-xfce-power-deps1-upower-testlog.txt" \
  "$LFS/root/blfs-xfce-power-deps1-smoke.c"
grep -Eq '^1/1 self-test[[:space:]]+OK' "$ARTIFACTS/blfs-xfce-power-deps1-upower-testlog.txt"
grep -Eq '^Ok:[[:space:]]+1$' "$ARTIFACTS/blfs-xfce-power-deps1-upower-testlog.txt"
grep -Eq '^Fail:[[:space:]]+0$' "$ARTIFACTS/blfs-xfce-power-deps1-upower-testlog.txt"
grep -q '^BLFS_XFCE_POWER_DEPS1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^PACKAGE_COUNT=2$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=libusb-upower-native-c-and-cli-help$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^LIBUSB=1.0.29$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^LIBUSB_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^UPOWER=1.90.9$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^UPOWER_SELF_TEST=passed$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^UPOWER_INTEGRATION_TESTS=not-run-optional-dbusmock-umockdev-session-deps-absent$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^UPOWER_CLI_SMOKE=help-only-no-daemon$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^POLKIT=not-built-recommended-deferred$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^USB_DEVICE_ACCESS=not-tested$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^UPOWER_DAEMON=not-started$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -Eq '^NATIVE_SMOKE=BLFS_XFCE_POWER_DEPS1_EXEC_OK=libusb-1\.0\.29\+upower-types-[1-9][0-9]*-[1-9][0-9]*$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^XFCE=through-appfinder+power-deps$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_POWER_DEPS1_BUILT=' "$ARTIFACTS/blfs-xfce-power-deps1-progress.txt")" -eq 2 ]]
cat "$ARTIFACTS/blfs-xfce-power-deps1-report.txt"
trap - EXIT
