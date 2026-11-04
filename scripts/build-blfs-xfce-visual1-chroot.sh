#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export PATH=/usr/local/bin:/usr/bin:/usr/sbin
umask 022
SOURCES=/sources
REPORT=/root/blfs-xfce-visual1-report.txt
PROGRESS=/root/blfs-xfce-visual1-progress.txt
VALUES=/root/blfs-xfce-visual1-values.txt
X11_LOG=/root/blfs-xfce-visual1-x11.txt
SESSION_LOG=/root/blfs-xfce-visual1-session.log
APPLY_LOG=/root/blfs-xfce-visual1-apply.log
XVFB_LOG=/root/blfs-xfce-visual1-xvfb.log
TERMINAL_LOG=/root/blfs-xfce-visual1-terminal.log
DESKTOP_SCREEN=/root/blfs-xfce-visual1-screen-desktop.png
TERMINAL_SCREEN=/root/blfs-xfce-visual1-screen-terminal.png
THEME_HASHES=/root/blfs-xfce-visual1-theme-sha256sums.txt
PROFILE_HASHES=/root/blfs-xfce-visual1-profile-sha256sums.txt
SCREENSHOT_STATS=/root/blfs-xfce-visual1-screenshot-stats.txt
PROBE=/tmp/blfs-xfce-visual1-probe
TEST_HOME=/tmp/blfs-xfce-visual1-home
TEST_RUNTIME=/tmp/blfs-xfce-visual1-runtime
DONE=/tmp/blfs-xfce-visual1-done
TERMINAL_MARKER=/tmp/blfs-xfce-visual1-terminal-ok
SRC=/usr/share/backgrounds/vim/lilith-memory-paradise.png
OUT_DIR=/usr/share/backgrounds/vim/generated
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
for p in /usr/bin/gcc /usr/bin/python3 /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/Xvfb /usr/bin/dbus-run-session /usr/bin/setsid /usr/bin/startxfce4 /usr/bin/xfconf-query /usr/bin/xfce4-terminal /usr/bin/xfdesktop /usr/bin/ps; do
  [[ -x "$p" ]]
done
[[ -d /usr/share/themes/Daloa/xfwm4 ]]
[[ -f /root/blfs-xfce-launch1-x11-smoke.c ]]
[[ ! -e /usr/share/themes/VimAnimeDark ]]
[[ ! -e /usr/local/bin/vim-xfce-visual-apply ]]
[[ ! -e /root/.config/xfce4 ]]
[[ -f "$SOURCES/146271413_p0.png" ]]
printf '2995b1f1e50865287e688764d612a89ae9b65713d6f6cf68b73e8954f9a5a24a  %s\n' "$SOURCES/146271413_p0.png" | sha256sum -c -
: >"$PROGRESS"
install -D -m0644 "$SOURCES/146271413_p0.png" "$SRC"

python3 - <<'PY'
from pathlib import Path
src = Path('/usr/share/themes/Daloa/xfwm4')
root = Path('/usr/share/themes/VimAnimeDark')
dst = root / 'xfwm4'
dst.mkdir(parents=True)
colors = {
    '#A0A0FF': '#0B1020', '#D0D0FF': '#40345F', '#C0C0FF': '#141421',
    '#E0E0FF': '#7DD3FC', '#C0C0C0': '#1B1B2A', '#B0B0B0': '#202238',
    '#B0B0FF': '#F472B6', '#666666': '#141421', '#7f7f7f': '#2A2138',
}
count = 0
for source in sorted(src.glob('*.xpm')):
    text = source.read_text()
    for old, new in colors.items():
        text = text.replace(old, new)
    (dst / source.name).write_text(text)
    count += 1
