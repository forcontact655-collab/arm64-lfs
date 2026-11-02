#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-polkit1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-polkit1-sources/sources ]]
[[ -e "$LFS/usr/lib/libupower-glib.so" ]]
[[ -x "$LFS/usr/bin/upower" ]]
[[ -x "$LFS/usr/bin/unshare" ]]
[[ ! -e "$LFS/usr/lib/libduktape.so" ]]
[[ ! -e "$LFS/usr/lib/libelogind.so" ]]
[[ ! -x "$LFS/usr/bin/pkaction" ]]
for archive in duktape-2.7.0.tar.xz elogind-255.17.tar.gz polkit-126.tar.gz; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-polkit1-chroot.sh" "$LFS/root/build-blfs-xfce-polkit1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-polkit1-chroot.sh

cleanup
for name in report progress elogind-testlog polkit-unit-tests; do
  sudo -n cat "$LFS/root/blfs-xfce-polkit1-$name.txt" >"$ARTIFACTS/blfs-xfce-polkit1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-polkit1-smoke.c" >"$ARTIFACTS/blfs-xfce-polkit1-smoke.c"
sudo -n rm -f "$LFS/root/build-blfs-xfce-polkit1-chroot.sh" \
  "$LFS/root/blfs-xfce-polkit1-report.txt" \
  "$LFS/root/blfs-xfce-polkit1-progress.txt" \
  "$LFS/root/blfs-xfce-polkit1-elogind-testlog.txt" \
  "$LFS/root/blfs-xfce-polkit1-polkit-unit-tests.txt" \
  "$LFS/root/blfs-xfce-polkit1-smoke.c"
python3 - "$ARTIFACTS/blfs-xfce-polkit1-elogind-testlog.txt" <<'PY'
import sys
known = {'test-login', 'dbus-docs-fresh', 'check-version-history'}
records = []
current = None
for line in open(sys.argv[1], encoding='utf-8'):
    if line.startswith('test:'):
        current = {'name': line.split(':', 1)[1].strip()}
    elif line.startswith('result:') and current is not None:
        current['result'] = line.split(':', 1)[1].strip()
        records.append(current)
        current = None
assert len(records) >= 10, len(records)
unexpected = [r for r in records if r['result'] != 'exit status 0' and r['result'] != 'exit status 77' and r['name'] not in known]
assert not unexpected, unexpected
PY
for name in polkitunixusertest polkitunixgrouptest polkitunixnetgrouptest polkitidentitytest; do
  grep -q "^POLKIT_UNIT_BEGIN=$name$" "$ARTIFACTS/blfs-xfce-polkit1-polkit-unit-tests.txt"
  grep -q "^POLKIT_UNIT_PASS=$name$" "$ARTIFACTS/blfs-xfce-polkit1-polkit-unit-tests.txt"
done
grep -q '^BLFS_XFCE_POLKIT1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^PACKAGE_COUNT=3$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=duktape-polkit-c-and-version-tools$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^DUKTAPE=2.7.0$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^DUKTAPE_TEST_SUITE=not-provided-by-blfs$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^ELOGIND=255.17$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^ELOGIND_TESTS=no-unexpected-failures$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^ELOGIND_KNOWN_FAILURE_POLICY=only-test-login+dbus-docs-fresh+check-version-history-allowed$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^ELOGIND_PAM=disabled-recommended-deferred$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^POLKIT=126$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^POLKIT_AUTHFW=shadow$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^POLKIT_SESSION_TRACKING=elogind$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^POLKIT_UNIT_TESTS=4-passed-isolated-mount-namespace$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^POLKIT_JS_AUTHORITY_TEST=not-run-dbusmock-absent$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^PAM=not-built-recommended-deferred$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^ELOGIND_DAEMON=not-started$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^POLKIT_DAEMON=not-started$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^DBUS_SESSION=not-started$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^AUTHORIZATION_OPERATIONS=not-tested$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_POLKIT1_EXEC_OK=duktape-eval-2+polkit-uid-0$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^XFCE=through-power-deps+polkit$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_POLKIT1_BUILT=' "$ARTIFACTS/blfs-xfce-polkit1-progress.txt")" -eq 3 ]]
cat "$ARTIFACTS/blfs-xfce-polkit1-report.txt"
trap - EXIT
