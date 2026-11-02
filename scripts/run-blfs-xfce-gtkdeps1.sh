#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-gtkdeps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-gtkdeps1-sources/sources ]]
[[ -x "$LFS/usr/bin/meson" ]]
[[ -x "$LFS/usr/bin/ninja" ]]
[[ -f "$LFS/usr/lib/pkgconfig/harfbuzz.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/libxfconf-0.pc" ]]
[[ ! -e "$LFS/usr/lib/libcairo.so" ]]
[[ ! -e "$LFS/usr/lib/libepoxy.so" ]]
for name in \
  fribidi-1.0.16.tar.xz \
  pixman-0.46.4.tar.gz \
  cairo-1.18.4.tar.xz \
  libepoxy-1.5.10.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-gtkdeps1-chroot.sh" "$LFS/root/build-blfs-xfce-gtkdeps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-gtkdeps1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-gtkdeps1-$name.txt" >"$ARTIFACTS/blfs-xfce-gtkdeps1-$name.txt"
done
for name in smoke.c smoke.png fribidi-testlog.txt pixman-testlog.txt libepoxy-testlog.txt; do
  sudo -n cat "$LFS/root/blfs-xfce-gtkdeps1-$name" >"$ARTIFACTS/blfs-xfce-gtkdeps1-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-gtkdeps1-chroot.sh" \
  "$LFS/root/blfs-xfce-gtkdeps1-report.txt" \
  "$LFS/root/blfs-xfce-gtkdeps1-progress.txt" \
  "$LFS/root/blfs-xfce-gtkdeps1-smoke.c" \
  "$LFS/root/blfs-xfce-gtkdeps1-smoke.png" \
  "$LFS/root/blfs-xfce-gtkdeps1-fribidi-testlog.txt" \
  "$LFS/root/blfs-xfce-gtkdeps1-pixman-testlog.txt" \
  "$LFS/root/blfs-xfce-gtkdeps1-libepoxy-testlog.txt"
grep -q '^BLFS_XFCE_GTKDEPS1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^PACKAGE_COUNT=4$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_GTKDEPS1_EXEC_OK$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^FRIBIDI=1.0.16$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^PIXMAN=0.46.4$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^CAIRO=1.18.4$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^LIBEPOXY=1.5.10$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^FRIBIDI_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^PIXMAN_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^LIBEPOXY_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_GTKDEPS1_EXEC_OK=1.18.4$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^GTK3=absent$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_GTKDEPS1_BUILT=' "$ARTIFACTS/blfs-xfce-gtkdeps1-progress.txt")" -eq 4 ]]
[[ "$(od -An -tx1 -N8 "$ARTIFACTS/blfs-xfce-gtkdeps1-smoke.png" | tr -d ' \n')" == 89504e470d0a1a0a ]]
expected_png="$(sed -n 's/^SMOKE_PNG_SHA256=//p' "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt")"
[[ -n "$expected_png" ]]
printf '%s  %s\n' "$expected_png" "$ARTIFACTS/blfs-xfce-gtkdeps1-smoke.png" | sha256sum -c -
cat "$ARTIFACTS/blfs-xfce-gtkdeps1-report.txt"
trap - EXIT