assert count >= 40, count
rc = (src / 'themerc').read_text()
rc = rc.replace('active_text_color=#ffffff', 'active_text_color=#E6E1F0')
rc += '\ninactive_text_color=#A7A2BA\ntitle_shadow_active=false\ntitle_shadow_inactive=false\nfull_width_title=true\n'
(dst / 'themerc').write_text(rc)
(root / 'index.theme').write_text('[Desktop Entry]\nType=XTheme\nName=VimAnimeDark\nComment=Dark anime-inspired XFCE theme\n')
(root / 'gtk-3.0').mkdir()
(root / 'gtk-3.0' / 'gtk.css').write_text('''/* VimAnimeDark: dark navy surfaces with cyan and pink accents. */
window, dialog, messagedialog {
  background-color: #141421;
  color: #E6E1F0;
}
headerbar, .titlebar {
  background-color: #10111C;
  color: #E6E1F0;
  border-color: #40345F;
}
button {
  background-image: none;
  background-color: #202238;
  color: #E6E1F0;
  border-color: #40345F;
}
button:hover, button:checked {
  background-color: #40345F;
  border-color: #7DD3FC;
}
entry, textview, treeview, scrolledwindow {
  background-color: #1B1B2A;
  color: #E6E1F0;
}
menu, popover, .context-menu {
  background-color: #10111C;
  color: #E6E1F0;
  border-color: #40345F;
}
.xfce4-panel {
  background-color: rgba(16, 17, 28, 0.96);
  border-color: #40345F;
  color: #E6E1F0;
}
.xfce4-panel button {
  background-color: transparent;
  color: #E6E1F0;
  border-color: transparent;
  border-radius: 4px;
}
.xfce4-panel button:hover, .xfce4-panel button:checked {
  background-color: #40345F;
  border-color: #7DD3FC;
}
''')
print('VIM_ANIME_DARK_XPM_FILES', count)
PY

cat >/usr/local/bin/vim-xfce-visual-apply <<'PYAPPLY'
#!/usr/bin/python3
import ctypes
import hashlib
import os
from pathlib import Path
import subprocess

SRC = Path('/usr/share/backgrounds/vim/lilith-memory-paradise.png')
OUT = Path(os.environ.get('VIM_XFCE_VISUAL_OUT', '/usr/share/backgrounds/vim/generated'))
EXPECTED = '2995b1f1e50865287e688764d612a89ae9b65713d6f6cf68b73e8954f9a5a24a'
assert SRC.is_file()
assert hashlib.sha256(SRC.read_bytes()).hexdigest() == EXPECTED
OUT.mkdir(parents=True, exist_ok=True)

def run(args, capture=False):
    return subprocess.run(args, text=True, capture_output=capture, check=True)

def dimensions():
    x11 = ctypes.CDLL('libX11.so.6')
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XDisplayWidth.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XDisplayWidth.restype = ctypes.c_int
    x11.XDisplayHeight.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XDisplayHeight.restype = ctypes.c_int
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('no X11 display')
    try:
        return x11.XDisplayWidth(display, 0), x11.XDisplayHeight(display, 0)
    finally:
        x11.XCloseDisplay(display)

def setv(channel, prop, typ, value):
    value = str(value)
    probe = subprocess.run(['xfconf-query', '-c', channel, '-p', prop],
                           text=True, capture_output=True)
    if probe.returncode == 0:
        run(['xfconf-query', '-c', channel, '-p', prop, '-s', value])
    else:
        run(['xfconf-query', '-c', channel, '-p', prop, '--create', '-t', typ, '-s', value])

w, h = dimensions()
wall = OUT / f'lilith-memory-paradise-{w}x{h}.png'
if not wall.is_file():
    sw, sh = 4000, 2857
    crop_w = min(sw, round(sh * w / h))
    crop_x = (sw - crop_w) // 2
    scale = min(w / sw, h / sh)
    fg_w, fg_h = round(sw * scale), round(sh * scale)
    fg_x, fg_y = (w - fg_w) // 2, (h - fg_h) // 2
    filters = (
        f'[0:v]split=2[bg][fg];'
        f'[bg]crop={crop_w}:{sh}:{crop_x}:0,scale={w}:{h}:flags=lanczos,'
        f'gblur=sigma=34,lutrgb=r=val*0.48:g=val*0.48:b=val*0.48[b];'
        f'[fg]scale={fg_w}:{fg_h}:flags=lanczos[f];'
        f'[b][f]overlay={fg_x}:{fg_y},format=rgb24[out]'
    )
    tmp = wall.with_suffix('.tmp.png')
    raw = subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(SRC),
                          '-filter_complex', filters, '-map', '[out]', '-frames:v', '1',
                          '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'],
                         capture_output=True, check=True).stdout
    assert len(raw) == w * h * 3, len(raw)
    # Apply the same final darkening pass as the reviewed Lilith composition.
    pixels = bytearray(round(value * 0.65) for value in raw)
    assert max(pixels) > 40
    ppm = wall.with_suffix('.tmp.ppm')
    ppm.write_bytes(f'P6\n{w} {h}\n255\n'.encode() + pixels)
    run(['ffmpeg', '-y', '-v', 'error', '-i', str(ppm), '-frames:v', '1', str(tmp)])
    ppm.unlink()
    probe = run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                 'stream=width,height', '-of', 'csv=p=0', str(tmp)], True).stdout.strip()
    assert probe == f'{w},{h}', probe
    tmp.replace(wall)
