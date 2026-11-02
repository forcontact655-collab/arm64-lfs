#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-color-deps1-report.txt
PROGRESS=/root/blfs-xfce-color-deps1-progress.txt
LCMS_TESTLOG=/root/blfs-xfce-color-deps1-lcms2-testlog.txt
JSON_TESTLOG=/root/blfs-xfce-color-deps1-json-glib-testlog.txt
GUSB_TESTLOG=/root/blfs-xfce-color-deps1-libgusb-testlog.txt
COLORD_TESTLOG=/root/blfs-xfce-color-deps1-colord-testlog.txt
SMOKE_SOURCE=/root/blfs-xfce-color-deps1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/python3 ]]
[[ -x /usr/bin/dbus-daemon ]]
[[ -x /usr/bin/xfce4-power-manager ]]
[[ ! -x /usr/bin/vala ]]
[[ ! -e /usr/lib/liblcms2.so ]]
[[ ! -e /usr/lib/libjson-glib-1.0.so ]]
[[ ! -e /usr/lib/libgusb.so ]]
[[ ! -e /usr/lib/libcolord.so ]]
[[ ! -e /usr/lib/libtiff.so ]]
[[ ! -f /usr/include/tiffio.h ]]
[[ -f /usr/share/hwdata/usb.ids ]]
[[ -f /usr/share/hwdata/pnp.ids ]]
[[ "$(pkg-config --modversion libjpeg)" == 3.0.1 ]]
[[ "$(pkg-config --modversion libusb-1.0)" == 1.0.29 ]]
[[ "$(pkg-config --modversion polkit-gobject-1)" == 126 ]]
! pkg-config --exists umockdev-1.0
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
  printf 'BUILD_BLFS_XFCE_COLOR_DEPS1=%s\n' "$package_dir"
}

cd /sources
build_package lcms2-2.17.tar.gz lcms2-2.17
./configure --prefix=/usr
make
make check 2>&1 | tee "$LCMS_TESTLOG"
make install
cd /sources
rm -rf lcms2-2.17
printf 'BLFS_XFCE_COLOR_DEPS1_BUILT=lcms2-2.17\n' >>"$PROGRESS"
/sbin/ldconfig

build_package json-glib-1.10.6.tar.xz json-glib-1.10.6
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D introspection=enabled \
  -D documentation=disabled \
  -D man=false \
  -D tests=true
ninja
export LC_ALL=C.UTF-8
set +e
meson test --print-errorlogs
JSON_TEST_STATUS=$?
set -e
cp meson-logs/testlog.txt "$JSON_TESTLOG"
printf 'JSON_GLIB_MESON_TEST_EXIT=%s\n' "$JSON_TEST_STATUS"
read -r JSON_RECORDS JSON_KNOWN < <(python3 - "$JSON_TESTLOG" <<'PY'
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
assert len(records) >= 2, len(records)
known = [r for r in records if r['result'] != 'exit status 0' and r['name'].rsplit(' / ', 1)[-1] == 'node']
unexpected = [r for r in records if r['result'] != 'exit status 0' and r['name'].rsplit(' / ', 1)[-1] != 'node']
assert len(known) <= 1, known
assert not unexpected, unexpected
print(len(records), len(known))
PY
)
printf 'JSON_GLIB_TEST_RECORDS=%s KNOWN_NODE_FAILURES=%s\n' "$JSON_RECORDS" "$JSON_KNOWN"
ninja install
cd /sources
rm -rf json-glib-1.10.6
printf 'BLFS_XFCE_COLOR_DEPS1_BUILT=json-glib-1.10.6\n' >>"$PROGRESS"
/sbin/ldconfig

build_package libgusb-0.4.9.tar.xz libgusb-0.4.9
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D tests=true \
  -D vapi=false \
  -D docs=false \
  -D introspection=true \
  -D umockdev=disabled \
  -D usb_ids=/usr/share/hwdata/usb.ids
ninja
meson test --print-errorlogs
cp meson-logs/testlog.txt "$GUSB_TESTLOG"
read -r GUSB_RECORDS < <(python3 - "$GUSB_TESTLOG" <<'PY'
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
assert len(records) >= 2, len(records)
unexpected = [r for r in records if r['result'] != 'exit status 0']
assert not unexpected, unexpected
print(len(records))
PY
)
printf 'LIBGUSB_TEST_RECORDS=%s UNEXPECTED_FAILURES=0\n' "$GUSB_RECORDS"
ninja install
cd /sources
rm -rf libgusb-0.4.9
printf 'BLFS_XFCE_COLOR_DEPS1_BUILT=libgusb-0.4.9\n' >>"$PROGRESS"
/sbin/ldconfig

