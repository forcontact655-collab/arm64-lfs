#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-usb-test-deps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-usb-test-deps1-sources/sources ]]
[[ -x "$LFS/usr/bin/xfce4-power-manager" ]]
[[ -x "$LFS/usr/bin/meson" ]]
[[ ! -e "$LFS/usr/lib/libumockdev.so" ]]
for archive in libpcap-1.10.5.tar.gz vala-0.56.18.tar.xz umockdev-0.19.3.tar.xz; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-usb-test-deps1-chroot.sh" "$LFS/root/build-blfs-xfce-usb-test-deps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-usb-test-deps1-chroot.sh

cleanup
for name in report progress vala-testlog umockdev-testlog; do
  sudo -n cat "$LFS/root/blfs-xfce-usb-test-deps1-$name.txt" >"$ARTIFACTS/blfs-xfce-usb-test-deps1-$name.txt"
done
for name in smoke.c smoke.vala; do
  sudo -n cat "$LFS/root/blfs-xfce-usb-test-deps1-$name" >"$ARTIFACTS/blfs-xfce-usb-test-deps1-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-usb-test-deps1-chroot.sh" \
  "$LFS/root/blfs-xfce-usb-test-deps1-report.txt" \
  "$LFS/root/blfs-xfce-usb-test-deps1-progress.txt" \
  "$LFS/root/blfs-xfce-usb-test-deps1-vala-testlog.txt" \
  "$LFS/root/blfs-xfce-usb-test-deps1-umockdev-testlog.txt" \
  "$LFS/root/blfs-xfce-usb-test-deps1-smoke.c" \
  "$LFS/root/blfs-xfce-usb-test-deps1-smoke.vala"
grep -q '^BLFS_XFCE_USB_TEST_DEPS1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^PACKAGE_COUNT=3$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=compiled-pcap-umockdev+vala-smoke$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^LIBPCAP=1.10.5$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^LIBPCAP_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^VALA=0.56.18$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^VALA_TEST_SUITE=make-check-passed$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^UMOCKDEV=0.19.3$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^UMOCKDEV_TEST_SUITE=meson-selected-passed$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^UMOCKDEV_TEST_RECORDS=6$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^UMOCKDEV_UNEXPECTED_FAILURES=0$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^UMOCKDEV_PYTHON_TEST=not-run-pygobject-absent$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^UMOCKDEV_X11_TEST=skipped-by-upstream-xorg-absent$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^NATIVE_SMOKE=pcap-1.10.5+umockdev-true$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^VALA_NATIVE_SMOKE=vala-native-ok$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^XFCE=through-power-manager+usb-test-deps$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_USB_TEST_DEPS1_BUILT=' "$ARTIFACTS/blfs-xfce-usb-test-deps1-progress.txt")" -eq 3 ]]
cat "$ARTIFACTS/blfs-xfce-usb-test-deps1-report.txt"
trap - EXIT
