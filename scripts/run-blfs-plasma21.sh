#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma21-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA21_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma21-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/KF6BluezQt/KF6BluezQtConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KIO/KF6KIOConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/qml/org/kde/bluezqt/qmldir" \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/kinfocenter/kcm_disks.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/gtkconfig.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_bluetooth.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/bluedevil.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kio/kio_bluetooth.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kio/kio_obexftp.so" \
  "$LFS/opt/kf6/bin/bluedevil-sendfile" \
  "$LFS/opt/kf6/bin/bluedevil-wizard" \
  "$LFS/opt/kf6/lib/qml/org/kde/plasma/private/bluetooth" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.bluetooth"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -f "$HOST_SOURCES/bluedevil-6.4.4.tar.xz" ]] || preflight_fail missing-source-bluedevil
printf 'BLFS_PLASMA21_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma21-chroot.sh" "$LFS/root/build-blfs-plasma21-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma21-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress bluedevil-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma21-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma21-$name.txt" >"$ARTIFACTS/blfs-plasma21-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA21_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma21-chroot.sh" \
  "$LFS/root/blfs-plasma21-report.txt" "$LFS/root/blfs-plasma21-progress.txt" \
  "$LFS/root/blfs-plasma21-bluedevil-config.txt"
REPORT="$ARTIFACTS/blfs-plasma21-report.txt"
for expected in \
  'BLFS_PLASMA21_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-bluedevil-tools-or-plugins' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' 'PACKAGES=bluedevil' 'BLUEDEVIL=6.4.4' 'ELF_FILE_COUNT=7' \
  'BLUETOOTH_KCM=installed-not-opened' 'BLUETOOTH_APPLET=installed-not-added' 'BLUETOOTH_QML_MODULE=installed-not-imported' 'BLUETOOTH_QML_PLUGIN_COUNT=1' \
  'KDED_BLUEDEVIL=installed-not-loaded' 'KIO_BLUETOOTH=installed-not-used' 'KIO_OBEXFTP=installed-not-used' \
  'BLUEDEVIL_SENDFILE=installed-not-executed' 'BLUEDEVIL_WIZARD=installed-not-executed' \
  'BLUEZQT=preserved-kf6-base14-no-manager' 'BLUEZ_DAEMON=not-started' 'BLUETOOTH=not-queried' 'BLUETOOTH_DEVICES=not-accessed' 'PAIRING=not-attempted' 'OBEX=not-used' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'NETWORK=not-used-by-built-programs' \
  'PLASMA20=preserved-pipeline-209' 'PLASMA_DISKS=preserved-pipeline-209-not-opened' 'KDE_GTK_CONFIG=preserved-pipeline-209-not-applied' \
  'KSYSTEMSTATS=preserved-pipeline-207-not-executed' 'QQC2_BREEZE_STYLE=preserved-pipeline-207-not-loaded' 'SYSTEMMONITOR=preserved-pipeline-206-not-opened' \
  'TEST_SUITES=not-run' 'PLASMA19=preserved-pipeline-207' 'PLASMA18=preserved-pipeline-206' 'PLASMA17=preserved-pipeline-204' 'SDDM=preserved-not-started' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA21_BUILT=' "$ARTIFACTS/blfs-plasma21-progress.txt")" -eq 1 ]]
grep -qx 'BLFS_PLASMA21_BUILT=bluedevil-6.4.4' "$ARTIFACTS/blfs-plasma21-progress.txt"
grep -Eq '^KF6BluezQt_DIR:PATH=/opt/kf6/lib/cmake/KF6BluezQt$' "$ARTIFACTS/blfs-plasma21-bluedevil-config.txt"
grep -qx 'BLUEZ_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma21-bluedevil-config.txt"
grep -qx 'BLUETOOTH=not-queried' "$ARTIFACTS/blfs-plasma21-bluedevil-config.txt"
cat "$REPORT"
