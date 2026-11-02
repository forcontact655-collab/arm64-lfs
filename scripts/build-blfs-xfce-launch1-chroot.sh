#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --disable-static"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-launch1-report.txt
PROGRESS=/root/blfs-xfce-launch1-progress.txt
XORG_TESTLOG=/root/blfs-xfce-launch1-xorg-testlog.txt
NATIVE_LOG=/root/blfs-xfce-launch1-native.txt
XVFB_LOG=/root/blfs-xfce-launch1-xvfb.log
SESSION_LOG=/root/blfs-xfce-launch1-session.log
PROCESS_LOG=/root/blfs-xfce-launch1-processes.txt
X11_LOG=/root/blfs-xfce-launch1-x11.txt
SCREENSHOT=/root/blfs-xfce-launch1-screen.png
PROBE=/tmp/blfs-xfce-launch1-x11-smoke
TEST_HOME=/tmp/blfs-xfce-launch1-home
TEST_RUNTIME=/tmp/blfs-xfce-launch1-runtime
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc && -x /usr/bin/meson && -x /usr/bin/ninja ]]
[[ -x /usr/bin/dbus-run-session && -x /usr/bin/setsid && -x /usr/bin/ps ]]
[[ -x /usr/bin/iceauth && -x /usr/bin/xfdesktop && -x /usr/bin/xfwm4 ]]
[[ -x /usr/bin/xfce4-session && -x /usr/bin/xfce4-panel && -x /usr/bin/xfsettingsd ]]
[[ ! -x /usr/bin/cvt && ! -x /usr/bin/xkbcomp && ! -x /usr/bin/Xvfb && ! -x /usr/bin/xrdb ]]
[[ -e /usr/lib/libepoxy.so ]]
[[ ! -e /usr/lib/libxcvt.so ]]
[[ -s /root/blfs-xfce-launch1-x11-smoke.c ]]
[[ "$(pkg-config --modversion xkeyboard-config)" == 2.45 ]]
[[ "$(pkg-config --modversion epoxy)" == 1.5.10 ]]
[[ "$(pkg-config --modversion libelogind)" == 255 ]]
[[ -d /sources ]]
: >"$PROGRESS"

build_package() {
  local archive="$1" expected="$2" first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"
  package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  printf 'BUILD_BLFS_XFCE_LAUNCH1=%s\n' "$package_dir"
}
finish_package() {
  local package_dir="$1"
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_XFCE_LAUNCH1_BUILT=%s\n' "$package_dir" >>"$PROGRESS"
  /sbin/ldconfig
}

build_package libxcvt-0.1.3.tar.xz libxcvt-0.1.3
mkdir build
cd build
meson setup --prefix=/usr --libdir=lib --buildtype=release ..
ninja
ninja install
finish_package libxcvt-0.1.3

build_package font-util-1.4.1.tar.xz font-util-1.4.1
./configure $XORG_CONFIG
make
make install
finish_package font-util-1.4.1

build_package xkbcomp-1.4.7.tar.xz xkbcomp-1.4.7
./configure $XORG_CONFIG
make
make install
finish_package xkbcomp-1.4.7

build_package xorg-server-21.1.18.tar.xz xorg-server-21.1.18
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --localstatedir=/var \
  -D glamor=true \
  -D systemd_logind=true \
  -D secure-rpc=false \
  -D xvfb=true \
  -D docs=false \
  -D devel-docs=false \
  -D xkb_output_dir=/var/lib/xkb
ninja
/sbin/ldconfig
ninja test
cp meson-logs/testlog.txt "$XORG_TESTLOG"
ninja install
finish_package xorg-server-21.1.18
mkdir -p /etc/X11/xorg.conf.d /var/lib/xkb
install -d -m1777 /tmp/.ICE-unix /tmp/.X11-unix
touch /etc/sysconfig/createfiles
grep -qxF '/tmp/.ICE-unix dir 1777 root root' /etc/sysconfig/createfiles || printf '/tmp/.ICE-unix dir 1777 root root\n' >>/etc/sysconfig/createfiles
grep -qxF '/tmp/.X11-unix dir 1777 root root' /etc/sysconfig/createfiles || printf '/tmp/.X11-unix dir 1777 root root\n' >>/etc/sysconfig/createfiles

