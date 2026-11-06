#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma17-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA17_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma17-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake" \
  "$LFS/usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/plasmavault.so" \
  "$LFS/opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.vault.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kfileitemaction/plasmavaultfileitemaction.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/usr/include/cups/cups.h" \
  "$LFS/opt/qt6/include/QtPrintSupport/6.9.2/QtPrintSupport/private/qcups_p.h" \
  "$LFS/opt/qt6/plugins/printsupport/libcupsprintersupport.so" \
  "$LFS/opt/kf6/libexec/xdg-desktop-portal-kde" \
  "$LFS/opt/kf6/share/xdg-desktop-portal/portals/kde.portal"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in cups-2.4.12-source.tar.gz qtbase-everywhere-src-6.9.2.tar.xz xdg-desktop-portal-kde-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA17_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma17-chroot.sh" "$LFS/root/build-blfs-plasma17-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma17-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress qtbase-config-summary cups-tls; do
  if sudo -n test -f "$LFS/root/blfs-plasma17-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma17-$name.txt" >"$ARTIFACTS/blfs-plasma17-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA17_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma17-chroot.sh" \
  "$LFS/root/blfs-plasma17-report.txt" "$LFS/root/blfs-plasma17-progress.txt" \
  "$LFS/root/blfs-plasma17-qtbase-config-summary.txt" "$LFS/root/blfs-plasma17-cups-tls.txt"
REPORT="$ARTIFACTS/blfs-plasma17-report.txt"
for expected in \
  'BLFS_PLASMA17_RESULT=ok' 'PACKAGE_COUNT=3' 'SOURCE_COUNT=3' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-portal-cups-or-print-tools' 'NEW_EXECUTABLES=portal-and-cups-installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'QTBASE=rebuilt-with-cups-6.9.2' 'QT_CUPS=enabled' \
  'QCUPS_PRIVATE_HEADER=installed' 'QCUPS_SYMBOLS=exported' 'CUPS_QT_PLUGIN=installed-linked-libcups' 'QT_CONFIG_SUMMARY=artifact' \
  'CUPS=2.4.12' 'CUPS_TLS=openssl-verified-config' 'CUPS_TLS_REPORT=artifact' \
  'CUPSD=installed-not-executed' 'CUPS_BOOTSCRIPT=removed' 'CUPS_SYSTEMD=disabled' \
  'PRINT_TOOLS=not-run' 'PRINT_JOBS=not-created' 'PRINTERS=not-configured' 'PRINTING=not-tested' \
  'PLASMA_VERSION=6.4.4' 'PACKAGES=cups+qtbase+xdg-desktop-portal-kde' 'XDG_PORTAL_KDE=6.4.4' \
  'PORTAL_DAEMON=built-elf-not-executed' 'PORTAL_CONFIG=installed-not-activated' \
  'PORTAL_BACKEND=not-started' 'PORTAL_REQUESTS=not-run' \
  'PLASMA_VAULT=preserved-pipeline-201-not-loaded' 'VAULT_OPERATIONS=not-run' \
  'GOCRYPTFS=not-installed-not-used' 'FUSE=not-mounted' \
  'DRKONQI=deferred-requires-systemd-coredumpd-integration' 'TEST_SUITES=not-run' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA16=preserved-pipeline-201' 'PLASMA15=preserved-pipeline-199' 'SDDM=preserved-not-started' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' \
  'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA17_BUILT=' "$ARTIFACTS/blfs-plasma17-progress.txt")" -eq 3 ]]
grep -Eq 'CUPS .*yes[[:space:]]*$' "$ARTIFACTS/blfs-plasma17-qtbase-config-summary.txt"
grep -qx '#define HAVE_OPENSSL 1' "$ARTIFACTS/blfs-plasma17-cups-tls.txt"
if grep -q '^#define HAVE_GNUTLS 1' "$ARTIFACTS/blfs-plasma17-cups-tls.txt"; then exit 1; fi
cat "$REPORT"