raw_check = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(wall), '-frames:v', '1',
                            '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'],
                           capture_output=True, check=True).stdout
assert len(raw_check) == w * h * 3
wall_nonblack = sum(1 for i in range(0, len(raw_check), 3)
                    if max(raw_check[i:i + 3]) > 32) / (w * h)
assert wall_nonblack > 0.25, wall_nonblack
print(f'VISUAL_WALLPAPER_NONBLACK={wall_nonblack:.6f}')

setv('xsettings', '/Net/ThemeName', 'string', 'VimAnimeDark')
setv('xsettings', '/Gtk/ApplicationPreferDarkTheme', 'bool', 'true')
setv('xfwm4', '/general/theme', 'string', 'VimAnimeDark')
setv('xfwm4', '/general/use_compositing', 'bool', 'true')
for prop, typ, value in [
    ('/color-background', 'string', '#141421'),
    ('/color-foreground', 'string', '#E6E1F0'),
    ('/color-cursor', 'string', '#F472B6'),
    ('/color-selection', 'string', '#40345F'),
    ('/color-palette', 'string', '#1B1B2A;#F472B6;#A7F3D0;#FDE68A;#97A6FF;#C4B5FD;#A5F3FC;#E6E1F0;#6B687A;#F9A8D4;#6EE7B7;#FCD34D;#A5B4FC;#D8B4FE;#67E8F9;#FFFFFF'),
    ('/background-mode', 'string', 'TERMINAL_BACKGROUND_TRANSPARENT'),
    ('/background-darkness', 'double', '0.85'),
]:
    setv('xfce4-terminal', prop, typ, value)

trc = Path.home() / '.config' / 'xfce4' / 'terminal' / 'terminalrc'
trc.parent.mkdir(parents=True, exist_ok=True)
trc.write_text('''[Configuration]
ColorForeground=#E6E1F0
ColorBackground=#141421
ColorCursor=#F472B6
ColorSelection=#40345F
ColorPalette=#1B1B2A;#F472B6;#A7F3D0;#FDE68A;#97A6FF;#C4B5FD;#A5F3FC;#E6E1F0;#6B687A;#F9A8D4;#6EE7B7;#FCD34D;#A5B4FC;#D8B4FE;#67E8F9;#FFFFFF
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.85
''')

listing = run(['xfconf-query', '-c', 'xfce4-desktop', '-l'], True).stdout.splitlines()
props = [p for p in listing if p.endswith('/last-image')]
if not props:
    props = ['/backdrop/screen0/monitor0/workspace0/last-image']
for prop in props:
    setv('xfce4-desktop', prop, 'string', str(wall))
    base = prop[:-len('last-image')]
    setv('xfce4-desktop', base + 'image-style', 'int', '4')
    setv('xfce4-desktop', base + 'color-style', 'int', '0')
    rgba = base + 'rgba1'
    subprocess.run(['xfconf-query', '-c', 'xfce4-desktop', '-p', rgba, '-r'],
                   text=True, capture_output=True)
    run(['xfconf-query', '-c', 'xfce4-desktop', '-p', rgba, '--create',
         '-t', 'double', '-s', '0.025', '-t', 'double', '-s', '0.030',
         '-t', 'double', '-s', '0.050', '-t', 'double', '-s', '1.0'])

