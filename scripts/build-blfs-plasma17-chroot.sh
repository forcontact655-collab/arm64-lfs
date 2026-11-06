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
REPORT=/root/blfs-plasma17-report.txt
PROGRESS=/root/blfs-plasma17-progress.txt
QT_CONFIG_SUMMARY=/root/blfs-plasma17-qtbase-config-summary.txt
CUPS_TLS_REPORT=/root/blfs-plasma17-cups-tls.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/pkg-config ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
pkg-config --exists openssl xkbcommon wayland-client
for path in \
  /opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake \
  /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake \
  /opt/kf6/lib/plugins/kf6/kded/plasmavault.so \
  /opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.vault.so \
  /opt/kf6/lib/plugins/kf6/kfileitemaction/plasmavaultfileitemaction.so; do
  [[ -e "$path" ]]
done
for path in \
  /usr/include/cups/cups.h \
  /opt/qt6/include/QtPrintSupport/6.9.2/QtPrintSupport/private/qcups_p.h \
  /opt/kf6/libexec/xdg-desktop-portal-kde \
  /opt/kf6/share/xdg-desktop-portal/portals/kde.portal; do
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

if ! getent group lp >/dev/null; then groupadd lp; fi
if ! id lp >/dev/null 2>&1; then
  useradd -c 'Print Service User' -d /var/spool/cups -g lp -s /bin/false lp
fi
if ! getent group lpadmin >/dev/null; then groupadd lpadmin; fi
printf 'BUILD_BLFS_PLASMA17=cups\n'
extract_package cups-2.4.12-source.tar.gz cups-2.4.12
./configure --prefix=/usr \
  --libdir=/usr/lib \
  --with-tls=openssl \
  --with-ondemand=no \
  --with-systemd=no \
  --with-rcdir=/tmp/cupsinit \
  --with-rundir=/run/cups \
  --with-system-groups=lpadmin \
  --with-docdir=/usr/share/cups/doc-2.4.12 \
  --disable-libusb
grep -q '^#define HAVE_OPENSSL 1' config.h
if grep -q '^#define HAVE_GNUTLS 1' config.h; then
  printf 'UNEXPECTED_CUPS_TLS=gnutls\n' >&2
  exit 1
fi
{ grep -E '^#define HAVE_(OPENSSL|GNUTLS) ' config.h || true; } >"$CUPS_TLS_REPORT"
make
make install
ln -svnf ../cups/doc-2.4.12 /usr/share/doc/cups-2.4.12
rm -rf /tmp/cupsinit
cd /sources
rm -rf cups-2.4.12
printf 'BLFS_PLASMA17_BUILT=cups-2.4.12\n' >>"$PROGRESS"
[[ -f /usr/include/cups/cups.h && -f /usr/lib/libcups.so.2 && -x /usr/sbin/cupsd ]]
[[ "$(awk '/CUPS_VERSION_MAJOR/{print $4}' /usr/include/cups/cups.h)" == 2 ]]
[[ "$(awk '/CUPS_VERSION_MINOR/{print $4}' /usr/include/cups/cups.h)" == 4 ]]
[[ "$(awk '/CUPS_VERSION_PATCH/{print $4}' /usr/include/cups/cups.h)" == 12 ]]
[[ ! -e /tmp/cupsinit && ! -e /usr/lib/systemd/system/cups.service && ! -e /usr/lib/systemd/system/cups.socket ]]

printf 'BUILD_BLFS_PLASMA17=qtbase-cups\n'
extract_package qtbase-everywhere-src-6.9.2.tar.xz qtbase-everywhere-src-6.9.2
mkdir build
cd build
../configure -prefix /opt/qt6 \
  -sysconfdir /etc/xdg \
  -dbus-linked \
  -openssl-linked \
  -cups \
  -qt-sqlite \
  -system-doubleconversion \
  -system-pcre \
  -system-zlib \
  -system-harfbuzz \
  -system-freetype \
  -system-libpng \
  -icu \
  -fontconfig \
  -xcb \
  -xkbcommon \
  -egl \
  -opengl desktop \
  -syslog \
  -nomake examples \
  -nomake tests \
  -no-rpath \
  -no-sbom