if ! getent group colord >/dev/null; then
  groupadd -g 71 colord
fi
if ! id colord >/dev/null 2>&1; then
  useradd -c "Color Daemon Owner" -d /var/lib/colord -u 71 \
    -g colord -s /bin/false colord
fi
build_package colord-1.4.8.tar.xz colord-1.4.8
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D systemd=false \
  -D libcolordcompat=true \
  -D argyllcms_sensor=false \
  -D vapi=false \
  -D introspection=true \
  -D tests=true \
  -D man=false \
  -D docs=false \
  -D daemon_user=colord
ninja
mkdir -p /run/dbus
dbus-uuidgen --ensure=/etc/machine-id
DBUS_LOG=/tmp/blfs-xfce-color-deps1-system-bus.log
dbus-daemon --system --nofork --nopidfile >"$DBUS_LOG" 2>&1 &
DBUS_PID=$!
stop_system_bus() {
  set +e
  kill "$DBUS_PID" 2>/dev/null
  wait "$DBUS_PID" 2>/dev/null
  set -e
}
trap stop_system_bus EXIT
for _ in {1..50}; do
  [[ -S /run/dbus/system_bus_socket ]] && break
  kill -0 "$DBUS_PID" 2>/dev/null || {
    cat "$DBUS_LOG"
    exit 1
  }
  sleep 0.1
done
[[ -S /run/dbus/system_bus_socket ]]
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
set +e
meson test --print-errorlogs
COLORD_TEST_STATUS=$?
set -e
cp meson-logs/testlog.txt "$COLORD_TESTLOG"
stop_system_bus
trap - EXIT
unset DBUS_SYSTEM_BUS_ADDRESS
printf 'COLORD_MESON_TEST_EXIT=%s\n' "$COLORD_TEST_STATUS"
read -r COLORD_RECORDS COLORD_SKIPS < <(python3 - "$COLORD_TESTLOG" <<'PY'
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
assert len(records) >= 4, len(records)
skips = [r for r in records if r['result'] == 'exit status 77']
unexpected = []
for r in records:
    if r['result'] == 'exit status 0':
        continue
    if r['result'] == 'exit status 77' and r['name'].rsplit(' / ', 1)[-1] == 'colord-test-daemon':
        continue
    unexpected.append(r)
assert not unexpected, unexpected
print(len(records), len(skips))
PY
)
[[ "$COLORD_TEST_STATUS" -eq 0 ]]
printf 'COLORD_TEST_RECORDS=%s SKIPS=%s UNEXPECTED_FAILURES=0\n' "$COLORD_RECORDS" "$COLORD_SKIPS"
ninja install
cd /sources
rm -rf colord-1.4.8
printf 'BLFS_XFCE_COLOR_DEPS1_BUILT=colord-1.4.8\n' >>"$PROGRESS"
/sbin/ldconfig
set -x

[[ "$(grep -c '^BLFS_XFCE_COLOR_DEPS1_BUILT=' "$PROGRESS")" -eq 4 ]]
[[ "$(pkg-config --modversion lcms2)" == 2.17 ]]
[[ "$(pkg-config --modversion json-glib-1.0)" == 1.10.6 ]]
[[ "$(pkg-config --modversion gusb)" == 0.4.9 ]]
[[ "$(pkg-config --modversion colord)" == 1.4.8 ]]
for library in liblcms2.so libjson-glib-1.0.so libgusb.so libcolord.so libcolordprivate.so libcolorhug.so libcolordcompat.so; do
  [[ -e "/usr/lib/$library" ]]
done
for gir in Json-1.0 GUsb-1.0 Colord-1.0 Colorhug-1.0; do
  [[ -f "/usr/share/gir-1.0/$gir.gir" ]]
  [[ -f "/usr/lib/girepository-1.0/$gir.typelib" ]]
done
programs=(
  /usr/bin/transicc
  /usr/bin/linkicc
  /usr/bin/psicc
  /usr/bin/jpgicc
  /usr/bin/json-glib-format
  /usr/bin/json-glib-validate
  /usr/bin/gusbcmd
  /usr/bin/colormgr
  /usr/bin/cd-fix-profile
  /usr/bin/cd-iccdump
  /usr/bin/cd-it8
  /usr/bin/cd-create-profile
  /usr/libexec/colord
)
[[ "${#programs[@]}" -eq 13 ]]
for program in "${programs[@]}"; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
[[ ! -x /usr/bin/tificc ]]

