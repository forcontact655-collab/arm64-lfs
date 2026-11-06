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
REPORT=/root/blfs-plasma20-report.txt
PROGRESS=/root/blfs-plasma20-progress.txt
DISKS_CONFIG=/root/blfs-plasma20-disks-config.txt
GTK_CONFIG=/root/blfs-plasma20-gtk-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
pkg-config --exists gtk+-3.0 glib-2.0 gobject-2.0 gio-2.0
for path in \
  /usr/bin/sassc \
  /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml \
  /opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake \
  /opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake \
  /opt/kf6/lib/cmake/KF6ColorScheme/KF6ColorSchemeConfig.cmake \
  /opt/kf6/lib/cmake/QQC2BreezeStyle/QQC2BreezeStyleConfig.cmake \
  /opt/kf6/bin/ksystemstats \
  /opt/kf6/bin/plasma-systemmonitor; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/plugins/plasma/kcms/kinfocenter/kcm_disks.so \
  /opt/kf6/lib/plugins/kf6/kded/smart.so \
  /opt/kf6/lib/plugins/kf6/kded/libsmart.so \
  /opt/kf6/libexec/kf6/kauth/kded-smart-helper \
  /opt/kf6/share/polkit-1/actions/org.kde.kded.smart.policy \
  /opt/kf6/lib/plugins/kf6/kded/gtkconfig.so \
  /opt/kf6/lib/plugins/kf6/kded/libgtkconfig.so \
  /opt/kf6/libexec/gtk3_preview \
  /opt/kf6/lib/gtk-3.0/modules/libcolorreload-gtk-module.so \
  /opt/kf6/lib/gtk-3.0/modules/libwindow-decorations-gtk-module.so \
  /opt/kf6/lib/kconf_update_bin/gtk_theme \
  /opt/kf6/lib/kconf_update_bin/remove_deprecated_gtk4_option; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
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

printf 'BUILD_BLFS_PLASMA20=plasma-disks\n'
extract_package plasma-disks-6.4.4.tar.xz plasma-disks-6.4.4
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
  -D WITH_SIMULATION=OFF \
  -W no-dev ..
grep -qx 'WITH_SIMULATION:BOOL=OFF' CMakeCache.txt
{
  grep -E '^(smartctl_EXE|WITH_SIMULATION|CMAKE_INSTALL_PREFIX)' CMakeCache.txt || true
  printf 'DISKS_RUNTIME=not-started\n'
} >"$DISKS_CONFIG"
grep -qx 'WITH_SIMULATION:BOOL=OFF' "$DISKS_CONFIG"
grep -qx 'DISKS_RUNTIME=not-started' "$DISKS_CONFIG"
ninja
ninja install
cd /sources
rm -rf plasma-disks-6.4.4
printf 'BLFS_PLASMA20_BUILT=plasma-disks-6.4.4\n' >>"$PROGRESS"

