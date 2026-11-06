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
REPORT=/root/blfs-plasma18-report.txt
PROGRESS=/root/blfs-plasma18-progress.txt
PRINT_CONFIG=/root/blfs-plasma18-print-manager-config.txt
SYSTEMMONITOR_CONFIG=/root/blfs-plasma18-systemmonitor-config.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /usr/include/cups/cups.h \
  /usr/lib/libcups.so.2 \
  /opt/qt6/include/QtPrintSupport/6.9.2/QtPrintSupport/private/qcups_p.h \
  /opt/qt6/plugins/printsupport/libcupsprintersupport.so \
  /opt/kf6/libexec/xdg-desktop-portal-kde \
  /opt/kf6/share/xdg-desktop-portal/portals/kde.portal \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake \
  /opt/kf6/lib/cmake/KF6KirigamiAddons/KF6KirigamiAddonsConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/plugins/kf6/kded/plasmavault.so; do
  [[ -e "$path" ]]
done
CUPS_MAJOR="$(awk '/CUPS_VERSION_MAJOR/{print $4}' /usr/include/cups/cups.h)"
CUPS_MINOR="$(awk '/CUPS_VERSION_MINOR/{print $4}' /usr/include/cups/cups.h)"
CUPS_PATCH="$(awk '/CUPS_VERSION_PATCH/{print $4}' /usr/include/cups/cups.h)"
[[ "$CUPS_MAJOR.$CUPS_MINOR.$CUPS_PATCH" == 2.4.12 ]]
for path in \
  /opt/kf6/bin/kde-print-queue \
  /opt/kf6/bin/configure-printer \
  /opt/kf6/bin/plasma-systemmonitor \
  /opt/kf6/lib/libkcupslib.so.6.4.4 \
  /opt/kf6/lib/plugins/kf6/kded/printmanager.so \
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_printer_manager.so \
  /opt/kf6/lib/qml/org/kde/plasma/printmanager \
  /opt/kf6/lib/qml/org/kde/systemmonitor \
  /opt/kf6/lib/qml/org/kde/ksysguard/page \
  /opt/kf6/lib/qml/org/kde/ksysguard/table \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.printmanager \
  /opt/kf6/share/ksysguard/sensorfaces/org.kde.ksysguard.applicationstable \
  /opt/kf6/share/ksysguard/sensorfaces/org.kde.ksysguard.processtable; do
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

printf 'BUILD_BLFS_PLASMA18=print-manager\n'
extract_package print-manager-6.4.4.tar.xz print-manager-6.4.4
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
  -D SCP_INSTALL=OFF \
  -W no-dev ..
grep -qx 'SCP_INSTALL:BOOL=OFF' CMakeCache.txt
if grep -q 'scpinstaller\.cpp' build.ninja; then
  printf 'UNEXPECTED_PRINT_MANAGER_SCP_SOURCE=enabled\n' >&2
  exit 1
fi
{
  grep -E '^(SCP_INSTALL|CUPS_|PackageKitQt6_|CMAKE_INSTALL_PREFIX)' CMakeCache.txt || true
  printf 'CUPS_HEADER_VERSION=%s.%s.%s\nSCP_INSTALL_SOURCE=excluded\n' "$CUPS_MAJOR" "$CUPS_MINOR" "$CUPS_PATCH"
} >"$PRINT_CONFIG"
grep -qx 'SCP_INSTALL:BOOL=OFF' "$PRINT_CONFIG"
grep -qx 'CUPS_HEADER_VERSION=2.4.12' "$PRINT_CONFIG"
grep -qx 'SCP_INSTALL_SOURCE=excluded' "$PRINT_CONFIG"
ninja
ninja install
cd /sources
rm -rf print-manager-6.4.4
printf 'BLFS_PLASMA18_BUILT=print-manager-6.4.4\n' >>"$PROGRESS"

printf 'BUILD_BLFS_PLASMA18=plasma-systemmonitor\n'
extract_package plasma-systemmonitor-6.4.4.tar.xz plasma-systemmonitor-6.4.4
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
  grep -E '^(KSysGuard_DIR|ksystemstats_EXE|KF6KirigamiAddons_DIR|Qt6QuickControls2_DIR|CMAKE_INSTALL_PREFIX)' CMakeCache.txt || true
  printf 'SYSTEMMONITOR_RUNTIME=not-started\n'
} >"$SYSTEMMONITOR_CONFIG"
grep -Eq '^KSysGuard_DIR(:[^=]+)?=/opt/kf6/' "$SYSTEMMONITOR_CONFIG"
grep -qx 'SYSTEMMONITOR_RUNTIME=not-started' "$SYSTEMMONITOR_CONFIG"
ninja
ninja install
cd /sources
rm -rf plasma-systemmonitor-6.4.4
printf 'BLFS_PLASMA18_BUILT=plasma-systemmonitor-6.4.4\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA18_BUILT=' "$PROGRESS")" -eq 2 ]]
PRINT_QUEUE=/opt/kf6/bin/kde-print-queue
CONFIGURE_PRINTER=/opt/kf6/bin/configure-printer
KCUPSLIB=/opt/kf6/lib/libkcupslib.so.6.4.4
PRINT_KCM=/opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_printer_manager.so
PRINT_KDED=/opt/kf6/lib/plugins/kf6/kded/printmanager.so
SYSTEMMONITOR=/opt/kf6/bin/plasma-systemmonitor
for path in \
  "$PRINT_QUEUE" "$CONFIGURE_PRINTER" "$KCUPSLIB" "$PRINT_KCM" "$PRINT_KDED" "$SYSTEMMONITOR" \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.printmanager/metadata.json \
  /opt/kf6/share/applications/org.kde.plasma-systemmonitor.desktop \
  /opt/kf6/share/ksysguard/sensorfaces/org.kde.ksysguard.applicationstable/metadata.json \
  /opt/kf6/share/ksysguard/sensorfaces/org.kde.ksysguard.processtable/metadata.json \
  /opt/kf6/share/plasma-systemmonitor/overview.page \
  /opt/kf6/share/plasma-systemmonitor/processes.page; do
  [[ -f "$path" ]]