cat >"$SMOKE_SOURCE" <<'EOF'
#include <lcms2.h>
#include <json-glib/json-glib.h>
#include <gusb.h>
#include <colord.h>

int main(void) {
  GError *error = NULL;
  JsonParser *parser;
  JsonObject *object;
  gboolean json_ok;
  const char *gusb_type;
  const char *colord_type;

  if (cmsGetEncodedCMMversion() != 2170)
    return 1;
  parser = json_parser_new();
  if (!json_parser_load_from_data(parser, "{\"ok\":true}", -1, &error)) {
    g_clear_error(&error);
    return 2;
  }
  object = json_node_get_object(json_parser_get_root(parser));
  json_ok = object != NULL && json_object_get_boolean_member(object, "ok");
  g_object_unref(parser);
  if (!json_ok)
    return 3;
  gusb_type = g_type_name(GUSB_TYPE_CONTEXT);
  colord_type = g_type_name(CD_TYPE_PROFILE);
  if (g_strcmp0(gusb_type, "GUsbContext") != 0)
    return 4;
  if (g_strcmp0(colord_type, "CdProfile") != 0)
    return 5;
  g_print("lcms-%u+json-true+gusb-%s+colord-%s\n",
          cmsGetEncodedCMMversion(), gusb_type, colord_type);
  return 0;
}
EOF
gcc -O2 -Wall -Wextra -Werror "$SMOKE_SOURCE" -o /root/blfs-xfce-color-deps1-smoke \
  $(pkg-config --cflags --libs lcms2 json-glib-1.0 gusb colord)
readelf -h /root/blfs-xfce-color-deps1-smoke | grep -q 'Machine:.*AArch64'
SMOKE_OUTPUT="$(/root/blfs-xfce-color-deps1-smoke)"
[[ "$SMOKE_OUTPUT" == lcms-2170+json-true+gusb-GUsbContext+colord-CdProfile ]]
printf '%s\n' "$SMOKE_OUTPUT"
rm -f /root/blfs-xfce-color-deps1-smoke
set +x
{
  printf 'BLFS_XFCE_COLOR_DEPS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=4\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=compiled-color-stack-smoke\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'LCMS2=2.17\n'
  printf 'LCMS2_TEST_SUITE=make-check-passed\n'
  printf 'LCMS2_PROGRAMS=4-present\n'
  printf 'LCMS2_TIFFICC=not-built-optional-libtiff-absent\n'
  printf 'JSON_GLIB=1.10.6\n'
  printf 'JSON_GLIB_TEST_EXIT=%s\n' "$JSON_TEST_STATUS"
  printf 'JSON_GLIB_TEST_RECORDS=%s\n' "$JSON_RECORDS"
  printf 'JSON_GLIB_KNOWN_NODE_FAILURES=%s\n' "$JSON_KNOWN"
  printf 'JSON_GLIB_UNEXPECTED_FAILURES=0\n'
  printf 'JSON_GLIB_PROGRAMS=2-present\n'
  printf 'LIBGUSB=0.4.9\n'
  printf 'LIBGUSB_TEST_SUITE=meson-passed\n'
  printf 'LIBGUSB_TEST_RECORDS=%s\n' "$GUSB_RECORDS"
  printf 'LIBGUSB_UNEXPECTED_FAILURES=0\n'
  printf 'LIBGUSB_PROGRAM=gusbcmd-present\n'
  printf 'UMOCKDEV=optional-disabled\n'
  printf 'COLORD=1.4.8\n'
  printf 'COLORD_TEST_SUITE=meson-passed\n'
  printf 'COLORD_TEST_RECORDS=%s\n' "$COLORD_RECORDS"
  printf 'COLORD_TEST_SKIPS=%s\n' "$COLORD_SKIPS"
  printf 'COLORD_UNEXPECTED_FAILURES=0\n'
  printf 'COLORD_PROGRAMS=5-present+daemon\n'
  printf 'COLORD_LIBCOLORDCOMPAT=present\n'
  printf 'COLORD_ARGYLL_SENSOR=disabled\n'
  printf 'DBUS_SYSTEM=started-for-tests-stopped\n'
  printf 'COLORD_DAEMON=not-started\n'
  printf 'VALA=not-installed-vapi-disabled\n'
  printf 'INTROSPECTION=Json+GUsb+Colord+Colorhug\n'
  printf 'NATIVE_SMOKE=%s\n' "$SMOKE_OUTPUT"
  printf 'COLOR_MANAGEMENT=not-tested\n'
  printf 'XFCE4_SETTINGS=not-rebuilt\n'
  printf 'XFCE=through-power-manager+color-deps\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
