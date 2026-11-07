#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma35-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA35_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma35-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in "$LFS/usr/bin/cmake" "$LFS/usr/bin/ninja" "$LFS/usr/bin/pkg-config" "$LFS/usr/bin/python3" "$LFS/usr/bin/readelf" \
  "$LFS/usr/lib/pkgconfig/libsystemd.pc" \
  "$LFS/opt/qt6/lib/cmake/Qt6/Qt6Config.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Kirigami/KF6KirigamiConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6ItemModels/KF6ItemModelsConfig.cmake" \
  "$LFS/usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake" \
  "$LFS/usr/lib/libpolkit-qt6-core-1.so" \
  "$LFS/opt/kf6/lib/qml/org/kde/kirigami/qmldir" \
  "$LFS/opt/kf6/lib/qml/org/kde/kitemmodels/qmldir" \
  "$LFS/opt/kf6/lib/qml/org/kde/syntaxhighlighting/qmldir"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for module in KF6I18n KF6CoreAddons KF6Config KF6Service KF6JobWidgets KF6KIO KF6Crash KF6WidgetsAddons KF6Wallet KF6Notifications KF6IdleTime KF6WindowSystem KF6SyntaxHighlighting KF6StatusNotifierItem; do
  [[ -e "$LFS/opt/kf6/lib/cmake/$module/${module}Config.cmake" ]] || preflight_fail "missing-kf6-module-$module"
done
for path in "$LFS/opt/kf6/libexec/drkonqi" "$LFS/opt/kf6/lib/libexec/drkonqi"; do
  [[ ! -e "$path" ]] || preflight_fail "existing-$path"
done
for path in "$LFS/opt/kf6/lib/libKF6NetworkManagerQt.so" "$LFS/opt/kf6/lib/libplasmanm_internal.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-accepted-plasma34-$path"
done
for name in drkonqi-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA35_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma35-chroot.sh" "$LFS/root/build-blfs-plasma35-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma35-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
NAMES=(report progress drkonqi-install-manifest drkonqi-config)
for name in "${NAMES[@]}"; do
  if sudo -n test -f "$LFS/root/blfs-plasma35-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma35-$name.txt" >"$ARTIFACTS/blfs-plasma35-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA35_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma35-chroot.sh"
for name in "${NAMES[@]}"; do sudo -n rm -f "$LFS/root/blfs-plasma35-$name.txt"; done
REPORT="$ARTIFACTS/blfs-plasma35-report.txt"
for expected in \
  'BLFS_PLASMA35_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-new-installed-tools-post-install' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'PACKAGES=drkonqi' 'DRKONQI=6.4.4' 'KF6_VERSION=6.17.0' 'PLASMA_VERSION=6.4.4' \
  'COREDUMP_INTEGRATION=compiled-not-started' 'PYTHON_VENDORING=disabled-by-official-option' \
  'CMAKE_BUILD_TESTING=OFF' 'BUILD_TESTING=OFF' \
  'SYSTEMD_UNITS=installed-not-enabled' \
  'DRKONQI_RUNTIME=not-started' 'COREDUMPD_RUNTIME=not-started' 'JOURNAL_READ=not-performed' 'CRASH_DIALOG=not-shown' \
  'QML_UI=not-started' 'DBUS_SERVICES=installed-not-activated' 'GDB=not-executed' 'COREDUMPCTL=not-executed' \
  'OFFICIAL_PLASMA_ACTIVE=56' 'OFFICIAL_PLASMA_BUILDABLE_COVERED=56' 'OFFICIAL_PLASMA_DEFERRED=0' 'OFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order' \
  'PLASMA_NM=preserved-pipeline-230' 'PLASMA33=preserved-pipeline-229' 'PLASMA32=preserved-pipeline-223' \
  'NETWORK=not-used-by-built-programs' 'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
grep -Eq '^LIB_SYSTEMD_VERSION=[0-9]+\.[0-9]+' "$REPORT"
grep -Eq '^SYSTEMD_LINK=(libsystemd|libelogind)(\+(libsystemd|libelogind))?$' "$REPORT"
grep -Eq '^SYSTEMD_UNIT_FILE_COUNT=[0-9]+$' "$REPORT"
grep -Eq '^ELF_FILE_COUNT=[0-9]+$' "$REPORT"
grep -Eq '^DRKONQI_BINARY=/opt/kf6/lib(exec)?/drkonqi$' "$REPORT"
[[ "$(grep -c '^BLFS_PLASMA35_BUILT=' "$ARTIFACTS/blfs-plasma35-progress.txt")" -eq 1 ]]
grep -qxF 'BLFS_PLASMA35_BUILT=drkonqi-6.4.4' "$ARTIFACTS/blfs-plasma35-progress.txt"
config_line() { grep -qxF "$1" "$ARTIFACTS/blfs-plasma35-drkonqi-config.txt"; }
for expected in 'PROJECT=drkonqi' 'PROJECT_VERSION=6.4.4' 'BUILD_TESTING=OFF' \
  'PYTHON_VENDORING=disabled-by-official-option' \
  'WITH_PYTHON_VENDORING:BOOL=OFF' 'BUILD_TESTING:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6' \
  'COREDUMP_INTEGRATION=compiled' 'SYSTEMD_UNITS=installed-not-enabled'; do
  config_line "$expected"
done
grep -q '^REQUIRED_TARGETS=.*drkonqi-coredump-launcher' "$ARTIFACTS/blfs-plasma35-drkonqi-config.txt"
MANIFEST_FILE="$ARTIFACTS/blfs-plasma35-drkonqi-install-manifest.txt"
[[ -s "$MANIFEST_FILE" ]]
grep -q '^/opt/kf6/share/applications/org.kde.drkonqi.desktop$' "$MANIFEST_FILE"
grep -Eq '^/opt/kf6/lib(exec)?/drkonqi$' "$MANIFEST_FILE"
for name in drkonqi-coredump-launcher drkonqi-coredump-processor drkonqi-coredump-gui drkonqi-coredump-cleanup drkonqi-polkit-helper; do
  grep -Eq "^/opt/kf6/libexec/${name}$" "$MANIFEST_FILE"
done
cat "$REPORT"