done
grep -q '"Id"[[:space:]]*:[[:space:]]*"org.kde.plasma.printmanager"' /opt/kf6/share/plasma/plasmoids/org.kde.plasma.printmanager/metadata.json
grep -q '^Exec=plasma-systemmonitor$' /opt/kf6/share/applications/org.kde.plasma-systemmonitor.desktop
readelf -d "$KCUPSLIB" | grep 'NEEDED.*libcups\.so\.2' >/dev/null
if readelf -d "$PRINT_KCM" | grep -qi packagekit; then
  printf 'UNEXPECTED_PRINT_MANAGER_PACKAGEKIT_LINKAGE=present\n' >&2
  exit 1
fi
for elf in "$PRINT_QUEUE" "$CONFIGURE_PRINTER" "$KCUPSLIB" "$PRINT_KCM" "$PRINT_KDED" "$SYSTEMMONITOR"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$SYSTEMMONITOR" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
for executable in "$PRINT_QUEUE" "$CONFIGURE_PRINTER"; do
  OTHER_INTERPRETER="$(readelf -l "$executable" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
  [[ "$OTHER_INTERPRETER" == "$INTERPRETER" ]]
done
QML_PLUGIN_COUNT=0
check_qml_module() {
  local uri="$1" directory="$2"
  local -a plugins=()
  [[ -f "$directory/qmldir" ]]
  grep -qx "module $uri" "$directory/qmldir"
  mapfile -t plugins < <(find "$directory" -maxdepth 1 -type f -name '*.so' -print)
  [[ "${#plugins[@]}" -eq 1 ]]
  readelf -h "${plugins[0]}" | grep -q 'Machine:.*AArch64'
  QML_PLUGIN_COUNT=$((QML_PLUGIN_COUNT + 1))
}
check_qml_module org.kde.plasma.printmanager /opt/kf6/lib/qml/org/kde/plasma/printmanager
check_qml_module org.kde.systemmonitor /opt/kf6/lib/qml/org/kde/systemmonitor
check_qml_module org.kde.ksysguard.page /opt/kf6/lib/qml/org/kde/ksysguard/page
check_qml_module org.kde.ksysguard.table /opt/kf6/lib/qml/org/kde/ksysguard/table
[[ "$QML_PLUGIN_COUNT" -eq 4 ]]
printf 'PLASMA18_POSTCHECK=print-manager-systemmonitor-elf-qml-files-not-executed\n'
{
  printf 'BLFS_PLASMA18_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-print-manager-or-systemmonitor\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=print-manager+plasma-systemmonitor\n'
  printf 'PRINT_MANAGER=6.4.4\nKCUPSLIB=installed-linked-libcups\nCUPS=2.4.12-preserved-pipeline-204\nCUPSD=preserved-not-executed\n'
  printf 'PRINT_MANAGER_KCM=installed-not-opened\nPRINT_MANAGER_KDED=installed-not-loaded\nPRINT_MANAGER_PLASMOID=installed-not-loaded\nPRINT_MANAGER_TOOLS=installed-not-executed\n'
  printf 'SCP_INSTALL=disabled-verified-cache-and-source-exclusion\nPACKAGEKIT_INSTALLER=disabled\nSMB_PRINTING=not-tested\n'
  printf 'PRINT_TOOLS=not-run\nPRINT_JOBS=not-created\nPRINTERS=not-configured\nPRINTING=not-tested\n'
  printf 'SYSTEMMONITOR=6.4.4\nSYSTEMMONITOR_EXECUTABLE=installed-not-executed\nSYSTEMMONITOR_QML=installed-not-loaded\nQML_PLUGIN_COUNT=%s\nSENSOR_FACES=installed-not-loaded\n' "$QML_PLUGIN_COUNT"
  printf 'KSYSGUARD=required-build-dependency-verified\nKSYSTEMSTATS=not-started-runtime-unverified\nSENSORS=not-queried\nPROCESSES=not-listed-or-signalled\nSYSTEMMONITOR_UI=not-opened\n'
  printf 'TEST_SUITES=not-run\nPLASMA17=preserved-pipeline-204\nXDG_PORTAL_KDE=preserved-not-activated\nPLASMA16=preserved-pipeline-201\nPLASMA15=preserved-pipeline-199\n'
  printf 'SDDM=preserved-not-started\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nKDED=not-started\n'
  printf 'NETWORK=not-used-by-built-programs\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
