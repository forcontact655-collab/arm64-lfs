#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-apps1-sources/sources}"
HOST_OVERLAY="${HOST_OVERLAY:-/home/circleci/blfs-xfce-apps1-overlay}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-apps1-sources/sources ]]
[[ "$HOST_OVERLAY" == /home/circleci/blfs-xfce-apps1-overlay ]]
for program in iceauth xfdesktop xfwm4 xfce4-session xfce4-panel xfsettingsd dbus-run-session setsid ps cvt xkbcomp Xvfb xrdb update-desktop-database; do
  [[ -x "$LFS/usr/bin/$program" ]]
done
[[ ! -x "$LFS/usr/bin/xfce4-terminal" ]]
[[ ! -e "$LFS/usr/include/fast_float/fast_float.h" ]]
[[ "$(uname -m)" == aarch64 ]]
for pair in \
  'build-blfs-xfce-launch1-chroot.sh:550635a0b0291e21d8c01cf786ba2f77f09a91a482a1b202e90d20a078ba34de' \
  'blfs-xfce-launch1-x11-smoke.c:3a9402649e7d929942976cd91fcb85efe280d841f7ae83d2788b090bac5e26be' \
  'run-blfs-xfce-launch1.sh:f14606d6bbd0e37f3ef119e9472493edd4169f5bb0542760729b6318c1cb8ed3'; do
  file="${pair%%:*}"; expected="${pair#*:}"
  actual="$(sha256sum "$REPO/scripts/$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]]
done
for archive in fast_float-8.0.2.tar.gz vte-0.80.3.tar.gz xfce4-terminal-1.1.5.tar.xz; do
  [[ -f "$HOST_SOURCES/$archive" ]]
done
mkdir -p "$ARTIFACTS" "$HOST_OVERLAY"
[[ -z "$(ls -A "$HOST_OVERLAY")" ]]
sudo -n true
cleanup() {
  set +e
  local path
  for path in "$LFS/sources" "$LFS/overlay" "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then sudo -n umount "$path"; fi
  done
  if [[ -d "$HOST_SOURCES" ]]; then sudo -n chown -R "$(id -u):$(id -g)" "$HOST_SOURCES"; fi
  if [[ -d "$HOST_OVERLAY" ]]; then sudo -n chown -R "$(id -u):$(id -g)" "$HOST_OVERLAY"; fi
  set -e
}
trap cleanup EXIT
sudo -n chown -R root:root "$LFS"
sudo -n mkdir -p "$LFS"/{dev,proc,sys,run,sources,overlay}
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-apps1-chroot.sh" "$LFS/root/build-blfs-xfce-apps1-chroot.sh"
sudo -n install -m 0644 "$REPO/scripts/blfs-xfce-launch1-x11-smoke.c" "$LFS/root/blfs-xfce-apps1-x11-smoke.c"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind "$HOST_OVERLAY" "$LFS/overlay"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-apps1-chroot.sh
cleanup
for name in report.txt progress.txt native.txt vte-testlog.txt xvfb.log session.log terminal.log processes.txt x11.txt screen.png; do
  sudo -n cat "$LFS/root/blfs-xfce-apps1-$name" >"$ARTIFACTS/blfs-xfce-apps1-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-apps1-chroot.sh" "$LFS/root/blfs-xfce-apps1-x11-smoke.c" \
  "$LFS"/root/blfs-xfce-apps1-{report.txt,progress.txt,native.txt,vte-testlog.txt,xvfb.log,session.log,terminal.log,processes.txt,x11.txt,screen.png}
REPORT="$ARTIFACTS/blfs-xfce-apps1-report.txt"
for expected in \
  'BLFS_XFCE_APPS1_RESULT=ok' \
  'PACKAGE_COUNT=3' \
  'ARCH=aarch64' \
  'BASE_PIPELINE=83' \
  'FAST_FLOAT=8.0.2' \
  'FAST_FLOAT_TEST_SUITE=not-run-optional-network' \
  'VTE=0.80.3' \
  'VTE_TEST_SUITE=ninja-test-passed' \
  'XFCE4_TERMINAL=1.1.5' \
  'XFCE4_TERMINAL_TEST_SUITE=not-provided' \
  'XFCE4_TERMINAL_MAN_PAGE=not-built-docbook-xml-xsl-unavailable' \
  'NATIVE_BINARY_EXEC=xfce4-terminal+xvfb+xfce-session' \
  'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'TERMINAL_EXEC=APPS1_TERMINAL_EXEC_OK' \
  'DESKTOP_LAUNCH=headless-xvfb-startxfce4-terminal-ok' \
  'SESSION_PROCESSES=xfce4-session+xfwm4+xfdesktop+xfce4-panel+xfsettingsd' \
  'TERMINAL_PROCESS=live' \
  'SCREENSHOT=png-terminal-visible-required' \
  'OVERLAY_CONTENT=fast_float+vte+xfce4-terminal' \
  'TEST_HOME=ephemeral-removed' \
  'SESSION_STATE=stopped-after-validation' \
  'DEFAULT_DESKTOP_IS_FINAL=no' \
  'REAL_DISPLAY=not-tested' \
  'HARDWARE_GRAPHICS=not-tested' \
  'EXISTING_ARCH=not-accessed-not-modified' \
  'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_XFCE_APPS1_BUILT=' "$ARTIFACTS/blfs-xfce-apps1-progress.txt")" -eq 3 ]]