build_package xrdb-1.2.2.tar.xz xrdb-1.2.2
./configure $XORG_CONFIG
make
make install
finish_package xrdb-1.2.2
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_LAUNCH1_BUILT=' "$PROGRESS")" -eq 5 ]]
[[ "$(pkg-config --modversion libxcvt)" == 0.1.3 ]]
[[ "$(pkg-config --modversion fontutil)" == 1.4.1 ]]
[[ "$(pkg-config --modversion xkbcomp)" == 1.4.7 ]]
[[ -x /usr/bin/bdftruncate && -x /usr/bin/ucs2any ]]
[[ -s /usr/share/fonts/X11/util/map-ISO8859-1 ]]
programs=(/usr/bin/cvt /usr/bin/xkbcomp /usr/bin/Xvfb /usr/bin/Xorg /usr/bin/xrdb)
for program in "${programs[@]}"; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
{
  cvt 1280 800 60
  xkbcomp -version
  xrdb -version
} >"$NATIVE_LOG"
grep -q 'Modeline.*1280x800' "$NATIVE_LOG"
grep -q '^xkbcomp 1.4.7$' "$NATIVE_LOG"
grep -q '^xrdb 1.2.2$' "$NATIVE_LOG"
cat "$NATIVE_LOG"
grep -qE 'Ok: *5' "$XORG_TESTLOG"
grep -qE 'Fail: *0' "$XORG_TESTLOG"
grep -qE 'Skipped: *1' "$XORG_TESTLOG"
grep -q 'XTS' "$XORG_TESTLOG"
grep -q 'exit status 77' "$XORG_TESTLOG"
! grep -qE 'Fail: *[1-9]|ERROR: *[1-9]' "$XORG_TESTLOG"

gcc /root/blfs-xfce-launch1-x11-smoke.c -o "$PROBE" $(pkg-config --cflags --libs x11 libpng)
readelf -h "$PROBE" | grep -q 'Machine:.*AArch64'
readelf -l "$PROBE" | grep -q '/lib/ld-linux-aarch64.so.1'
rm -rf "$TEST_HOME" "$TEST_RUNTIME"
mkdir -p "$TEST_HOME/.config" "$TEST_HOME/.cache" "$TEST_HOME/.local/share"
mkdir -m 0700 "$TEST_RUNTIME"
XVFB_PID=''
SESSION_PID=''
dump_logs() {
  printf '%s\n' '--- XVFB LOG ---'
  [[ ! -f "$XVFB_LOG" ]] || cat "$XVFB_LOG"
  printf '%s\n' '--- SESSION LOG ---'
  [[ ! -f "$SESSION_LOG" ]] || cat "$SESSION_LOG"
  printf '%s\n' '--- X11 PROBE ---'
  [[ ! -f "$X11_LOG" ]] || cat "$X11_LOG"
}
stop_session() {
  [[ -z "$SESSION_PID" ]] && return 0
  kill -TERM -- "-$SESSION_PID" 2>/dev/null
  for _ in {1..50}; do
    kill -0 "$SESSION_PID" 2>/dev/null || break
    sleep 0.1
  done
  kill -KILL -- "-$SESSION_PID" 2>/dev/null
  wait "$SESSION_PID" 2>/dev/null
  SESSION_PID=''
}
cleanup() {
  local status=$?
  set +e
  if [[ "$status" -ne 0 ]]; then dump_logs; fi
  stop_session
  if [[ -n "$XVFB_PID" ]]; then
    kill "$XVFB_PID" 2>/dev/null
    wait "$XVFB_PID" 2>/dev/null
    XVFB_PID=''
  fi
  rm -rf "$TEST_HOME" "$TEST_RUNTIME"
  rm -f /tmp/blfs-xfce-launch1-display
  set -e
}
trap cleanup EXIT

rm -f /tmp/blfs-xfce-launch1-display
LIBGL_ALWAYS_SOFTWARE=1 Xvfb -displayfd 3 -screen 0 1280x800x24 -nolisten tcp -ac 3>/tmp/blfs-xfce-launch1-display >"$XVFB_LOG" 2>&1 &
XVFB_PID=$!
for _ in {1..100}; do
  [[ -s /tmp/blfs-xfce-launch1-display ]] && break
  kill -0 "$XVFB_PID" 2>/dev/null || { cat "$XVFB_LOG"; exit 1; }
  sleep 0.1
done
[[ -s /tmp/blfs-xfce-launch1-display ]]
DISPLAY_NUMBER="$(cat /tmp/blfs-xfce-launch1-display)"
[[ "$DISPLAY_NUMBER" =~ ^[0-9]+$ ]]
DISPLAY=":$DISPLAY_NUMBER"
[[ -S "/tmp/.X11-unix/X$DISPLAY_NUMBER" ]]
DISPLAY="$DISPLAY" "$PROBE" server >"$X11_LOG"
grep -q '^X11_CONNECTION=ok$' "$X11_LOG"
grep -q '^SCREEN=1280x800$' "$X11_LOG"
grep -q '^SERVER_VENDOR=The X.Org Foundation$' "$X11_LOG"
grep -q '^VENDOR_RELEASE=12101018$' "$X11_LOG"

