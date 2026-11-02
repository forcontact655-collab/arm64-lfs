#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-launch1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-launch1-sources/sources ]]
for program in iceauth xfdesktop xfwm4 xfce4-session xfce4-panel xfsettingsd dbus-run-session setsid ps; do
  [[ -x "$LFS/usr/bin/$program" ]]
done
for program in cvt xkbcomp Xvfb xrdb; do
  [[ ! -x "$LFS/usr/bin/$program" ]]
done
[[ ! -e "$LFS/usr/lib/libepoxy.so" ]]
[[ ! -e "$LFS/usr/lib/libxcvt.so" ]]
for archive in libepoxy-1.5.10.tar.xz libxcvt-0.1.3.tar.xz font-util-1.4.1.tar.xz xkbcomp-1.4.7.tar.xz xorg-server-21.1.18.tar.xz xrdb-1.2.2.tar.xz; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-launch1-chroot.sh" "$LFS/root/build-blfs-xfce-launch1-chroot.sh"
sudo -n install -m 0644 "$REPO/scripts/blfs-xfce-launch1-x11-smoke.c" "$LFS/root/blfs-xfce-launch1-x11-smoke.c"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-launch1-chroot.sh
cleanup
for name in report.txt progress.txt libepoxy-testlog.txt xorg-testlog.txt native.txt xvfb.log session.log processes.txt x11.txt screen.png; do
  sudo -n cat "$LFS/root/blfs-xfce-launch1-$name" >"$ARTIFACTS/blfs-xfce-launch1-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-launch1-chroot.sh" "$LFS/root/blfs-xfce-launch1-x11-smoke.c" \
  "$LFS"/root/blfs-xfce-launch1-{report.txt,progress.txt,libepoxy-testlog.txt,xorg-testlog.txt,native.txt,xvfb.log,session.log,processes.txt,x11.txt,screen.png}
REPORT="$ARTIFACTS/blfs-xfce-launch1-report.txt"
for expected in \
  'BLFS_XFCE_LAUNCH1_RESULT=ok' \
  'PACKAGE_COUNT=6' \
  'LIBEPOXY=1.5.10' \
  'LIBEPOXY_TEST_SUITE=ninja-test-passed' \
  'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=cvt+xkbcomp+xrdb+xvfb+xfce-session' \
  'LIBXCVT=0.1.3' \
  'FONT_UTIL=1.4.1' \
  'XKBCOMP=1.4.7' \
  'XORG_SERVER=21.1.18' \
  'XORG_TEST_SUITE=ninja-test-passed' \
  'XRDB=1.2.2' \
  'XVFB=1280x800x24-no-tcp' \
  'XVFB_ACCESS_CONTROL=disabled-for-isolated-test-only' \
  'LIBGL=software-forced' \
  'STARTXFCE4=executed-with-existing-display' \
  'XINIT=not-used' \
  'DESKTOP_LAUNCH=headless-xvfb-startxfce4-ok' \
  'SESSION_PROCESSES=xfce4-session+xfwm4+xfdesktop+xfce4-panel+xfsettingsd' \
  'X11_WM_CHECK=present' \
  'X11_CLIENT_LIST=nonempty' \
  'SCREENSHOT=png-nonblank' \
  'TEST_HOME=ephemeral-removed' \
  'SESSION_STATE=stopped-after-validation' \
  'XFCE_CORE=18-of-18' \
  'REAL_DISPLAY=not-tested' \
  'HARDWARE_GRAPHICS=not-tested' \
  'ROOTLESS_XORG=not-tested' \
  'KDE=attica-only' \
  'PLASMA=absent' \
  'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_XFCE_LAUNCH1_BUILT=' "$ARTIFACTS/blfs-xfce-launch1-progress.txt")" -eq 6 ]]
grep -q 'Modeline.*1280x800' "$ARTIFACTS/blfs-xfce-launch1-native.txt"
grep -q '^xkbcomp 1.4.7$' "$ARTIFACTS/blfs-xfce-launch1-native.txt"
grep -q '^xrdb 1.2.2$' "$ARTIFACTS/blfs-xfce-launch1-native.txt"
grep -qE 'Ok: *[1-9]' "$ARTIFACTS/blfs-xfce-launch1-libepoxy-testlog.txt"
grep -qE 'Fail: *0' "$ARTIFACTS/blfs-xfce-launch1-libepoxy-testlog.txt"
grep -qE 'Ok: *[1-9]' "$ARTIFACTS/blfs-xfce-launch1-xorg-testlog.txt"
grep -qE 'Fail: *0' "$ARTIFACTS/blfs-xfce-launch1-xorg-testlog.txt"
grep -q '^X11_CONNECTION=ok$' "$ARTIFACTS/blfs-xfce-launch1-x11.txt"
grep -q '^X11_WM_CHECK=present$' "$ARTIFACTS/blfs-xfce-launch1-x11.txt"
grep -qE '^X11_CLIENT_COUNT=[1-9][0-9]*$' "$ARTIFACTS/blfs-xfce-launch1-x11.txt"
grep -qE '^SCREENSHOT_NON_BACKGROUND_PIXELS=[1-9][0-9]{3,}$' "$ARTIFACTS/blfs-xfce-launch1-x11.txt"
grep -qE '^SCREENSHOT_DISTINCT_COLORS_CAPPED=([2-9]|[1-9][0-9]+)$' "$ARTIFACTS/blfs-xfce-launch1-x11.txt"
for name in xfce4-session xfwm4 xfdesktop xfce4-panel xfsettingsd; do
  awk -v n="$name" '$4 == n && $3 !~ /^Z/ { found=1 } END { exit !found }' "$ARTIFACTS/blfs-xfce-launch1-processes.txt"
done
grep -q 'X.Org X Server 1.21.1.18' "$ARTIFACTS/blfs-xfce-launch1-xvfb.log"
! grep -q 'Could not invoke xkbcomp' "$ARTIFACTS/blfs-xfce-launch1-xvfb.log"
python3 - "$ARTIFACTS/blfs-xfce-launch1-screen.png" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);data=p.read_bytes()
assert len(data)>1000 and data[:8]==b'\x89PNG\r\n\x1a\n'
PY
cat "$REPORT"
trap - EXIT
