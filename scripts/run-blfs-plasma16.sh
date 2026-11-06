#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma16-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA16_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma16-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake" \
  "$LFS/opt/kf6/bin/ksshaskpass"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/plasmavault.so" \
  "$LFS/opt/kf6/lib/plugins/plasma/applets/org.kde.plasma.vault.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kfileitemaction/plasmavaultfileitemaction.so" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.vault"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -f "$HOST_SOURCES/plasma-vault-6.4.4.tar.xz" ]] || preflight_fail missing-source-plasma-vault
printf 'BLFS_PLASMA16_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma16-chroot.sh" "$LFS/root/build-blfs-plasma16-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma16-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma16-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma16-$name.txt" >"$ARTIFACTS/blfs-plasma16-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA16_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma16-chroot.sh" \
  "$LFS/root/blfs-plasma16-report.txt" "$LFS/root/blfs-plasma16-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma16-report.txt"
for expected in \
  'BLFS_PLASMA16_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-no-new-executables' 'NEW_EXECUTABLES=none-vault-plugins-only' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=not-applicable-shared-plugins' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=plasma-vault' 'PLASMA_VAULT=6.4.4' \
  'XDG_PORTAL_KDE=deferred-pipeline-200-missing-qt-cups-private-support' 'QT_CUPS=not-rebuilt' \
  'CUPS=not-installed-not-started' 'PORTAL_DAEMON=not-built-not-executed' \
  'PORTAL_BACKEND=not-started' 'PORTAL_REQUESTS=not-run' 'PRINTING=not-tested' \
  'VAULT_KDED=built-not-loaded' 'VAULT_APPLET=built-not-loaded' \
  'VAULT_FILEITEM_PLUGIN=built-not-loaded' 'VAULT_PLASMOID=installed-not-loaded' \
  'GOCRYPTFS=not-found-runtime-backend-unavailable' 'VAULT_BACKENDS=not-executed' \
  'VAULT_CREATION=not-run' 'VAULT_UNLOCK=not-run' 'VAULT_PASSWORD=not-entered' 'FUSE=not-mounted' \
  'DRKONQI=deferred-requires-systemd-coredumpd-integration' 'TEST_SUITES=not-run' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA15=preserved-pipeline-199' 'SDDM=preserved-not-started' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' \
  'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA16_BUILT=' "$ARTIFACTS/blfs-plasma16-progress.txt")" -eq 1 ]]
cat "$REPORT"