ids_result = subprocess.run(['xfconf-query', '-c', 'xfce4-panel', '-p', '/panels/panel-ids'],
                            text=True, capture_output=True)
if ids_result.returncode == 0:
    for panel_id in ids_result.stdout.split():
        if panel_id.isdigit():
            setv('xfce4-panel', f'/panels/panel-{panel_id}/length', 'int', '100')

run(['xfce4-panel', '-r'])
xfwm_log = open('/tmp/vim-xfce-visual-xfwm4.log', 'w')
subprocess.Popen(['xfwm4', '--replace'], stdout=xfwm_log, stderr=xfwm_log,
                 start_new_session=True)
xfwm_log.close()
run(['xfdesktop', '--reload'])
print(f'VISUAL_WALLPAPER={wall}\nVISUAL_DIMENSIONS={w}x{h}\nVISUAL_WALLPAPER_SHA256={hashlib.sha256(wall.read_bytes()).hexdigest()}')
print('VIM_XFCE_VISUAL_APPLY_OK')
PYAPPLY
chmod 755 /usr/local/bin/vim-xfce-visual-apply
python3 -m py_compile /usr/local/bin/vim-xfce-visual-apply

# Reuse the already reviewed X11 probe for native WM and screenshot checks.
gcc /root/blfs-xfce-launch1-x11-smoke.c -o "$PROBE" $(pkg-config --cflags --libs x11 libpng)
readelf -h "$PROBE" | grep -q 'Machine:.*AArch64'
readelf -l "$PROBE" | grep -q '/lib/ld-linux-aarch64.so.1'

cat >/root/blfs-xfce-visual1-session.sh <<'SESSION'
#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/usr/sbin
export NO_AT_BRIDGE=1
export GDK_BACKEND=x11
export LIBGL_ALWAYS_SOFTWARE=1
XFCE_PID=''
TERM_PID=''
cleanup() {
  local status=$?
  set +e
  [[ -z "$TERM_PID" ]] || kill "$TERM_PID" 2>/dev/null
  [[ -z "$XFCE_PID" ]] || kill "$XFCE_PID" 2>/dev/null
  [[ -z "$TERM_PID" ]] || wait "$TERM_PID" 2>/dev/null
  [[ -z "$XFCE_PID" ]] || wait "$XFCE_PID" 2>/dev/null
  set -e
  return "$status"
}
trap cleanup EXIT
startxfce4 >"$VISUAL_SESSION_LOG" 2>&1 &
XFCE_PID=$!
ready=0
for _ in $(seq 1 45); do
  if xfconf-query -c xsettings -p /Net/ThemeName >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[[ "$ready" -eq 1 ]]
for _ in $(seq 1 45); do
  props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null || true)
  if grep -qE '/(image-path|last-image)$' <<<"$props" && grep -q '/image-style$' <<<"$props"; then break; fi
  sleep 1
done
/usr/local/bin/vim-xfce-visual-apply >"$VISUAL_APPLY_LOG" 2>&1
cat "$VISUAL_APPLY_LOG"
grep -q VIM_XFCE_VISUAL_APPLY_OK "$VISUAL_APPLY_LOG"
sleep 5
DISPLAY="$DISPLAY" "$VISUAL_PROBE" session "$VISUAL_DESKTOP_SCREEN" >>"$VISUAL_X11_LOG"
[[ -s "$VISUAL_DESKTOP_SCREEN" ]]
xfce4-terminal --disable-server --title=VimAnimeDark \
  --command="/bin/bash -lc 'printf VIM_XFCE_VISUAL_TERMINAL_EXEC_OK >$VISUAL_TERMINAL_MARKER; exec sleep 60'" \
  >"$VISUAL_TERMINAL_LOG" 2>&1 &
TERM_PID=$!
for _ in $(seq 1 45); do
  [[ -s "$VISUAL_TERMINAL_MARKER" ]] && break
  sleep 1
