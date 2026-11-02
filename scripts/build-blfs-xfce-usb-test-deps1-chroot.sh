#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-usb-test-deps1-report.txt
PROGRESS=/root/blfs-xfce-usb-test-deps1-progress.txt
VALA_TESTLOG=/root/blfs-xfce-usb-test-deps1-vala-testlog.txt
UMOCKDEV_TESTLOG=/root/blfs-xfce-usb-test-deps1-umockdev-testlog.txt
SMOKE_SOURCE=/root/blfs-xfce-usb-test-deps1-smoke.c
VALA_SMOKE_SOURCE=/root/blfs-xfce-usb-test-deps1-smoke.vala
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/python3 ]]
[[ -x /usr/bin/dbus-run-session ]]
[[ -x /usr/bin/xfce4-power-manager ]]
[[ ! -x /usr/bin/valac ]]
[[ ! -x /usr/bin/dot ]]
[[ ! -x /usr/bin/Xorg ]]
[[ ! -e /usr/lib/libpcap.so ]]
[[ ! -e /usr/lib/libumockdev.so ]]
[[ "$(pkg-config --modversion gudev-1.0)" == 238 ]]
[[ "$(pkg-config --modversion libusb-1.0)" == 1.0.29 ]]
! python3 -c 'import gi' >/dev/null 2>&1
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
  printf 'BUILD_BLFS_XFCE_USB_TEST_DEPS1=%s\n' "$package_dir"
}

cd /sources
build_package libpcap-1.10.5.tar.gz libpcap-1.10.5
./configure --prefix=/usr
make
make install
cd /sources
rm -rf libpcap-1.10.5
printf 'BLFS_XFCE_USB_TEST_DEPS1_BUILT=libpcap-1.10.5\n' >>"$PROGRESS"
/sbin/ldconfig

build_package vala-0.56.18.tar.xz vala-0.56.18
./configure --prefix=/usr --disable-valadoc
make
export LC_ALL=C.UTF-8
dbus-run-session -- make check 2>&1 | tee "$VALA_TESTLOG"
make install
cd /sources
rm -rf vala-0.56.18
printf 'BLFS_XFCE_USB_TEST_DEPS1_BUILT=vala-0.56.18\n' >>"$PROGRESS"
/sbin/ldconfig

build_package umockdev-0.19.3.tar.xz umockdev-0.19.3
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D gtk_doc=false
ninja
meson test --print-errorlogs \
  umockdev \
  umockdev-vala \
  ioctl-tree \
  umockdev-run \
  umockdev-record \
  static-code
cp meson-logs/testlog.txt "$UMOCKDEV_TESTLOG"
read -r UMOCKDEV_RECORDS < <(python3 - "$UMOCKDEV_TESTLOG" <<'PY'
import sys
records = []
current = None
for line in open(sys.argv[1], encoding='utf-8'):
    if line.startswith('test:'):
        current = {'name': line.split(':', 1)[1].strip()}
    elif line.startswith('result:') and current is not None:
        current['result'] = line.split(':', 1)[1].strip()
        records.append(current)
        current = None
assert len(records) == 6, records
unexpected = [r for r in records if r['result'] != 'exit status 0']
assert not unexpected, unexpected
print(len(records))
PY
)
[[ "$UMOCKDEV_RECORDS" -eq 6 ]]
grep -q 'SKIP: Xorg not installed' "$UMOCKDEV_TESTLOG"
printf 'UMOCKDEV_TEST_RECORDS=%s UNEXPECTED_FAILURES=0\n' "$UMOCKDEV_RECORDS"
ninja install
cd /sources
rm -rf umockdev-0.19.3
printf 'BLFS_XFCE_USB_TEST_DEPS1_BUILT=umockdev-0.19.3\n' >>"$PROGRESS"
/sbin/ldconfig
set -x