printf 'BUILD_BLFS_PLASMA20=kde-gtk-config\n'
extract_package kde-gtk-config-6.4.4.tar.xz kde-gtk-config-6.4.4
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
  grep -E '^(Sass_EXECUTABLE|XSettingsd_PATH|GLIB_SCHEMAS_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt || true
  printf 'GTK_SETTINGS=not-applied\n'
} >"$GTK_CONFIG"
grep -Eq '^Sass_EXECUTABLE(:[^=]+)?=/usr/bin/sassc$' "$GTK_CONFIG"
grep -qx 'GTK_SETTINGS=not-applied' "$GTK_CONFIG"
grep -q 'window_decorations\.css' build.ninja
ninja
ninja install
cd /sources
rm -rf kde-gtk-config-6.4.4
printf 'BLFS_PLASMA20_BUILT=kde-gtk-config-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA20_BUILT=' "$PROGRESS")" -eq 2 ]]
DISKS_KCM=/opt/kf6/lib/plugins/plasma/kcms/kinfocenter/kcm_disks.so
SMART_HELPER=/opt/kf6/libexec/kf6/kauth/kded-smart-helper
SMART_POLICY=/opt/kf6/share/polkit-1/actions/org.kde.kded.smart.policy
GTK_PREVIEW=/opt/kf6/libexec/gtk3_preview
GTK_COLOR_MODULE=/opt/kf6/lib/gtk-3.0/modules/libcolorreload-gtk-module.so
GTK_DECORATIONS_MODULE=/opt/kf6/lib/gtk-3.0/modules/libwindow-decorations-gtk-module.so
GTK_THEME_TOOL=/opt/kf6/lib/kconf_update_bin/gtk_theme
GTK4_CLEANUP_TOOL=/opt/kf6/lib/kconf_update_bin/remove_deprecated_gtk4_option
GTK_CSS=/opt/kf6/share/themes/Breeze/window_decorations.css
KDED_DIR=/opt/kf6/lib/plugins/kf6/kded
mapfile -t SMART_PLUGINS < <(find "$KDED_DIR" -maxdepth 1 -type f \( -name smart.so -o -name libsmart.so \) -print)
mapfile -t GTK_PLUGINS < <(find "$KDED_DIR" -maxdepth 1 -type f \( -name gtkconfig.so -o -name libgtkconfig.so \) -print)
[[ "${#SMART_PLUGINS[@]}" -eq 1 && "${#GTK_PLUGINS[@]}" -eq 1 ]]
SMART_PLUGIN="${SMART_PLUGINS[0]}"
GTK_PLUGIN="${GTK_PLUGINS[0]}"
for path in "$DISKS_KCM" "$SMART_HELPER" "$SMART_POLICY" "$GTK_PREVIEW" "$GTK_COLOR_MODULE" "$GTK_DECORATIONS_MODULE" "$GTK_THEME_TOOL" "$GTK4_CLEANUP_TOOL" "$GTK_CSS"; do
  [[ -f "$path" ]]
done
for elf in "$DISKS_KCM" "$SMART_PLUGIN" "$SMART_HELPER" "$GTK_PLUGIN" "$GTK_PREVIEW" "$GTK_COLOR_MODULE" "$GTK_DECORATIONS_MODULE" "$GTK_THEME_TOOL" "$GTK4_CLEANUP_TOOL"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$SMART_HELPER" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
for executable in "$GTK_PREVIEW" "$GTK_THEME_TOOL" "$GTK4_CLEANUP_TOOL"; do
  OTHER_INTERPRETER="$(readelf -l "$executable" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
  [[ "$OTHER_INTERPRETER" == "$INTERPRETER" ]]
done
printf 'PLASMA20_POSTCHECK=disks-and-gtk-config-elf-files-not-executed\n'
{
  printf 'BLFS_PLASMA20_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-smart-helper-gtk-preview-or-kconf-update\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=plasma-disks+kde-gtk-config\n'
  printf 'PLASMA_DISKS=6.4.4\nDISKS_KCM=installed-not-opened\nKDED_SMART=installed-not-loaded\nSMART_HELPER=installed-not-executed\n'
  printf 'SMART_POLICY=installed-not-used\nSMARTCTL=not-run-runtime-unverified\nSMART=not-queried\nDISKS=not-accessed\nDISKS_SIMULATION=disabled\nKAUTH=not-run\nPOLKIT=not-used\n'
  printf 'KDE_GTK_CONFIG=6.4.4\nGTK_KDED=installed-not-loaded\nGTK_MODULES=installed-not-loaded\nGTK_CSS=built-present-not-applied\nGTK_PREVIEW=installed-not-executed\n'
  printf 'KCONF_UPDATE_TOOLS=installed-not-executed\nGTK_SETTINGS=not-applied\nXSETTINGSD=not-started-runtime-unverified\n'
  printf 'KSYSTEMSTATS=preserved-pipeline-207-not-executed\nQQC2_BREEZE_STYLE=preserved-pipeline-207-not-loaded\nSYSTEMMONITOR=preserved-pipeline-206-not-opened\n'
  printf 'TEST_SUITES=not-run\nPLASMA19=preserved-pipeline-207\nPLASMA18=preserved-pipeline-206\nPLASMA17=preserved-pipeline-204\nSDDM=preserved-not-started\n'
  printf 'PLASMA_DESKTOP=preserved-pipeline-183-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\n'
  printf 'NETWORK=not-used-by-built-programs\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