done
[[ -s "$VISUAL_TERMINAL_MARKER" ]]
sleep 4
DISPLAY="$DISPLAY" "$VISUAL_PROBE" session "$VISUAL_TERMINAL_SCREEN" >>"$VISUAL_X11_LOG"
[[ -s "$VISUAL_TERMINAL_SCREEN" ]]
{
  for spec in 'xsettings /Net/ThemeName' 'xsettings /Gtk/ApplicationPreferDarkTheme' 'xfwm4 /general/theme' 'xfwm4 /general/use_compositing' 'xfce4-panel /panels/panel-1/length' 'xfce4-terminal /color-background' 'xfce4-terminal /color-foreground' 'xfce4-terminal /background-mode' 'xfce4-terminal /background-darkness'; do
    set -- $spec
    printf '%s %s=' "$1" "$2"
    xfconf-query -c "$1" -p "$2" 2>&1 || true
  done
  printf '%s\n' '--- WALLPAPER ---'
  xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/(last-image|image-style|color-style|rgba1)$' | while read -r p; do
    printf '%s=' "$p"; xfconf-query -c xfce4-desktop -p "$p" 2>&1 || true
  done
} >"$VISUAL_VALUES"
grep -q 'xsettings /Net/ThemeName=VimAnimeDark' "$VISUAL_VALUES"
grep -q 'xfwm4 /general/theme=VimAnimeDark' "$VISUAL_VALUES"
grep -q 'xfce4-terminal /color-background=#141421' "$VISUAL_VALUES"
grep -q 'xfce4-terminal /color-foreground=#E6E1F0' "$VISUAL_VALUES"
grep -q 'lilith-memory-paradise-1280x800.png' "$VISUAL_VALUES"
printf '%s\n' VIM_XFCE_VISUAL_SESSION_OK
printf 'ok\n' >"$VISUAL_DONE"
SESSION
chmod 700 /root/blfs-xfce-visual1-session.sh

rm -rf "$TEST_HOME" "$TEST_RUNTIME" "$DONE" "$TERMINAL_MARKER"
mkdir -p "$TEST_HOME/.config" "$TEST_HOME/.cache" "$TEST_HOME/.local/share"
mkdir -m 0700 "$TEST_RUNTIME"
XVFB_PID=''
SESSION_PID=''
dump_logs() {
  printf '%s\n' '--- XVFB LOG ---'; [[ ! -f "$XVFB_LOG" ]] || cat "$XVFB_LOG"
  printf '%s\n' '--- SESSION LOG ---'; [[ ! -f "$SESSION_LOG" ]] || cat "$SESSION_LOG"
  printf '%s\n' '--- APPLY LOG ---'; [[ ! -f "$APPLY_LOG" ]] || cat "$APPLY_LOG"
  printf '%s\n' '--- TERMINAL LOG ---'; [[ ! -f "$TERMINAL_LOG" ]] || cat "$TERMINAL_LOG"
  printf '%s\n' '--- X11 LOG ---'; [[ ! -f "$X11_LOG" ]] || cat "$X11_LOG"
}
stop_session() {
  [[ -z "$SESSION_PID" ]] && return 0
  kill -TERM -- "-$SESSION_PID" 2>/dev/null || true
  for _ in {1..50}; do
    kill -0 "$SESSION_PID" 2>/dev/null || break
    sleep 0.1
  done
  kill -KILL -- "-$SESSION_PID" 2>/dev/null || true
  wait "$SESSION_PID" 2>/dev/null || true
  SESSION_PID=''
}
cleanup() {
  local status=$?
  set +e
  if [[ "$status" -ne 0 ]]; then dump_logs; fi
  stop_session
  if [[ -n "$XVFB_PID" ]]; then kill "$XVFB_PID" 2>/dev/null; wait "$XVFB_PID" 2>/dev/null; fi
  rm -rf "$TEST_HOME" "$TEST_RUNTIME"
  rm -f "$DONE" "$TERMINAL_MARKER"
  set -e
}
trap cleanup EXIT
rm -f /tmp/blfs-xfce-visual1-display
LIBGL_ALWAYS_SOFTWARE=1 Xvfb -displayfd 3 -screen 0 1280x800x24 -nolisten tcp -ac 3>/tmp/blfs-xfce-visual1-display >"$XVFB_LOG" 2>&1 &
XVFB_PID=$!
for _ in {1..100}; do
  [[ -s /tmp/blfs-xfce-visual1-display ]] && break
  kill -0 "$XVFB_PID" 2>/dev/null || { cat "$XVFB_LOG"; exit 1; }
  sleep 0.1