setsid /usr/bin/env -i \
  PATH=/usr/bin:/usr/sbin \
  HOME="$TEST_HOME" \
  TERM=xterm \
  LC_ALL=C.UTF-8 \
  DISPLAY="$DISPLAY" \
  GDK_BACKEND=x11 \
  LIBGL_ALWAYS_SOFTWARE=1 \
  NO_AT_BRIDGE=1 \
  XDG_RUNTIME_DIR="$TEST_RUNTIME" \
  XDG_CONFIG_HOME="$TEST_HOME/.config" \
  XDG_CACHE_HOME="$TEST_HOME/.cache" \
  XDG_DATA_HOME="$TEST_HOME/.local/share" \
  XDG_CONFIG_DIRS=/etc/xdg \
  XDG_DATA_DIRS=/usr/local/share:/usr/share \
  dbus-run-session -- startxfce4 >"$SESSION_LOG" 2>&1 &
SESSION_PID=$!
sleep 20
kill -0 "$SESSION_PID"
ps -eo pid,ppid,stat,comm,args >"$PROCESS_LOG"
cat "$PROCESS_LOG"
for name in xfce4-session xfwm4 xfdesktop xfce4-panel xfsettingsd; do
  ps -eo stat=,comm= | awk -v n="$name" '$2 == n && $1 !~ /^Z/ { found=1 } END { exit !found }'
done
DISPLAY="$DISPLAY" "$PROBE" session "$SCREENSHOT" >>"$X11_LOG"
grep -q '^X11_WM_CHECK=present$' "$X11_LOG"
grep -qE '^X11_CLIENT_COUNT=[1-9][0-9]*$' "$X11_LOG"
grep -qE '^SCREENSHOT_NON_BACKGROUND_PIXELS=[1-9][0-9]{3,}$' "$X11_LOG"
grep -qE '^SCREENSHOT_DISTINCT_COLORS_CAPPED=([2-9]|[1-9][0-9]+)$' "$X11_LOG"
! grep -q 'Could not invoke xkbcomp' "$XVFB_LOG"
[[ -s "$SCREENSHOT" ]]
dump_logs
cleanup
trap - EXIT
set +x
{
  printf 'BLFS_XFCE_LAUNCH1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=5\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=cvt+xkbcomp+xrdb+xvfb+xfce-session\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'LIBXCVT=0.1.3\n'
  printf 'LIBXCVT_TEST_SUITE=not-provided\n'
  printf 'FONT_UTIL=1.4.1\n'
  printf 'FONT_UTIL_TEST_SUITE=not-provided\n'
  printf 'XKBCOMP=1.4.7\n'
  printf 'XKBCOMP_TEST_SUITE=not-provided\n'
  printf 'XORG_SERVER=21.1.18\n'
  printf 'XORG_VENDOR_RELEASE=12101018\n'
  printf 'XORG_TEST_SUITE=ninja-test-passed\n'
  printf 'XORG_TESTS=5-ok+1-xts-skip+0-failed\n'
  printf 'XRDB=1.2.2\n'
  printf 'XRDB_TEST_SUITE=not-provided\n'
  printf 'XVFB=1280x800x24-no-tcp-auto-display\n'
  printf 'XVFB_ACCESS_CONTROL=disabled-for-isolated-test-only\n'
  printf 'LIBGL=software-forced\n'
  printf 'STARTXFCE4=executed-with-existing-display\n'
  printf 'XINIT=not-used\n'
  printf 'DESKTOP_LAUNCH=headless-xvfb-startxfce4-ok\n'
  printf 'SESSION_PROCESSES=xfce4-session+xfwm4+xfdesktop+xfce4-panel+xfsettingsd\n'
  printf 'X11_WM_CHECK=present\n'
  printf 'X11_CLIENT_LIST=nonempty\n'
  printf 'SCREENSHOT=png-nonblank\n'
  printf 'TEST_HOME=ephemeral-removed\n'
  printf 'SESSION_STATE=stopped-after-validation\n'
  printf 'XFCE_CORE=18-of-18\n'
  printf 'REAL_DISPLAY=not-tested\n'
  printf 'HARDWARE_GRAPHICS=not-tested\n'
  printf 'ROOTLESS_XORG=not-tested\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f "$PROBE"
