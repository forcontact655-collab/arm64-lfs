#!/usr/bin/env bash
set -euo pipefail
set -x
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
SOURCES=/sources
OVERLAY=/overlay
REPORT=/root/blfs-xfce-apps1-report.txt
PROGRESS=/root/blfs-xfce-apps1-progress.txt
NATIVE_LOG=/root/blfs-xfce-apps1-native.txt
VTE_TESTLOG=/root/blfs-xfce-apps1-vte-testlog.txt
PROBE=/tmp/blfs-xfce-apps1-x11-smoke
TEST_HOME=/tmp/blfs-xfce-apps1-home
TEST_RUNTIME=/tmp/blfs-xfce-apps1-runtime
XVFB_LOG=/root/blfs-xfce-apps1-xvfb.log
SESSION_LOG=/root/blfs-xfce-apps1-session.log
TERMINAL_LOG=/root/blfs-xfce-apps1-terminal.log
PROCESS_LOG=/root/blfs-xfce-apps1-processes.txt
X11_LOG=/root/blfs-xfce-apps1-x11.txt
SCREENSHOT=/root/blfs-xfce-apps1-screen.png
: >"$PROGRESS"
[[ -d "$OVERLAY" && -z "$(ls -A "$OVERLAY")" ]]
[[ ! -x /usr/bin/xfce4-terminal ]]
[[ ! -e /usr/include/fast_float/fast_float.h ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion libxml-2.0)" == 2.14.5 ]]
[[ "$(pkg-config --modversion libpcre2-8)" == 10.45 ]]
[[ "$(pkg-config --modversion icu-uc)" == 77.1 ]]
extract() {
  local archive="$1" directory="$2"
  cd "$SOURCES"
  rm -rf "$directory"
  tar -xf "$archive"
  cd "$directory"
}

printf 'BUILD_BLFS_XFCE_APPS1=fast_float-8.0.2\n'
extract fast_float-8.0.2.tar.gz fast_float-8.0.2
mkdir build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release -G Ninja ..
ninja
DESTDIR="$OVERLAY" ninja install
cp -a "$OVERLAY/." /
[[ -s /usr/include/fast_float/fast_float.h ]]
[[ -s /usr/share/cmake/FastFloat/FastFloatConfig.cmake ]]
printf 'BLFS_XFCE_APPS1_BUILT=fast_float-8.0.2\n' >>"$PROGRESS"

printf 'BUILD_BLFS_XFCE_APPS1=vte-0.80.3\n'
extract vte-0.80.3.tar.gz vte-0.80.3
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback \
  -D _systemd=false -D gnutls=false -D gtk3=true -D gtk4=false \
  -D vapi=false -D docs=false
ninja
ninja test
cp meson-logs/testlog.txt "$VTE_TESTLOG"
DESTDIR="$OVERLAY" ninja install
cp -a "$OVERLAY/." /
rm -f /etc/profile.d/vte.* "$OVERLAY"/etc/profile.d/vte.*
[[ "$(pkg-config --modversion vte-2.91)" == 0.80.3 ]]
printf 'BLFS_XFCE_APPS1_BUILT=vte-0.80.3\n' >>"$PROGRESS"

printf 'BUILD_BLFS_XFCE_APPS1=xfce4-terminal-1.1.5\n'
extract xfce4-terminal-1.1.5.tar.xz xfce4-terminal-1.1.5
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback \
  -D x11=enabled -D wayland=disabled -D gtk-layer-shell=disabled -D libutempter=disabled
ninja
DESTDIR="$OVERLAY" ninja install
cp -a "$OVERLAY/." /
update-desktop-database /usr/share/applications
update-desktop-database "$OVERLAY/usr/share/applications"
rm -f "$OVERLAY/usr/share/applications/mimeinfo.cache"
[[ -x /usr/bin/xfce4-terminal ]]
[[ -s /usr/share/applications/xfce4-terminal.desktop ]]
printf 'BLFS_XFCE_APPS1_BUILT=xfce4-terminal-1.1.5\n' >>"$PROGRESS"
[[ "$(grep -c '^BLFS_XFCE_APPS1_BUILT=' "$PROGRESS")" -eq 3 ]]
for program in /usr/bin/xfce4-terminal /usr/libexec/vte-urlencode-cwd; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
readelf -h /usr/lib/libvte-2.91.so | grep -q 'Machine:.*AArch64'
{
  printf 'VTE=%s\n' "$(pkg-config --modversion vte-2.91)"
  printf 'FAST_FLOAT_HEADER=8.0.2\n'
} >"$NATIVE_LOG"
grep -q '^VTE=0.80.3$' "$NATIVE_LOG"
cat "$NATIVE_LOG"
gcc /root/blfs-xfce-apps1-x11-smoke.c -o "$PROBE" $(pkg-config --cflags --libs x11 libpng)
readelf -h "$PROBE" | grep -q 'Machine:.*AArch64'
readelf -l "$PROBE" | grep -q '/lib/ld-linux-aarch64.so.1'
rm -rf "$TEST_HOME" "$TEST_RUNTIME"
mkdir -p "$TEST_HOME/.config" "$TEST_HOME/.cache" "$TEST_HOME/.local/share"
mkdir -m 0700 "$TEST_RUNTIME"
XVFB_PID=''
SESSION_PID=''
TERMINAL_PID=''
dump_logs() {
  printf '%s\n' '--- XVFB LOG ---'
  [[ ! -f "$XVFB_LOG" ]] || cat "$XVFB_LOG"
  printf '%s\n' '--- SESSION LOG ---'
  [[ ! -f "$SESSION_LOG" ]] || cat "$SESSION_LOG"
  printf '%s\n' '--- TERMINAL LOG ---'
  [[ ! -f "$TERMINAL_LOG" ]] || cat "$TERMINAL_LOG"
  printf '%s\n' '--- X11 PROBE ---'
  [[ ! -f "$X11_LOG" ]] || cat "$X11_LOG"
}
stop_terminal() {
  [[ -z "$TERMINAL_PID" ]] && return 0
  kill -TERM -- "-$TERMINAL_PID" 2>/dev/null
  for _ in {1..50}; do
    kill -0 "$TERMINAL_PID" 2>/dev/null || break
    sleep 0.1
  done
  kill -KILL -- "-$TERMINAL_PID" 2>/dev/null
  wait "$TERMINAL_PID" 2>/dev/null
  TERMINAL_PID=''
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
  stop_terminal
  stop_session
  if [[ -n "$XVFB_PID" ]]; then
    kill "$XVFB_PID" 2>/dev/null
    wait "$XVFB_PID" 2>/dev/null
    XVFB_PID=''
  fi
  rm -rf "$TEST_HOME" "$TEST_RUNTIME"
  rm -f /tmp/blfs-xfce-apps1-display /tmp/blfs-xfce-apps1-terminal-ok
  set -e
}
trap cleanup EXIT

rm -f /tmp/blfs-xfce-apps1-display
LIBGL_ALWAYS_SOFTWARE=1 Xvfb -displayfd 3 -screen 0 1280x800x24 -nolisten tcp -ac 3>/tmp/blfs-xfce-apps1-display >"$XVFB_LOG" 2>&1 &
XVFB_PID=$!
for _ in {1..100}; do
  [[ -s /tmp/blfs-xfce-apps1-display ]] && break
  kill -0 "$XVFB_PID" 2>/dev/null || { cat "$XVFB_LOG"; exit 1; }
  sleep 0.1
done
[[ -s /tmp/blfs-xfce-apps1-display ]]
DISPLAY_NUMBER="$(cat /tmp/blfs-xfce-apps1-display)"
[[ "$DISPLAY_NUMBER" =~ ^[0-9]+$ ]]
DISPLAY=":$DISPLAY_NUMBER"
[[ -S "/tmp/.X11-unix/X$DISPLAY_NUMBER" ]]
DISPLAY="$DISPLAY" "$PROBE" server >"$X11_LOG"
grep -q '^X11_CONNECTION=ok$' "$X11_LOG"
grep -q '^SCREEN=1280x800$' "$X11_LOG"
grep -q '^SERVER_VENDOR=The X.Org Foundation$' "$X11_LOG"
grep -q '^VENDOR_RELEASE=12101018$' "$X11_LOG"
DISPLAY="$DISPLAY" GDK_BACKEND=x11 xfce4-terminal --version >>"$NATIVE_LOG" 2>&1
grep -q '1.1.5' "$NATIVE_LOG"
cat "$NATIVE_LOG"

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
setsid /usr/bin/env -i \
  PATH=/usr/bin:/usr/sbin HOME="$TEST_HOME" TERM=xterm LC_ALL=C.UTF-8 \
  DISPLAY="$DISPLAY" GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 NO_AT_BRIDGE=1 \
  XDG_RUNTIME_DIR="$TEST_RUNTIME" XDG_CONFIG_HOME="$TEST_HOME/.config" \
  XDG_CACHE_HOME="$TEST_HOME/.cache" XDG_DATA_HOME="$TEST_HOME/.local/share" \
  XDG_CONFIG_DIRS=/etc/xdg XDG_DATA_DIRS=/usr/local/share:/usr/share \
  dbus-run-session -- xfce4-terminal --disable-server --title=Apps1Termux \
  --command="/bin/bash -lc 'printf APPS1_TERMINAL_EXEC_OK >/tmp/blfs-xfce-apps1-terminal-ok; exec sleep 60'" \
  >"$TERMINAL_LOG" 2>&1 &
TERMINAL_PID=$!
for _ in {1..100}; do
  [[ -s /tmp/blfs-xfce-apps1-terminal-ok ]] && break
  kill -0 "$TERMINAL_PID" 2>/dev/null || { cat "$TERMINAL_LOG"; exit 1; }
  sleep 0.1
done
grep -qx 'APPS1_TERMINAL_EXEC_OK' /tmp/blfs-xfce-apps1-terminal-ok
kill -0 "$TERMINAL_PID"
sleep 2
ps -eo stat=,comm= | awk -v n=xfce4-terminal '$2 == n && $1 !~ /^Z/ { found=1 } END { exit !found }'
ps -eo pid,ppid,stat,comm,args >"$PROCESS_LOG"
DISPLAY="$DISPLAY" "$PROBE" session "$SCREENSHOT" >>"$X11_LOG"
grep -q '^X11_WM_CHECK=present$' "$X11_LOG"
grep -qE '^X11_CLIENT_COUNT=([4-9]|[1-9][0-9]+)$' "$X11_LOG"
grep -qE '^SCREENSHOT_NON_BACKGROUND_PIXELS=[1-9][0-9]{3,}$' "$X11_LOG"
grep -qE '^SCREENSHOT_DISTINCT_COLORS_CAPPED=([2-9]|[1-9][0-9]+)$' "$X11_LOG"
! grep -q 'Could not invoke xkbcomp' "$XVFB_LOG"
[[ -s "$SCREENSHOT" ]]
dump_logs
cleanup
trap - EXIT

CLIENTS="$(awk -F= '/^X11_CLIENT_COUNT=/{value=$2} END{print value}' "$X11_LOG")"
[[ "$CLIENTS" =~ ^[0-9]+$ && "$CLIENTS" -ge 4 ]]
set +x
{
  printf 'BLFS_XFCE_APPS1_RESULT=ok
'
  printf 'PACKAGE_COUNT=3
'
  printf 'ARCH=%s
' "$(uname -m)"
  printf 'BASE_PIPELINE=83
'
  printf 'FAST_FLOAT=8.0.2
'
  printf 'FAST_FLOAT_TEST_SUITE=not-run-optional-network
'
  printf 'VTE=0.80.3
'
  printf 'VTE_TEST_SUITE=ninja-test-passed
'
  printf 'XFCE4_TERMINAL=1.1.5
'
  printf 'XFCE4_TERMINAL_TEST_SUITE=not-provided
'
  printf 'NATIVE_BINARY_EXEC=xfce4-terminal+xvfb+xfce-session
'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1
'
  printf 'TERMINAL_EXEC=APPS1_TERMINAL_EXEC_OK
'
  printf 'X11_CLIENT_COUNT=%s
' "$CLIENTS"
  printf 'DESKTOP_LAUNCH=headless-xvfb-startxfce4-terminal-ok
'
  printf 'SESSION_PROCESSES=xfce4-session+xfwm4+xfdesktop+xfce4-panel+xfsettingsd
'
  printf 'TERMINAL_PROCESS=live
'
  printf 'SCREENSHOT=png-terminal-visible-required
'
  printf 'OVERLAY_CONTENT=fast_float+vte+xfce4-terminal
'
  printf 'TEST_HOME=ephemeral-removed
'
  printf 'SESSION_STATE=stopped-after-validation
'
  printf 'DEFAULT_DESKTOP_IS_FINAL=no
'
  printf 'REAL_DISPLAY=not-tested
'
  printf 'HARDWARE_GRAPHICS=not-tested
'
  printf 'EXISTING_ARCH=not-accessed-not-modified
'
  printf 'BOOTABLE=no
'
} >"$REPORT"
cat "$REPORT"
rm -f "$PROBE"
