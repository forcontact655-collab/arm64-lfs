#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-polkit1-report.txt
PROGRESS=/root/blfs-xfce-polkit1-progress.txt
ELOGIND_TESTLOG=/root/blfs-xfce-polkit1-elogind-testlog.txt
POLKIT_TESTLOG=/root/blfs-xfce-polkit1-polkit-unit-tests.txt
SMOKE_SOURCE=/root/blfs-xfce-polkit1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/python3 ]]
[[ -x /usr/bin/unshare ]]
[[ ! -e /usr/lib/libduktape.so ]]
[[ ! -e /usr/lib/libelogind.so ]]
[[ ! -x /usr/bin/pkaction ]]
[[ "$(pkg-config --modversion upower-glib)" == 1.90.9 ]]
[[ -d /sources ]]
: >"$PROGRESS"

build_package() {
  local archive="$1" expected="$2"
  local first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"
  package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  printf 'BUILD_BLFS_XFCE_POLKIT1=%s\n' "$package_dir"
}

cd /sources
build_package duktape-2.7.0.tar.xz duktape-2.7.0
sed -i 's/-Os/-O2/' Makefile.sharedlibrary
make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr
make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr install
cd /sources
rm -rf duktape-2.7.0
printf 'BLFS_XFCE_POLKIT1_BUILT=duktape-2.7.0\n' >>"$PROGRESS"
/sbin/ldconfig

build_package elogind-255.17.tar.gz elogind-255.17
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D man=disabled \
  -D pam=disabled \
  -D tests=true \
  -D docdir=/usr/share/doc/elogind-255.17 \
  -D cgroup-controller=elogind \
  -D dev-kvm-mode=0660 \
  -D dbuspolicydir=/etc/dbus-1/system.d
ninja
export LC_ALL=C
set +e
meson test --print-errorlogs
ELOGIND_TEST_STATUS=$?
set -e
cp meson-logs/testlog.txt "$ELOGIND_TESTLOG"
printf 'ELOGIND_MESON_TEST_EXIT=%s\n' "$ELOGIND_TEST_STATUS"
python3 - "$ELOGIND_TESTLOG" <<'PY'
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
print('ELOGIND_TEST_RECORDS=%d' % len(records))
print('ELOGIND_UNEXPECTED_FAILURES=0')
PY
ninja install
ln -sfv libelogind.pc /usr/lib/pkgconfig/libsystemd.pc
ln -sfvn elogind /usr/include/systemd
cd /sources
rm -rf elogind-255.17
printf 'BLFS_XFCE_POLKIT1_BUILT=elogind-255.17\n' >>"$PROGRESS"
/sbin/ldconfig

if ! getent group polkitd >/dev/null; then
  groupadd -fg 27 polkitd
fi
if ! id polkitd >/dev/null 2>&1; then
  useradd -c "PolicyKit Daemon Owner" -d /etc/polkit-1 -u 27 \
    -g polkitd -s /bin/false polkitd
fi
build_package polkit-126.tar.gz polkit-126
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D man=false \
  -D session_tracking=elogind \
  -D systemdsystemunitdir=/tmp \
  -D tests=true \
  -D authfw=shadow \
  -D os_type=lfs
ninja
set +e
unshare --mount --propagation private /bin/bash -c '
  set -euo pipefail
  mount --bind /sources/polkit-126/test/data/etc /etc
  export POLKIT_TEST_DATA=/sources/polkit-126/test/data
  cd /sources/polkit-126/build
  for name in polkitunixusertest polkitunixgrouptest polkitunixnetgrouptest polkitidentitytest; do
    printf "POLKIT_UNIT_BEGIN=%s\n" "$name"
    "./test/polkit/$name"
    printf "POLKIT_UNIT_PASS=%s\n" "$name"
  done
' >"$POLKIT_TESTLOG" 2>&1
POLKIT_TEST_STATUS=$?
set -e
cat "$POLKIT_TESTLOG"
[[ "$POLKIT_TEST_STATUS" -eq 0 ]]
for name in polkitunixusertest polkitunixgrouptest polkitunixnetgrouptest polkitidentitytest; do
  grep -q "^POLKIT_UNIT_PASS=$name$" "$POLKIT_TESTLOG"
