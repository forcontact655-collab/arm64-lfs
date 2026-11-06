#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma15-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA15_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma15-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/usr/lib/libXxf86vm.so" \
  "$LFS/opt/kf6/lib/cmake/KF6Wallet/KF6WalletConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Archive/KF6ArchiveConfig.cmake" \
  "$LFS/opt/kf6/libexec/org_kde_powerdevil"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_kgamma.so" \
  "$LFS/opt/kf6/bin/ksshaskpass" \
  "$LFS/opt/kf6/bin/sddmthemeinstaller"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -z "$(find "$LFS/opt/kf6/lib/plugins" -type f -name kcm_sddm.so -print -quit)" ]] || preflight_fail existing-kcm_sddm
[[ -z "$(find "$LFS/opt/kf6/libexec" -type f -name kcmsddm_authhelper -print -quit)" ]] || preflight_fail existing-kcmsddm_authhelper
for name in kgamma-6.4.4.tar.xz ksshaskpass-6.4.4.tar.xz sddm-kcm-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA15_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma15-chroot.sh" "$LFS/root/build-blfs-plasma15-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma15-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma15-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma15-$name.txt" >"$ARTIFACTS/blfs-plasma15-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA15_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma15-chroot.sh" \
  "$LFS/root/blfs-plasma15-report.txt" "$LFS/root/blfs-plasma15-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma15-report.txt"
for expected in \
  'BLFS_PLASMA15_RESULT=ok' 'PACKAGE_COUNT=3' 'SOURCE_COUNT=3' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-password-theme-and-auth-tools' \
  'NEW_EXECUTABLES=ksshaskpass+sddmthemeinstaller+kcmsddm_authhelper-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=kgamma+ksshaskpass+sddm-kcm' \
  'KGAMMA=6.4.4' 'KSSHASKPASS=6.4.4' 'SDDM_KCM=6.4.4' \
  'KGAMMA_KCM=built-not-loaded' 'KGAMMA_INIT=installed-not-run' 'GAMMA=not-changed' 'XF86VIDMODE=not-queried' \
  'KSSHASKPASS_EXEC=not-run-no-password-or-wallet' 'KWALLET=not-opened' 'SSH_ASKPASS=not-invoked' \
  'SDDM_KCM_PLUGIN=built-not-loaded' 'SDDM_AUTHHELPER=installed-not-executed' \
  'SDDM_HELPER_MODE=observed-in-host-log' 'SDDM_THEME_INSTALLER=built-not-executed' \
  'SDDM_CONFIG=not-modified' 'SDDM=not-started' 'TEST_SUITES=not-run' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA14=preserved-pipeline-198' 'POWERDEVIL=preserved-not-executed' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' \
  'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA15_BUILT=' "$ARTIFACTS/blfs-plasma15-progress.txt")" -eq 3 ]]
cat "$REPORT"
