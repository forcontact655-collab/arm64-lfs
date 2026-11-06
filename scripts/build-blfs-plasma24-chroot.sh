#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma24-report.txt
PROGRESS=/root/blfs-plasma24-progress.txt
OXYGEN_CONFIG=/root/blfs-plasma24-oxygen-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/gzip ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/share/sounds/oxygen/index.theme \
  /opt/kf6/share/sounds/ocean/index.theme; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/liboxygenstyle6.so.6.4.4 \
  /opt/kf6/lib/liboxygenstyleconfig6.so.6.4.4 \
  /opt/kf6/bin/oxygen-demo6 \
  /opt/kf6/bin/oxygen-settings6 \
  /opt/kf6/share/kstyle/themes/oxygen.themerc \
  /opt/kf6/share/plasma/look-and-feel/org.kde.oxygen \
  /opt/kf6/share/plasma/desktoptheme/oxygen \
  /opt/kf6/share/icons/Oxygen_Black; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
[[ -z "$(find /opt/kf6/lib/plugins -type f \( -path '*/styles/oxygen6.so' -o -path '*/kstyle_config/kstyle_oxygen_config.so' -o -path '*/org.kde.kdecoration3/org.kde.oxygen.so' -o -name 'kcm_oxygendecoration.so' \) -print -quit)" ]]
: >"$PROGRESS"
printf 'BUILD_BLFS_PLASMA24=oxygen\n'
archive=oxygen-6.4.4.tar.xz
package=oxygen-6.4.4
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
top="${first%%/*}"; top="${top#./}"
[[ "$top" == "$package" ]]
rm -rf "$SOURCES/$package"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
cd "$SOURCES/$package"
mkdir build
cd build
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -D BUILD_QT5=OFF \
  -D BUILD_QT6=ON \
  -W no-dev ..
grep -q 'oxygen-demo6' build.ninja
grep -q 'oxygen-settings6' build.ninja
{
  grep -E '^(BUILD_QT5|BUILD_QT6|KDecoration3_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt
  printf 'OXYGEN_RUNTIME=not-started\nTHEME_APPLICATION=not-run\n'
} >"$OXYGEN_CONFIG"
grep -qx 'BUILD_QT5:BOOL=OFF' "$OXYGEN_CONFIG"
grep -qx 'BUILD_QT6:BOOL=ON' "$OXYGEN_CONFIG"
grep -qx 'OXYGEN_RUNTIME=not-started' "$OXYGEN_CONFIG"
grep -qx 'THEME_APPLICATION=not-run' "$OXYGEN_CONFIG"
ninja
ninja install
cd /sources
rm -rf "$package"
printf 'BLFS_PLASMA24_BUILT=oxygen-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA24_BUILT=' "$PROGRESS")" -eq 1 ]]
mapfile -t STYLE < <(find /opt/kf6/lib/plugins -type f -path '*/styles/oxygen6.so' -print)
mapfile -t STYLE_CONFIG < <(find /opt/kf6/lib/plugins -type f -path '*/kstyle_config/kstyle_oxygen_config.so' -print)
mapfile -t DECORATION < <(find /opt/kf6/lib/plugins -type f -path '*/org.kde.kdecoration3/org.kde.oxygen.so' -print)
mapfile -t DECORATION_KCM < <(find /opt/kf6/lib/plugins -type f -name 'kcm_oxygendecoration.so' -print)
[[ "${#STYLE[@]}" -eq 1 && "${#STYLE_CONFIG[@]}" -eq 1 && "${#DECORATION[@]}" -eq 1 && "${#DECORATION_KCM[@]}" -eq 1 ]]
STYLE_PLUGIN="${STYLE[0]}"
STYLE_CONFIG_PLUGIN="${STYLE_CONFIG[0]}"
DECORATION_PLUGIN="${DECORATION[0]}"
KCM_PLUGIN="${DECORATION_KCM[0]}"
STYLE_LIBRARY=/opt/kf6/lib/liboxygenstyle6.so.6.4.4
CONFIG_LIBRARY=/opt/kf6/lib/liboxygenstyleconfig6.so.6.4.4
DEMO=/opt/kf6/bin/oxygen-demo6
SETTINGS=/opt/kf6/bin/oxygen-settings6
for path in "$STYLE_LIBRARY" "$CONFIG_LIBRARY" "$DEMO" "$SETTINGS" \
  /opt/kf6/share/kstyle/themes/oxygen.themerc \
  /opt/kf6/share/plasma/look-and-feel/org.kde.oxygen/metadata.json \
  /opt/kf6/share/plasma/desktoptheme/oxygen/metadata.json \
  /opt/kf6/share/icons/Oxygen_Black/index.theme; do
  [[ -f "$path" ]]
done
for elf in "$STYLE_PLUGIN" "$STYLE_CONFIG_PLUGIN" "$DECORATION_PLUGIN" "$KCM_PLUGIN" "$STYLE_LIBRARY" "$CONFIG_LIBRARY" "$DEMO" "$SETTINGS"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$SETTINGS" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
DEMO_INTERPRETER="$(readelf -l "$DEMO" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$DEMO_INTERPRETER" == "$INTERPRETER" ]]
printf 'PLASMA24_POSTCHECK=oxygen-eight-elf-files-theme-data-not-executed\n'
{
  printf 'BLFS_PLASMA24_RESULT=ok\nPACKAGE_COUNT=1\nSOURCE_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-oxygen-demo-settings-or-plugins\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=oxygen\nOXYGEN=6.4.4\nELF_FILE_COUNT=8\nQT5_BUILD=disabled\n'
  printf 'OXYGEN_STYLE=installed-not-applied\nOXYGEN_STYLE_CONFIG=installed-not-opened\nOXYGEN_DECORATION=installed-not-loaded\nOXYGEN_KCM=installed-not-opened\n'
  printf 'OXYGEN_DEMO=installed-not-executed\nOXYGEN_SETTINGS=installed-not-executed\nOXYGEN_LOOKANDFEEL=installed-not-applied\n'
  printf 'OXYGEN_CURSOR_THEMES=installed-not-applied\nOXYGEN_DESKTOPTHEME=installed-not-applied\nTHEME_APPLICATION=not-run\n'
  printf 'WACOMTABLET=deferred-requires-xorg-wacom\nTEST_SUITES=not-run\nNETWORK=not-used-by-built-programs\n'
  printf 'PLASMA23=preserved-pipeline-213\nSOUND_THEMES=preserved-pipeline-213-not-played\nPLASMA22=preserved-pipeline-211\nKDEPLASMA_ADDONS=preserved-pipeline-211-not-loaded\nPLASMA_WELCOME=preserved-pipeline-211-not-opened\n'
  printf 'PLASMA21=preserved-pipeline-210\nBLUEDEVIL=preserved-pipeline-210-not-started\nPLASMA20=preserved-pipeline-209\n'
  printf 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nSDDM=preserved-not-started\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