done
ninja install
find /tmp -maxdepth 1 -type f -name '*.service' -delete
rm -rf /usr/lib/sysusers.d /usr/lib/tmpfiles.d
cd /sources
rm -rf polkit-126
printf 'BLFS_XFCE_POLKIT1_BUILT=polkit-126\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_POLKIT1_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ "$(pkg-config --modversion duktape)" == 2.7.0 ]]
[[ "$(pkg-config --modversion libelogind)" == 255.17 ]]
[[ "$(pkg-config --modversion polkit-gobject-1)" == 126 ]]
[[ -e /usr/lib/libduktape.so ]]
[[ -e /usr/lib/libduktaped.so ]]
[[ -e /usr/lib/libelogind.so ]]
[[ -e /usr/lib/libpolkit-gobject-1.so ]]
[[ -e /usr/lib/libpolkit-agent-1.so ]]
[[ -L /usr/lib/pkgconfig/libsystemd.pc ]]
[[ -L /usr/include/systemd ]]
for program in /usr/bin/loginctl /usr/bin/busctl /usr/lib/elogind/elogind \
  /usr/bin/pkaction /usr/bin/pkcheck /usr/bin/pkexec /usr/bin/pkttyagent \
  /usr/lib/polkit-1/polkitd; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
[[ ! -e /usr/lib/systemd/system/polkit.service ]]

cat >"$SMOKE_SOURCE" <<'EOF'
#include <duktape.h>
#include <polkit/polkit.h>
#include <stdio.h>

int main(void) {
  duk_context *context = duk_create_heap_default();
  PolkitUnixUser *user;
  int value;
  if (context == NULL)
    return 1;
  if (duk_eval_string(context, "1 + 1") != 0)
    return 1;
  value = duk_get_int(context, -1);
  duk_destroy_heap(context);
  user = polkit_unix_user_new(0);
  if (user == NULL)
    return 1;
  printf("BLFS_XFCE_POLKIT1_EXEC_OK=duktape-eval-%d+polkit-uid-%u\n",
         value, (unsigned int) polkit_unix_user_get_uid(user));
  g_object_unref(user);
  return value == 2 ? 0 : 1;
}
EOF
cc "$SMOKE_SOURCE" -o /root/blfs-xfce-polkit1-smoke \
  $(pkg-config --cflags --libs duktape polkit-gobject-1)
OUTPUT="$(/root/blfs-xfce-polkit1-smoke)"
printf '%s\n' "$OUTPUT"
[[ "$OUTPUT" == 'BLFS_XFCE_POLKIT1_EXEC_OK=duktape-eval-2+polkit-uid-0' ]]
[[ "$(pkaction --version)" == 'pkaction version 126' ]]
[[ "$(pkexec --version)" == 'pkexec version 126' ]]
LOGINCTL_VERSION="$(loginctl --version)"
printf '%s\n' "$LOGINCTL_VERSION"
grep -q '255.17' <<<"$LOGINCTL_VERSION"
rm -f /root/blfs-xfce-polkit1-smoke
set +x
{
  printf 'BLFS_XFCE_POLKIT1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=3\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=duktape-polkit-c-and-version-tools\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'UPOWER=1.90.9\n'
  printf 'DUKTAPE=2.7.0\n'
  printf 'DUKTAPE_TEST_SUITE=not-provided-by-blfs\n'
  printf 'ELOGIND=255.17\n'
  printf 'ELOGIND_TESTS=no-unexpected-failures\n'
  printf 'ELOGIND_KNOWN_FAILURE_POLICY=only-test-login+dbus-docs-fresh+check-version-history-allowed\n'
  printf 'ELOGIND_PAM=disabled-recommended-deferred\n'
  printf 'POLKIT=126\n'
  printf 'POLKIT_AUTHFW=shadow\n'
  printf 'POLKIT_SESSION_TRACKING=elogind\n'
  printf 'POLKIT_UNIT_TESTS=4-passed-isolated-mount-namespace\n'
  printf 'POLKIT_JS_AUTHORITY_TEST=not-run-dbusmock-absent\n'
  printf 'PAM=not-built-recommended-deferred\n'
  printf 'ELOGIND_DAEMON=not-started\n'
  printf 'POLKIT_DAEMON=not-started\n'
  printf 'DBUS_SESSION=not-started\n'
  printf 'AUTHORIZATION_OPERATIONS=not-tested\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'XFCE=through-power-deps+polkit\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