done
[[ -s /tmp/blfs-xfce-visual1-display ]]
DISPLAY_NUMBER="$(cat /tmp/blfs-xfce-visual1-display)"
[[ "$DISPLAY_NUMBER" =~ ^[0-9]+$ ]]
DISPLAY=":$DISPLAY_NUMBER"
[[ -S "/tmp/.X11-unix/X$DISPLAY_NUMBER" ]]
DISPLAY="$DISPLAY" "$PROBE" server >"$X11_LOG"
grep -q '^X11_CONNECTION=ok$' "$X11_LOG"
grep -q '^SCREEN=1280x800$' "$X11_LOG"

setsid /usr/bin/env -i \
  PATH=/usr/local/bin:/usr/bin:/usr/sbin \
  HOME="$TEST_HOME" TERM=xterm LC_ALL=C.UTF-8 DISPLAY="$DISPLAY" \
  GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 NO_AT_BRIDGE=1 \
  XDG_CURRENT_DESKTOP=XFCE XDG_RUNTIME_DIR="$TEST_RUNTIME" \
  XDG_CONFIG_HOME="$TEST_HOME/.config" XDG_CACHE_HOME="$TEST_HOME/.cache" \
  XDG_DATA_HOME="$TEST_HOME/.local/share" XDG_CONFIG_DIRS=/etc/xdg \
  XDG_DATA_DIRS=/usr/local/share:/usr/share \
  VIM_XFCE_VISUAL_OUT="$OUT_DIR" \
  VISUAL_PROBE="$PROBE" VISUAL_DESKTOP_SCREEN="$DESKTOP_SCREEN" \
  VISUAL_TERMINAL_SCREEN="$TERMINAL_SCREEN" VISUAL_X11_LOG="$X11_LOG" \
  VISUAL_SESSION_LOG="$SESSION_LOG" VISUAL_APPLY_LOG="$APPLY_LOG" \
  VISUAL_TERMINAL_LOG="$TERMINAL_LOG" VISUAL_VALUES="$VALUES" \
  VISUAL_DONE="$DONE" VISUAL_TERMINAL_MARKER="$TERMINAL_MARKER" \
  dbus-run-session -- /root/blfs-xfce-visual1-session.sh >"$SESSION_LOG.launcher" 2>&1 &
SESSION_PID=$!
for _ in {1..150}; do
  [[ -s "$DONE" ]] && break
  if ! kill -0 "$SESSION_PID" 2>/dev/null; then break; fi
  sleep 1
done
[[ -s "$DONE" ]]
set +e
wait "$SESSION_PID"
SESSION_STATUS=$?
set -e
[[ "$SESSION_STATUS" -eq 0 ]]
stop_session
grep -q VIM_XFCE_VISUAL_SESSION_OK "$SESSION_LOG.launcher"
[[ -s "$DESKTOP_SCREEN" && -s "$TERMINAL_SCREEN" ]]
grep -q 'X11_WM_CHECK=present' "$X11_LOG"
grep -q 'SCREENSHOT_NON_BACKGROUND_PIXELS=[1-9]' "$X11_LOG"
python3 - "$DESKTOP_SCREEN" "$TERMINAL_SCREEN" >"$SCREENSHOT_STATS" <<'PYSTATS'
import subprocess
import sys

W, H = 1280, 800
def measure(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-frames:v', '1',
                          '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'],
                         capture_output=True, check=True).stdout
    assert len(raw) == W * H * 3, (path, len(raw))
    total = W * H
    nonblack = bright = colorful = 0
    for i in range(0, len(raw), 3):
        r, g, b = raw[i:i + 3]
        high = max(r, g, b)
        if high > 32:
            nonblack += 1
        if high > 100:
            bright += 1
        if high > 50 and high - min(r, g, b) > 20:
            colorful += 1
    return nonblack / total, bright / total, colorful / total

