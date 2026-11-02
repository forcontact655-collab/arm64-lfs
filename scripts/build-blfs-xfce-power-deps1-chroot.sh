#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-power-deps1-report.txt
PROGRESS=/root/blfs-xfce-power-deps1-progress.txt
TESTLOG=/root/blfs-xfce-power-deps1-upower-testlog.jsonl
SMOKE_SOURCE=/root/blfs-xfce-power-deps1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ ! -e /usr/lib/libusb-1.0.so ]]
[[ ! -x /usr/bin/upower ]]
[[ ! -e /usr/lib/libupower-glib.so ]]
[[ "$(pkg-config --modversion gudev-1.0)" == 238 ]]
[[ -x /usr/bin/xfce4-appfinder ]]
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
  printf 'BUILD_BLFS_XFCE_POWER_DEPS1=%s\n' "$package_dir"
}

cd /sources
build_package libusb-1.0.29.tar.bz2 libusb-1.0.29
./configure --prefix=/usr --disable-static
make
make install
cd /sources
rm -rf libusb-1.0.29
printf 'BLFS_XFCE_POWER_DEPS1_BUILT=libusb-1.0.29\n' >>"$PROGRESS"

build_package upower-v1.90.9.tar.bz2 upower-v1.90.9
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D gtk-doc=false \
  -D man=false \
  -D polkit=disabled \
  -D idevice=disabled \
  -D systemdsystemunitdir=no \
  -D udevrulesdir=/usr/lib/udev/rules.d
ninja
export LC_ALL=C
meson test --print-errorlogs self-test
cp meson-logs/testlog.jsonl "$TESTLOG"
ninja install
cd /sources
rm -rf upower-v1.90.9
printf 'BLFS_XFCE_POWER_DEPS1_BUILT=upower-1.90.9\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_POWER_DEPS1_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ "$(pkg-config --modversion libusb-1.0)" == 1.0.29 ]]
[[ "$(pkg-config --modversion upower-glib)" == 1.90.9 ]]
[[ -e /usr/lib/libusb-1.0.so ]]
[[ -e /usr/lib/libupower-glib.so ]]
[[ -x /usr/bin/upower ]]
[[ -x /usr/libexec/upowerd ]]
[[ -f /usr/share/dbus-1/system-services/org.freedesktop.UPower.service ]]
[[ ! -e /usr/lib/systemd/system/upower.service ]]
for program in /usr/bin/upower /usr/libexec/upowerd; do
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

cat >"$SMOKE_SOURCE" <<'EOF'
#include <libusb-1.0/libusb.h>
#include <libupower-glib/upower.h>
#include <stdio.h>

int main(void) {
  const struct libusb_version *version = libusb_get_version();
  GType client_type = up_client_get_type();
  GType device_type = up_device_get_type();
  printf("BLFS_XFCE_POWER_DEPS1_EXEC_OK=libusb-%u.%u.%u+upower-types-%lu-%lu\n",
         version->major, version->minor, version->micro,
         (unsigned long) client_type, (unsigned long) device_type);
  return version->major == 1 && version->minor == 0 && version->micro == 29 &&
                 client_type != 0 && device_type != 0
             ? 0
             : 1;
}
EOF
cc "$SMOKE_SOURCE" -o /root/blfs-xfce-power-deps1-smoke \
  $(pkg-config --cflags --libs libusb-1.0 upower-glib)
OUTPUT="$(/root/blfs-xfce-power-deps1-smoke)"
printf '%s\n' "$OUTPUT"
[[ "$OUTPUT" =~ ^BLFS_XFCE_POWER_DEPS1_EXEC_OK=libusb-1\.0\.29\+upower-types-[1-9][0-9]*-[1-9][0-9]*$ ]]
set +e
HELP_OUTPUT="$(upower --help 2>&1)"
HELP_STATUS=$?
set -e
printf '%s\n' "$HELP_OUTPUT"
[[ "$HELP_STATUS" -eq 0 ]]
grep -q -- '--version' <<<"$HELP_OUTPUT"
rm -f /root/blfs-xfce-power-deps1-smoke
set +x
{
  printf 'BLFS_XFCE_POWER_DEPS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=2\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=libusb-upower-native-c-and-cli-help\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'XFCE4_APPFINDER=4.20.0\n'
  printf 'LIBUSB=1.0.29\n'
  printf 'LIBUSB_TEST_SUITE=not-provided\n'
  printf 'UPOWER=1.90.9\n'
  printf 'UPOWER_SELF_TEST=passed\n'
  printf 'UPOWER_INTEGRATION_TESTS=not-run-optional-dbusmock-umockdev-session-deps-absent\n'
  printf 'UPOWER_CLI_SMOKE=help-only-no-daemon\n'
  printf 'POLKIT=not-built-recommended-deferred\n'
  printf 'USB_DEVICE_ACCESS=not-tested\n'
  printf 'UPOWER_DAEMON=not-started\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'XFCE=through-appfinder+power-deps\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