[[ -s config.summary ]]
grep -Eq 'CUPS .*yes[[:space:]]*$' config.summary
cp config.summary "$QT_CONFIG_SUMMARY"
ninja
ninja install
find /opt/qt6 -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
cd /sources
rm -rf qtbase-everywhere-src-6.9.2
printf 'BLFS_PLASMA17_BUILT=qtbase-everywhere-src-6.9.2\n' >>"$PROGRESS"
QT_VERSION="$(/opt/qt6/bin/qmake6 -query QT_VERSION)"
[[ "$QT_VERSION" == 6.9.2 ]]
QTPS=/opt/qt6/lib/libQt6PrintSupport.so.6.9.2
QCUPS_HEADER=/opt/qt6/include/QtPrintSupport/6.9.2/QtPrintSupport/private/qcups_p.h
[[ -f "$QTPS" && -f "$QCUPS_HEADER" ]]
QT_SYMBOLS=/tmp/blfs-plasma17-qtprintsupport-symbols.txt
nm -D --defined-only "$QTPS" | c++filt >"$QT_SYMBOLS"
grep -q 'QCUPSSupport::setPageSet' "$QT_SYMBOLS"
rm -f "$QT_SYMBOLS"
printf 'QT_CUPS_POSTCHECK=symbols-exported\n'
readelf -d "$QTPS" | grep -q 'NEEDED.*libcups\.so\.2'

printf 'BUILD_BLFS_PLASMA17=xdg-desktop-portal-kde\n'
extract_package xdg-desktop-portal-kde-6.4.4.tar.xz xdg-desktop-portal-kde-6.4.4
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
ninja
ninja install
cd /sources
rm -rf xdg-desktop-portal-kde-6.4.4
printf 'BLFS_PLASMA17_BUILT=xdg-desktop-portal-kde-6.4.4\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA17_BUILT=' "$PROGRESS")" -eq 3 ]]
PORTAL=/opt/kf6/libexec/xdg-desktop-portal-kde
LIBCUPS=/usr/lib/libcups.so.2
CUPSD=/usr/sbin/cupsd
[[ -x "$PORTAL" && -x "$CUPSD" && -f "$LIBCUPS" && -f "$QTPS" ]]
for path in \
  /opt/kf6/share/xdg-desktop-portal/portals/kde.portal \
  /opt/kf6/share/dbus-1/services/org.freedesktop.impl.portal.desktop.kde.service \
  /opt/kf6/share/applications/org.freedesktop.impl.portal.desktop.kde.desktop \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.vault/metadata.json; do
  [[ -f "$path" ]]
done
for elf in "$PORTAL" "$CUPSD" "$LIBCUPS" "$QTPS"; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l "$PORTAL" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
CUPS_INTERPRETER="$(readelf -l "$CUPSD" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$CUPS_INTERPRETER" == "$INTERPRETER" ]]
[[ -z "$(command -v gocryptfs || true)" ]]
printf 'PLASMA17_POSTCHECK=cups-qtbase-portal-elf-not-executed\n'
{
  printf 'BLFS_PLASMA17_RESULT=ok\nPACKAGE_COUNT=3\nSOURCE_COUNT=3\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-portal-cups-or-print-tools\nNEW_EXECUTABLES=portal-and-cups-installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=%s\nQTBASE=rebuilt-with-cups-6.9.2\nQT_CUPS=enabled\nQCUPS_PRIVATE_HEADER=installed\nQCUPS_SYMBOLS=exported\nQT_CONFIG_SUMMARY=artifact\n' "$QT_VERSION"
  printf 'CUPS=2.4.12\nCUPS_TLS=openssl-verified-config\nCUPS_TLS_REPORT=artifact\nCUPSD=installed-not-executed\nCUPS_BOOTSCRIPT=removed\nCUPS_SYSTEMD=disabled\n'
  printf 'PRINT_TOOLS=not-run\nPRINT_JOBS=not-created\nPRINTERS=not-configured\nPRINTING=not-tested\n'
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=cups+qtbase+xdg-desktop-portal-kde\nXDG_PORTAL_KDE=6.4.4\n'
  printf 'PORTAL_DAEMON=built-elf-not-executed\nPORTAL_CONFIG=installed-not-activated\nPORTAL_BACKEND=not-started\nPORTAL_REQUESTS=not-run\n'
  printf 'PLASMA_VAULT=preserved-pipeline-201-not-loaded\nVAULT_OPERATIONS=not-run\nGOCRYPTFS=not-installed-not-used\nFUSE=not-mounted\n'
  printf 'DRKONQI=deferred-requires-systemd-coredumpd-integration\nTEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA16=preserved-pipeline-201\nPLASMA15=preserved-pipeline-199\nSDDM=preserved-not-started\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'ACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