grep -q '^VTE=0.80.3$' "$ARTIFACTS/blfs-xfce-apps1-native.txt"
grep -q '1.1.5' "$ARTIFACTS/blfs-xfce-apps1-native.txt"
! grep -qE 'Fail: *[1-9]|ERROR: *[1-9]' "$ARTIFACTS/blfs-xfce-apps1-vte-testlog.txt"
grep -q '^X11_CONNECTION=ok$' "$ARTIFACTS/blfs-xfce-apps1-x11.txt"
grep -q '^X11_WM_CHECK=present$' "$ARTIFACTS/blfs-xfce-apps1-x11.txt"
grep -qE '^X11_CLIENT_COUNT=([4-9]|[1-9][0-9]+)$' "$ARTIFACTS/blfs-xfce-apps1-x11.txt"
grep -qE '^SCREENSHOT_NON_BACKGROUND_PIXELS=[1-9][0-9]{3,}$' "$ARTIFACTS/blfs-xfce-apps1-x11.txt"
grep -qE '^SCREENSHOT_DISTINCT_COLORS_CAPPED=([2-9]|[1-9][0-9]+)$' "$ARTIFACTS/blfs-xfce-apps1-x11.txt"
for name in xfce4-session xfwm4 xfdesktop xfce4-panel xfsettingsd xfce4-terminal; do
  awk -v n="$name" '$4 == n && $3 !~ /^Z/ { found=1 } END { exit !found }' "$ARTIFACTS/blfs-xfce-apps1-processes.txt"
done
! grep -q 'Could not invoke xkbcomp' "$ARTIFACTS/blfs-xfce-apps1-xvfb.log"
python3 - "$ARTIFACTS/blfs-xfce-apps1-screen.png" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);data=p.read_bytes()
assert len(data)>1000 and data[:8]==b'\x89PNG\r\n\x1a\n'
PY
ARCHIVE="$ARTIFACTS/lfs-12.4-xfce-apps1-overlay-aarch64.tar.xz"
[[ ! -e "$ARCHIVE" ]]
tar --numeric-owner --hard-dereference -C "$HOST_OVERLAY" -I xz -cf "$ARCHIVE" .
python3 - "$ARCHIVE" <<'PY'
import hashlib,struct,sys,tarfile
from pathlib import Path, PurePosixPath
p=Path(sys.argv[1]);required={
 './usr/bin/xfce4-terminal','./usr/libexec/vte-urlencode-cwd',
 './usr/lib/libvte-2.91.so','./usr/include/fast_float/fast_float.h',
 './usr/share/cmake/FastFloat/FastFloatConfig.cmake',
 './usr/share/applications/xfce4-terminal.desktop'}
forbidden={'./bin/bash','./usr/bin/xfce4-session','./usr/share/applications/mimeinfo.cache'}
hardlinks=regular_bytes=0
with tarfile.open(p,'r:xz') as t:
 members=t.getmembers();names={m.name for m in members}
 assert required<=names, sorted(required-names)
 assert not forbidden&names, sorted(forbidden&names)
 for m in members:
  q=PurePosixPath(m.name)
  assert not q.is_absolute() and '..' not in q.parts,m.name
  assert m.name=='.' or m.name.startswith('./'),m.name
  assert not m.isdev() and not m.issock(),m.name
  assert not m.islnk(),('hardlink',m.name)
  hardlinks+=m.islnk();regular_bytes+=m.size if m.isreg() else 0
 terminal=t.extractfile('./usr/bin/xfce4-terminal').read()
 assert terminal[:4]==b'\x7fELF' and struct.unpack_from('<H',terminal,18)[0]==183
 assert b'/lib/ld-linux-aarch64.so.1' in terminal
sha=hashlib.sha256(p.read_bytes()).hexdigest()
report=p.parent/'blfs-xfce-apps1-overlay-archive.txt'
report.write_text('\n'.join([
 'BLFS_XFCE_APPS1_OVERLAY_ARCHIVE=ok','BASE_PIPELINE=83','PACKAGE_COUNT=3',
 'OVERLAY_ONLY=yes',f'ARCHIVE={p.name}',f'ARCHIVE_SHA256={sha}',
 f'ARCHIVE_BYTES={p.stat().st_size}',f'MEMBER_COUNT={len(members)}',
 f'REGULAR_BYTES={regular_bytes}',f'HARDLINKS={hardlinks}',
 'MIMEINFO_CACHE=excluded-regenerate-on-target','BOOTABLE=no',''])+'\n')
PY
sha256sum "$ARCHIVE" >"$ARCHIVE.sha256"
cat "$REPORT"
cat "$ARTIFACTS/blfs-xfce-apps1-overlay-archive.txt"
trap - EXIT
