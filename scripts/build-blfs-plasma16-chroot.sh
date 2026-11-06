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
REPORT=/root/blfs-plasma16-report.txt
PROGRESS=/root/blfs-plasma16-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
pkg-config --exists xkbcommon wayland-client
for path in \
  /opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake \
  /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake \
  /opt/kf6/bin/ksshaskpass; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/libexec/xdg-desktop-portal-kde \
  /opt/kf6/lib/plugins/kf6/kded/plasmavault.so \
  /opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.vault.so \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.vault; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
packages=(xdg-desktop-portal-kde plasma-vault)
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
  printf 'BUILD_BLFS_PLASMA16=%s\n' "$name"
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
  printf 'BLFS_PLASMA16_BUILT=%s-6.4.4\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA16_BUILT=' "$PROGRESS")" -eq 2 ]]
PORTAL=/opt/kf6/libexec/xdg-desktop-portal-kde
VAULT_KDED=/opt/kf6/lib/plugins/kf6/kded/plasmavault.so
VAULT_APPLET=/opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.vault.so
VAULT_FILEITEM=/opt/kf6/lib/plugins/kf6/kfileitemaction/plasmavaultfileitemaction.so
[[ -x "$PORTAL" && -f "$VAULT_KDED" && -f "$VAULT_APPLET" && -f "$VAULT_FILEITEM" ]]
for path in \
  /opt/kf6/share/xdg-desktop-portal/portals/kde.portal \
  /opt/kf6/share/dbus-1/services/org.freedesktop.impl.portal.desktop.kde.service \
  /opt/kf6/share/applications/org.freedesktop.impl.portal.desktop.kde.desktop \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.vault/metadata.json; do
  [[ -f "$path" ]]
done
for elf in "$PORTAL" "$VAULT_KDED" "$VAULT_APPLET" "$VAULT_FILEITEM"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$PORTAL" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
if command -v gocryptfs >/dev/null 2>&1; then
  GOCRYPTFS_STATUS=found-not-used
else
  GOCRYPTFS_STATUS=not-found-runtime-backend-unavailable
fi
[[ "$GOCRYPTFS_STATUS" == not-found-runtime-backend-unavailable ]]
printf 'PLASMA16_POSTCHECK=portal-daemon-and-vault-plugins-elf\n'
{
  printf 'BLFS_PLASMA16_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-portal-daemon\nNEW_EXECUTABLES=xdg-desktop-portal-kde-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=xdg-desktop-portal-kde+plasma-vault\nXDG_PORTAL_KDE=6.4.4\nPLASMA_VAULT=6.4.4\n'
  printf 'PORTAL_DAEMON=built-elf-not-executed\nPORTAL_CONFIG=installed-not-activated\nPORTAL_BACKEND=not-started\nPORTAL_REQUESTS=not-run\n'
  printf 'VAULT_KDED=built-not-loaded\nVAULT_APPLET=built-not-loaded\nVAULT_FILEITEM_PLUGIN=built-not-loaded\nVAULT_PLASMOID=installed-not-loaded\n'
  printf 'GOCRYPTFS=%s\nVAULT_CREATION=not-run\nVAULT_UNLOCK=not-run\nVAULT_PASSWORD=not-entered\nFUSE=not-mounted\n' "$GOCRYPTFS_STATUS"
  printf 'DRKONQI=deferred-requires-systemd-coredumpd-integration\nTEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA15=preserved-pipeline-199\nSDDM=preserved-not-started\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'ACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
