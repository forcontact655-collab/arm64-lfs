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
REPORT=/root/blfs-plasma13-report.txt
PROGRESS=/root/blfs-plasma13-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake \
  /usr/lib/libpolkit-qt6-core-1.so \
  /opt/kf6/lib/cmake/KF6Crash/KF6CrashConfig.cmake \
  /opt/kf6/lib/cmake/KF6Notifications/KF6NotificationsConfig.cmake \
  /opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.volume.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/share/wallpapers/DarkestHour \
  /opt/kf6/share/wallpapers/Nuvole \
  /opt/kf6/libexec/polkit-kde-authentication-agent-1; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
packages=(plasma-workspace-wallpapers polkit-kde-agent-1)
for name in "${packages[@]}"; do
  archive="$name-6.4.4.tar.xz"
  package_dir="$name-6.4.4"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  [[ "${first%%/*}" == "$package_dir" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA13=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_PLASMA13_BUILT=%s-6.4.4\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA13_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/share/wallpapers/DarkestHour/metadata.json \
  /opt/kf6/share/wallpapers/DarkestHour/contents/screenshot.jpg \
  /opt/kf6/share/wallpapers/Nuvole/metadata.json; do
  [[ -f "$path" ]]
done
python3 -m json.tool /opt/kf6/share/wallpapers/DarkestHour/metadata.json >/dev/null
python3 -m json.tool /opt/kf6/share/wallpapers/Nuvole/metadata.json >/dev/null
POLKIT_AGENT=/opt/kf6/libexec/polkit-kde-authentication-agent-1
[[ -x "$POLKIT_AGENT" ]]
[[ -f /opt/kf6/etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop ]]
[[ -f /opt/kf6/share/applications/org.kde.polkit-kde-authentication-agent-1.desktop ]]
readelf -h "$POLKIT_AGENT" | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l "$POLKIT_AGENT" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
printf 'PLASMA13_POSTCHECK=wallpaper-data-and-polkit-agent-elf\n'
{
  printf 'BLFS_PLASMA13_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-authentication-agent\nNEW_EXECUTABLES=polkit-kde-authentication-agent-1-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=plasma-workspace-wallpapers+polkit-kde-agent-1\nWALLPAPERS=6.4.4\nPOLKIT_KDE_AGENT=6.4.4\n'
  printf 'WALLPAPER_DATA=installed-upstream-not-applied\nWALLPAPER_JSON=validated-not-rendered\nLILIT_WALLPAPER=not-changed\nDARK_ANIME_STYLE=not-changed\nPASTEL_THEME=not-applied\n'
  printf 'POLKIT_AGENT=built-elf-not-executed\nPOLKIT_AUTH=not-run\nPOLKIT_AGENT_REGISTRATION=not-run\nPOLKIT_DAEMON=preserved-not-started\n'
  printf 'TEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA12=preserved-pipeline-196\nPLASMA_PA=preserved-built-no-audio\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'PLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