desktop = measure(sys.argv[1])
terminal = measure(sys.argv[2])
for name, values in [('DESKTOP', desktop), ('TERMINAL', terminal)]:
    print('%s_NONBLACK=%.6f' % (name, values[0]))
    print('%s_BRIGHT=%.6f' % (name, values[1]))
    print('%s_COLORFUL=%.6f' % (name, values[2]))
# A few icons and panels must not pass as a wallpaper: require substantial image coverage.
assert desktop[0] > 0.20 and desktop[1] > 0.03 and desktop[2] > 0.03, desktop
assert terminal[0] > 0.05, terminal
print('SCREENSHOT_WALLPAPER_ACCEPTANCE=ok')
PYSTATS
cat "$SCREENSHOT_STATS"
grep -q '^SCREENSHOT_WALLPAPER_ACCEPTANCE=ok$' "$SCREENSHOT_STATS"

mkdir -p /root/.config/xfce4/xfconf
cp -a "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml" /root/.config/xfce4/xfconf/
if [[ -f "$TEST_HOME/.config/xfce4/terminal/terminalrc" ]]; then
  mkdir -p /root/.config/xfce4/terminal
  cp -a "$TEST_HOME/.config/xfce4/terminal/terminalrc" /root/.config/xfce4/terminal/terminalrc
fi
find /usr/share/themes/VimAnimeDark -type f -print0 | sort -z | xargs -0 sha256sum >"$THEME_HASHES"
find /root/.config/xfce4 -type f -print0 | sort -z | xargs -0 sha256sum >"$PROFILE_HASHES"
WALL_SHA="$(sha256sum "$OUT_DIR/lilith-memory-paradise-1280x800.png" | awk '{print $1}')"
CLIENTS="$(awk -F= '/^X11_CLIENT_COUNT=/{value=$2} END{print value}' "$X11_LOG")"
{
  printf 'BLFS_XFCE_VISUAL1_RESULT=ok\nPACKAGE_COUNT=0\nARCH=aarch64\nBASE_PIPELINE=156\nXFCE_CORE=18-of-18\nXFCE_APPS=pipeline-87\n'
  printf 'GTK_THEME=VimAnimeDark\nXFWM_THEME=VimAnimeDark\nXFWM_ASSETS=xpm-only\n'
} >"$REPORT"
{
  printf 'PANEL_STYLE=dark-navy-cyan-pink\nTERMINAL_STYLE=dark-navy-transparent\nTERMINAL_EXEC=VIM_XFCE_VISUAL_TERMINAL_EXEC_OK\n'
  printf 'DESKTOP_LAUNCH=headless-xvfb-startxfce4-terminal-ok\nX11_CLIENT_COUNT=%s\n' "$CLIENTS"
  printf 'SCREENSHOT_DESKTOP=png-wallpaper-visible\nSCREENSHOT_TERMINAL=png-terminal-visible-required\nSCREENSHOT_PIXEL_ACCEPTANCE=desktop-nonblack-bright-colorful\n'
  printf 'WALLPAPER=Lilith-Memory-Paradise\nWALLPAPER_RENDER=rawvideo-final-darkening\nDESKTOP_COLOR_STYLE=solid-dark\nWALLPAPER_SOURCE_SHA256=2995b1f1e50865287e688764d612a89ae9b65713d6f6cf68b73e8954f9a5a24a\nWALLPAPER_DERIVATIVE=1280x800\nWALLPAPER_SHA256=%s\n' "$WALL_SHA"
  printf 'PERSISTENT_PROFILE=/root/.config/xfce4\nADAPTIVE_WALLPAPER=generated-on-apply-no-watcher\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nEXISTING_ARCH=not-accessed-not-modified\nPLASMA=not-built\nBOOTABLE=no\n'
} >>"$REPORT"
printf 'BLFS_XFCE_VISUAL1_BUILT=VimAnimeDark+Lilith+profile\n' >>"$PROGRESS"
cat "$REPORT"
rm -f "$PROBE" /root/blfs-xfce-visual1-session.sh "$SESSION_LOG.launcher"
trap - EXIT
cleanup
trap - EXIT
