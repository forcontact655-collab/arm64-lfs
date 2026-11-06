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
REPORT=/root/blfs-plasma22-report.txt
PROGRESS=/root/blfs-plasma22-progress.txt
ADDONS_CONFIG=/root/blfs-plasma22-addons-config.txt
WELCOME_CONFIG=/root/blfs-plasma22-welcome-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake \
  /opt/kf6/lib/cmake/KF6Runner/KF6RunnerConfig.cmake \
  /opt/kf6/lib/cmake/KF6Holidays/KF6HolidaysConfig.cmake \
  /opt/kf6/lib/cmake/KF6UnitConversion/KF6UnitConversionConfig.cmake \
  /opt/kf6/lib/cmake/KF6KirigamiAddons/KF6KirigamiAddonsConfig.cmake \
  /opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake \
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_bluetooth.so; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/qml/org/kde/plasma/private/colorpicker \
  /opt/kf6/lib/qml/org/kde/plasma/private/profiles \
  /opt/kf6/lib/plugins/kf6/krunner/krunner_dictionary.so \
  /opt/kf6/lib/plugins/kf6/krunner/unitconverter.so \
  /opt/kf6/lib/plugins/kf6/kded/kameleon.so \
  /opt/kf6/libexec/kf6/kauth/kameleonhelper \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.colorpicker \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.binaryclock \
  /opt/kf6/bin/plasma-welcome \
  /opt/kf6/share/applications/org.kde.plasma-welcome.desktop; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
[[ -z "$(find /opt/kf6/lib/plugins/kf6/kded -maxdepth 1 -name '*plasma-welcome*.so' -print -quit)" ]]
: >"$PROGRESS"
extract_package() {
  local archive="$1" expected="$2" first top
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  top="${first%%/*}"; top="${top#./}"
  [[ "$top" == "$expected" ]]
  rm -rf "$SOURCES/$expected"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$expected"
}

printf 'BUILD_BLFS_PLASMA22=kdeplasma-addons\n'
extract_package kdeplasma-addons-6.4.4.tar.xz kdeplasma-addons-6.4.4
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
  -W no-dev ..
{
  grep -E '^(Plasma5Support_DIR|PlasmaQuick_DIR|KF6Runner_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt
  printf 'ADDONS_RUNTIME=not-started\nKAMELEON_HELPER=not-executed\nDEVICE_LEDS=not-accessed\n'
} >"$ADDONS_CONFIG"
grep -Eq '^Plasma5Support_DIR:PATH=/opt/kf6/lib/cmake/Plasma5Support$' "$ADDONS_CONFIG"
grep -Eq '^PlasmaQuick_DIR:PATH=/opt/kf6/lib/cmake/PlasmaQuick$' "$ADDONS_CONFIG"
grep -qx 'ADDONS_RUNTIME=not-started' "$ADDONS_CONFIG"
grep -qx 'KAMELEON_HELPER=not-executed' "$ADDONS_CONFIG"
grep -qx 'DEVICE_LEDS=not-accessed' "$ADDONS_CONFIG"
ninja
ninja install
cd /sources
rm -rf kdeplasma-addons-6.4.4
printf 'BLFS_PLASMA22_BUILT=kdeplasma-addons-6.4.4\n' >>"$PROGRESS"

printf 'BUILD_BLFS_PLASMA22=plasma-welcome\n'
extract_package plasma-welcome-6.4.4.tar.xz plasma-welcome-6.4.4
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
  -W no-dev ..