[[ "$(grep -c '^BLFS_XFCE_USB_TEST_DEPS1_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ "$(pkg-config --modversion libpcap)" == 1.10.5 ]]
[[ "$(pkg-config --modversion umockdev-1.0)" == 0.19.3 ]]
[[ "$(pcap-config --version)" == 1.10.5 ]]
[[ "$(valac --version)" == 'Vala 0.56.18' ]]
[[ "$(umockdev-run --version)" == 0.19.3 ]]
for library in libpcap.so libvala-0.56.so libumockdev.so libumockdev-preload.so; do
  [[ -e "/usr/lib/$library" ]]
done
for program in /usr/bin/valac-0.56 /usr/bin/vapigen-0.56 /usr/bin/vala-gen-introspect-0.56 /usr/bin/umockdev-run /usr/bin/umockdev-record; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
for program in /usr/bin/pcap-config /usr/bin/umockdev-wrapper /usr/bin/vala /usr/bin/valac /usr/bin/vapigen; do
  [[ -x "$program" ]]
done
[[ -f /usr/share/gir-1.0/UMockdev-1.0.gir ]]
[[ -f /usr/lib/girepository-1.0/UMockdev-1.0.typelib ]]
[[ -f /usr/share/vala/vapi/umockdev-1.0.vapi ]]

cat >"$SMOKE_SOURCE" <<'EOF'
#include <pcap/pcap.h>
#include <umockdev.h>
#include <string.h>

int main(void) {
  UMockdevTestbed *testbed;
  const char *version = pcap_lib_version();
  if (version == NULL || strstr(version, "1.10.5") == NULL)
    return 1;
  testbed = umockdev_testbed_new();
  if (testbed == NULL)
    return 2;
  g_object_unref(testbed);
  g_print("pcap-1.10.5+umockdev-true\n");
  return 0;
}
EOF
gcc -O2 -Wall -Wextra -Werror "$SMOKE_SOURCE" -o /root/blfs-xfce-usb-test-deps1-smoke \
  $(pkg-config --cflags --libs libpcap umockdev-1.0)
readelf -h /root/blfs-xfce-usb-test-deps1-smoke | grep -q 'Machine:.*AArch64'
SMOKE_OUTPUT="$(/root/blfs-xfce-usb-test-deps1-smoke)"
[[ "$SMOKE_OUTPUT" == pcap-1.10.5+umockdev-true ]]
printf '%s\n' "$SMOKE_OUTPUT"
rm -f /root/blfs-xfce-usb-test-deps1-smoke

cat >"$VALA_SMOKE_SOURCE" <<'EOF'
void main() {
    stdout.printf("vala-native-ok\n");
}
EOF
valac "$VALA_SMOKE_SOURCE" -o /root/blfs-xfce-usb-test-deps1-vala-smoke
readelf -h /root/blfs-xfce-usb-test-deps1-vala-smoke | grep -q 'Machine:.*AArch64'
VALA_SMOKE_OUTPUT="$(/root/blfs-xfce-usb-test-deps1-vala-smoke)"
[[ "$VALA_SMOKE_OUTPUT" == vala-native-ok ]]
printf '%s\n' "$VALA_SMOKE_OUTPUT"
rm -f /root/blfs-xfce-usb-test-deps1-vala-smoke
set +x
{
  printf 'BLFS_XFCE_USB_TEST_DEPS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=3\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=compiled-pcap-umockdev+vala-smoke\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'LIBPCAP=1.10.5\n'
  printf 'LIBPCAP_TEST_SUITE=not-provided\n'
  printf 'VALA=0.56.18\n'
  printf 'VALA_TEST_SUITE=make-check-passed\n'
  printf 'VALADOC=disabled-graphviz-absent\n'
  printf 'DBUS_SESSION=vala-tests-only-stopped\n'
  printf 'UMOCKDEV=0.19.3\n'
  printf 'UMOCKDEV_TEST_SUITE=meson-selected-passed\n'
  printf 'UMOCKDEV_TEST_RECORDS=%s\n' "$UMOCKDEV_RECORDS"
  printf 'UMOCKDEV_UNEXPECTED_FAILURES=0\n'
  printf 'UMOCKDEV_TEST_SELECTION=umockdev+umockdev-vala+ioctl-tree+umockdev-run+umockdev-record+static-code\n'
  printf 'UMOCKDEV_PYTHON_TEST=not-run-pygobject-absent\n'
  printf 'UMOCKDEV_X11_TEST=skipped-by-upstream-xorg-absent\n'
  printf 'UMOCKDEV_PROGRAMS=3-present\n'
  printf 'INTROSPECTION=UMockdev-1.0\n'
  printf 'VAPI=umockdev-1.0\n'
  printf 'NATIVE_SMOKE=%s\n' "$SMOKE_OUTPUT"
  printf 'VALA_NATIVE_SMOKE=%s\n' "$VALA_SMOKE_OUTPUT"
  printf 'USB_DEVICE_ACCESS=emulation-framework-only\n'
  printf 'COLOR_DEPS=not-rebuilt\n'
  printf 'XFCE4_SETTINGS=not-rebuilt\n'
  printf 'XFCE=through-power-manager+usb-test-deps\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
