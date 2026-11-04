#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-visual1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_XFCE_VISUAL1_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-visual1-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for p in /usr/bin/startxfce4 /usr/bin/xfconf-query /usr/bin/xfce4-terminal /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/Xvfb /usr/bin/dbus-run-session; do
  [[ -x "$LFS$p" ]] || preflight_fail "missing-$p"
done
[[ -f "$HOST_SOURCES/146271413_p0.png" ]] || preflight_fail missing-wallpaper-source
[[ ! -e "$LFS/usr/share/themes/VimAnimeDark" ]] || preflight_fail existing-visual-theme
[[ ! -e "$LFS/usr/local/bin/vim-xfce-visual-apply" ]] || preflight_fail existing-visual-applier
[[ ! -e "$LFS/usr/local/bin/vim-xfce-monitor-names" ]] || preflight_fail existing-monitor-helper
[[ ! -e "$LFS/root/.config/xfce4" ]] || preflight_fail existing-root-xfce-profile
mkdir -p "$ARTIFACTS"
sudo -n true || preflight_fail sudo
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-visual1-chroot.sh" "$LFS/root/build-blfs-xfce-visual1-chroot.sh"
sudo -n install -m 0644 "$REPO/scripts/blfs-xfce-launch1-x11-smoke.c" "$LFS/root/blfs-xfce-launch1-x11-smoke.c"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/local/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-xfce-visual1-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
for name in report.txt progress.txt values.txt x11.txt session.log apply.log xvfb.log terminal.log theme-sha256sums.txt profile-sha256sums.txt screenshot-stats.txt screen-desktop.png screen-terminal.png; do
  if sudo -n test -f "$LFS/root/blfs-xfce-visual1-$name"; then
    sudo -n cat "$LFS/root/blfs-xfce-visual1-$name" >"$ARTIFACTS/blfs-xfce-visual1-$name"
  fi
done
if sudo -n test -f "$LFS/usr/share/backgrounds/vim/generated/lilith-memory-paradise-1280x800.png"; then
  sudo -n cat "$LFS/usr/share/backgrounds/vim/generated/lilith-memory-paradise-1280x800.png" >"$ARTIFACTS/blfs-xfce-visual1-wallpaper-1280x800.png"
fi
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_XFCE_VISUAL1_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
for name in xsettings.xml xfwm4.xml xfce4-panel.xml xfce4-desktop.xml xfce4-terminal.xml; do
  sudo -n cat "$LFS/root/.config/xfce4/xfconf/xfce-perchannel-xml/$name" >"$ARTIFACTS/blfs-xfce-visual1-profile-$name"
done
for name in themerc gtk.css title-1-active.xpm; do
  case "$name" in
    themerc) source="$LFS/usr/share/themes/VimAnimeDark/xfwm4/themerc" ;;
    gtk.css) source="$LFS/usr/share/themes/VimAnimeDark/gtk-3.0/gtk.css" ;;
    *) source="$LFS/usr/share/themes/VimAnimeDark/xfwm4/$name" ;;
  esac
  sudo -n cat "$source" >"$ARTIFACTS/blfs-xfce-visual1-theme-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-visual1-chroot.sh" "$LFS/root/blfs-xfce-launch1-x11-smoke.c" \
  "$LFS"/root/blfs-xfce-visual1-{report.txt,progress.txt,values.txt,x11.txt,session.log,apply.log,xvfb.log,terminal.log,theme-sha256sums.txt,profile-sha256sums.txt,screenshot-stats.txt,screen-desktop.png,screen-terminal.png} \
  "$LFS/root/blfs-xfce-visual1-session.sh" "$LFS/root/blfs-xfce-visual1-session.log.launcher"
REPORT="$ARTIFACTS/blfs-xfce-visual1-report.txt"
for expected in \
  'BLFS_XFCE_VISUAL1_RESULT=ok' 'PACKAGE_COUNT=0' 'ARCH=aarch64' 'BASE_PIPELINE=156' \
  'XFCE_CORE=18-of-18' 'XFCE_APPS=pipeline-87' 'GTK_THEME=VimAnimeDark' 'XFWM_THEME=VimAnimeDark' 'XFWM_ASSETS=xpm-only' \
  'PANEL_STYLE=dark-navy-cyan-pink' 'TERMINAL_STYLE=dark-navy-transparent' 'TERMINAL_EXEC=VIM_XFCE_VISUAL_TERMINAL_EXEC_OK' \
  'DESKTOP_LAUNCH=headless-xvfb-startxfce4-terminal-ok' 'SCREENSHOT_DESKTOP=png-wallpaper-visible' 'SCREENSHOT_TERMINAL=png-terminal-visible-required' 'SCREENSHOT_PIXEL_ACCEPTANCE=desktop-nonblack-bright-colorful' \
  'WALLPAPER=Lilith-Memory-Paradise' 'WALLPAPER_RENDER=rawvideo-final-darkening' 'DESKTOP_COLOR_STYLE=solid-dark' 'WALLPAPER_DERIVATIVE=1280x800' 'PERSISTENT_PROFILE=/root/.config/xfce4' 'MONITOR_DETECTION=native-xrandr' \
  'ADAPTIVE_WALLPAPER=generated-on-apply-no-watcher' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'EXISTING_ARCH=not-accessed-not-modified' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_XFCE_VISUAL1_BUILT=' "$ARTIFACTS/blfs-xfce-visual1-progress.txt")" -eq 1 ]]
grep -q '^X11_WM_CHECK=present$' "$ARTIFACTS/blfs-xfce-visual1-x11.txt"
grep -q 'lilith-memory-paradise-1280x800.png' "$ARTIFACTS/blfs-xfce-visual1-values.txt"
grep -q 'xsettings /Net/ThemeName=VimAnimeDark' "$ARTIFACTS/blfs-xfce-visual1-values.txt"
grep -q 'xfwm4 /general/theme=VimAnimeDark' "$ARTIFACTS/blfs-xfce-visual1-values.txt"
grep -q 'VIM_XFCE_VISUAL_APPLY_OK' "$ARTIFACTS/blfs-xfce-visual1-apply.log"
grep -q '^SCREENSHOT_WALLPAPER_ACCEPTANCE=ok$' "$ARTIFACTS/blfs-xfce-visual1-screenshot-stats.txt"
grep -q '^VISUAL_WALLPAPER_NONBLACK=' "$ARTIFACTS/blfs-xfce-visual1-apply.log"
grep -q '^VISUAL_MONITORS=' "$ARTIFACTS/blfs-xfce-visual1-apply.log"
clients="$(awk -F= '/^X11_CLIENT_COUNT=/{v=$2} END{print v}' "$ARTIFACTS/blfs-xfce-visual1-x11.txt")"
[[ "$clients" =~ ^[0-9]+$ && "$clients" -ge 4 ]]
python3 - "$ARTIFACTS/blfs-xfce-visual1-screen-desktop.png" "$ARTIFACTS/blfs-xfce-visual1-screen-terminal.png" "$ARTIFACTS/blfs-xfce-visual1-wallpaper-1280x800.png" <<'PY'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    data = Path(name).read_bytes()
    assert len(data) > 1000 and data[:8] == b'\x89PNG\r\n\x1a\n', name
PY
cat "$REPORT"
trap - EXIT