grep -q 'qml/Main.qml' build.ninja
grep -q 'plasma-welcome-publicplugin' build.ninja
{
  grep -E '^(KF6KirigamiAddons_DIR|Plasma_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt
  printf 'WELCOME_RUNTIME=not-started\nWELCOME_QML=build-graph-verified-not-run\n'
} >"$WELCOME_CONFIG"
grep -Eq '^KF6KirigamiAddons_DIR:PATH=/opt/kf6/lib/cmake/KF6KirigamiAddons$' "$WELCOME_CONFIG"
grep -qx 'WELCOME_RUNTIME=not-started' "$WELCOME_CONFIG"
grep -qx 'WELCOME_QML=build-graph-verified-not-run' "$WELCOME_CONFIG"
ninja
ninja install
cd /sources
rm -rf plasma-welcome-6.4.4
printf 'BLFS_PLASMA22_BUILT=plasma-welcome-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA22_BUILT=' "$PROGRESS")" -eq 2 ]]
COLORPICKER_DIR=/opt/kf6/lib/qml/org/kde/plasma/private/colorpicker
PROFILES_DIR=/opt/kf6/lib/qml/org/kde/plasma/private/profiles
KDED_DIR=/opt/kf6/lib/plugins/kf6/kded
mapfile -t COLORPICKER_PLUGINS < <(find "$COLORPICKER_DIR" -maxdepth 1 -type f -name '*.so' -print)
mapfile -t PROFILES_PLUGINS < <(find "$PROFILES_DIR" -maxdepth 1 -type f -name '*.so' -print)
mapfile -t WELCOME_KDED_PLUGINS < <(find "$KDED_DIR" -maxdepth 1 -type f -name '*plasma-welcome*.so' -print)
[[ "${#COLORPICKER_PLUGINS[@]}" -eq 1 && "${#PROFILES_PLUGINS[@]}" -eq 1 && "${#WELCOME_KDED_PLUGINS[@]}" -eq 1 ]]
COLORPICKER_PLUGIN="${COLORPICKER_PLUGINS[0]}"
PROFILES_PLUGIN="${PROFILES_PLUGINS[0]}"
WELCOME_KDED="${WELCOME_KDED_PLUGINS[0]}"
RUNNER_DICT=/opt/kf6/lib/plugins/kf6/krunner/krunner_dictionary.so
RUNNER_CONVERTER=/opt/kf6/lib/plugins/kf6/krunner/unitconverter.so
KAMELEON=/opt/kf6/lib/plugins/kf6/kded/kameleon.so
KAMELEON_HELPER=/opt/kf6/libexec/kf6/kauth/kameleonhelper
WELCOME=/opt/kf6/bin/plasma-welcome
for path in "$RUNNER_DICT" "$RUNNER_CONVERTER" "$KAMELEON" "$KAMELEON_HELPER" "$WELCOME" \
  "$COLORPICKER_DIR/qmldir" "$PROFILES_DIR/qmldir" \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.colorpicker/metadata.json \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.binaryclock/metadata.json \
  /opt/kf6/share/applications/org.kde.plasma-welcome.desktop; do
  [[ -f "$path" ]]
done
grep -q '"Id": "org.kde.plasma.colorpicker"' /opt/kf6/share/plasma/plasmoids/org.kde.plasma.colorpicker/metadata.json
grep -q '"Id": "org.kde.plasma.binaryclock"' /opt/kf6/share/plasma/plasmoids/org.kde.plasma.binaryclock/metadata.json
for elf in "$COLORPICKER_PLUGIN" "$PROFILES_PLUGIN" "$RUNNER_DICT" "$RUNNER_CONVERTER" "$KAMELEON" "$KAMELEON_HELPER" "$WELCOME" "$WELCOME_KDED"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$WELCOME" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
HELPER_INTERPRETER="$(readelf -l "$KAMELEON_HELPER" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$HELPER_INTERPRETER" == "$INTERPRETER" ]]
printf 'PLASMA22_POSTCHECK=addons-welcome-eight-elf-files-qml-not-executed\n'
{
  printf 'BLFS_PLASMA22_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-welcome-kameleon-helper-or-plugins\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=kdeplasma-addons+plasma-welcome\nELF_FILE_COUNT=8\n'
  printf 'KDEPLASMA_ADDONS=6.4.4\nCOLORPICKER_QML=installed-not-imported\nPROFILES_QML=installed-not-imported\nAPPLETS=installed-not-added\n'
  printf 'KRUNNER_DICTIONARY=installed-not-queried\nKRUNNER_CONVERTER=installed-not-queried\nKRUNNER=not-started\n'
  printf 'KAMELEON=installed-not-loaded\nKAMELEON_HELPER=installed-not-executed\nDEVICE_LEDS=not-accessed\nKAUTH=not-run\nPOLKIT=not-used\n'
  printf 'PLASMA_WELCOME=6.4.4\nWELCOME_EXECUTABLE=installed-not-executed\nWELCOME_KDED=installed-not-loaded\nWELCOME_QML=build-graph-verified-not-run\nUSER_FEEDBACK=not-started\n'
  printf 'KWIN_ADDONS=not-executed\nAPPIUM_TESTS=not-run\nTEST_SUITES=not-run\nNETWORK=not-used-by-built-programs\n'
  printf 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nPLASMA21=preserved-pipeline-210\nBLUEDEVIL=preserved-pipeline-210-not-started\n'
  printf 'PLASMA20=preserved-pipeline-209\nPLASMA_DISKS=preserved-pipeline-209-not-opened\nKDE_GTK_CONFIG=preserved-pipeline-209-not-applied\n'
  printf 'KSYSTEMSTATS=preserved-pipeline-207-not-executed\nQQC2_BREEZE_STYLE=preserved-pipeline-207-not-loaded\nSYSTEMMONITOR=preserved-pipeline-206-not-opened\n'
  printf 'PLASMA19=preserved-pipeline-207\nPLASMA18=preserved-pipeline-206\nPLASMA17=preserved-pipeline-204\nSDDM=preserved-not-started\n'
  printf 'PLASMA_DESKTOP=preserved-pipeline-183-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
