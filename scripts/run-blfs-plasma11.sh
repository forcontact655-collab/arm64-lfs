#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma11-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA11_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma11-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/bin/kwrited" \
  "$LFS/opt/kf6/lib/qml/org/kde/milou/libmilouqmlplugin.so" \
  "$LFS/opt/kf6/bin/kwalletd6" \
  "$LFS/opt/kf6/lib/cmake/KF6Wallet/KF6WalletConfig.cmake" \
  "$LFS/usr/include/security/pam_appl.h" \
  "$LFS/usr/lib64/libpam.so" \
  "$LFS/usr/lib/libgcrypt.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
[[ "$(sudo -n stat -c %a "$LFS/opt/kf6/bin/kwrited")" == 4755 ]] || preflight_fail kwrited-mode
for path in \
  "$LFS/usr/bin/socat" \
  "$LFS/opt/kf6/lib/security/pam_kwallet5.so" \
  "$LFS/opt/kf6/libexec/pam_kwallet_init"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in socat-1.8.0.3.tar.bz2 kwallet-pam-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA11_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma11-chroot.sh" "$LFS/root/build-blfs-plasma11-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma11-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma11-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma11-$name.txt" >"$ARTIFACTS/blfs-plasma11-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA11_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma11-chroot.sh" \
  "$LFS/root/blfs-plasma11-report.txt" "$LFS/root/blfs-plasma11-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma11-report.txt"
for expected in \
  'BLFS_PLASMA11_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA11_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA11_EXEC_OK=1.8.0.3=local-stdio-exec-cat-relay' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=socat+kwallet-pam' 'SOCAT=1.8.0.3' 'KWALLET_PAM=6.4.4' \
  'NEW_EXECUTABLES=socat+filan+procan+pam_kwallet_init' 'EXECUTED_EXECUTABLES=socat-only-local-version-and-relay' \
  'SOCAT_EXEC=version-and-local-relay-passed' 'SOCAT_NETWORK=not-used' 'SOCAT_VERSION=1.8.0.3-verified-native' \
  'KWALLET_PAM_STATUS=built-socat-present-not-configured' 'PAM_MODULE=elf-entrypoints-verified-not-loaded' \
  'PAM_MODULE_PATH=/opt/kf6/lib/security/pam_kwallet5.so' 'PAM_AUTH=not-run' 'PAM_SESSION=not-run' \
  'PAM_CONFIG=not-modified' 'KWALLET_PAM_INIT=not-run' 'KWALLETD=not-started' \
  'KWALLETD_BIN_PATH=/opt/kf6/bin/kwalletd6' 'KWALLET_RUNTIME=functional-login-unlock-not-tested' \
  'TEST_SUITES=not-run' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA10=preserved-pipeline-191' 'KWRITED=preserved-setuid-4755-not-executed' 'MILOU=preserved-built-not-loaded' \
  'PLASMA_DESKTOP=preserved-not-rebuilt-not-running' 'ACTIVITY_SERVICE=preserved-not-started' \
  'KWIN=preserved-not-rebuilt-not-running' 'PLASMASHELL=not-started' \
  'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used-by-native-smoke' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA11_BUILT=' "$ARTIFACTS/blfs-plasma11-progress.txt")" -eq 2 ]]
cat "$REPORT"
