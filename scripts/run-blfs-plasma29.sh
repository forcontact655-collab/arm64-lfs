#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma29-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA29_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma29-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/KPipeWire/KPipeWireConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/LayerShellQt/LayerShellQtConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Prison/KF6PrisonConfig.cmake" \
  "$LFS/opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake" \
  "$LFS/opt/kf6/lib/libKF6PrisonScanner.so.6.17.0" \
  "$LFS/usr/lib/libZXing.so.2.3.0" \
  "$LFS/usr/lib/cmake/opencv4/OpenCVConfig.cmake" \
  "$LFS/opt/kf6/lib/liboxygenstyle6.so.6.4.4" \
  "$LFS/opt/kf6/share/sounds/oxygen/index.theme"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
grep -q 'KF6::PrisonScanner' "$LFS/opt/kf6/lib/cmake/KF6Prison/KF6PrisonTargets.cmake" || preflight_fail missing-prison-scanner-target
for path in \
  "$LFS/opt/kf6/bin/spectacle" \
  "$LFS/opt/kf6/share/applications/org.kde.spectacle.desktop" \
  "$LFS/opt/kf6/share/dbus-1/services/org.kde.spectacle.service" \
  "$LFS/opt/kf6/share/dbus-1/services/org.kde.Spectacle.service" \
  "$LFS/opt/kf6/share/dbus-1/interfaces/org.kde.Spectacle.xml" \
  "$LFS/opt/kf6/share/kconf_update/spectacle.upd"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for tool in spectacle-24.02.0-video_format spectacle-24.02.0-keep_old_save_location spectacle-24.02.0-rename_settings spectacle-24.02.0-keep_old_filename_templates spectacle-24.02.0-change_placeholder_format; do
  [[ ! -e "$LFS/opt/kf6/lib/kconf_update_bin/$tool" ]] || preflight_fail "existing-kconf-$tool"
done
[[ -f "$HOST_SOURCES/spectacle-6.4.4.tar.xz" ]] || preflight_fail missing-source-spectacle
printf 'BLFS_PLASMA29_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma29-chroot.sh" "$LFS/root/build-blfs-plasma29-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma29-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress spectacle-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma29-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma29-$name.txt" >"$ARTIFACTS/blfs-plasma29-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA29_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma29-chroot.sh" \
  "$LFS/root/blfs-plasma29-report.txt" "$LFS/root/blfs-plasma29-progress.txt" \
  "$LFS/root/blfs-plasma29-spectacle-config.txt"
REPORT="$ARTIFACTS/blfs-plasma29-report.txt"
for expected in \
  'BLFS_PLASMA29_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-spectacle-or-kconf-update-tools' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' 'PACKAGES=spectacle' 'SPECTACLE=6.4.4' 'ELF_FILE_COUNT=6' 'BUILD_TESTING=OFF' \
  'SPECTACLE_RUNTIME=not-started' 'QML_UI=not-started' 'SCREENSHOT=not-captured' 'SCREEN_RECORDING=not-started' 'PIPEWIRE_STREAM=not-started' \
  'KPIPEWIRE_RECORD=build-dependency-no-stream' 'XCB_BACKEND=compiled-not-used' 'KCONF_UPDATE_TOOLS=installed-not-executed' 'DBUS_SERVICES=installed-not-activated' \
  'WACOMTABLET=deferred-requires-xorg-wacom' 'TEST_SUITES=not-run' 'NETWORK=not-used-by-built-programs' \
  'PLASMA28=failed-pipeline-218-restore-key-mismatch-no-install' \
  'PLASMA27=preserved-pipeline-217' 'ZXING=preserved-pipeline-217' 'PRISON_SCANNER=preserved-pipeline-217-not-run' \
  'PLASMA26=failed-pipeline-216-zxing-writers-off-missing-bitmatrix' 'PLASMA25=failed-pipeline-215-cmake-no-install' \
  'PLASMA24=preserved-pipeline-214' 'OXYGEN=preserved-pipeline-214-not-applied' 'PLASMA23=preserved-pipeline-213' 'SOUND_THEMES=preserved-pipeline-213-not-played' \
  'PLASMA22=preserved-pipeline-211' 'KDEPLASMA_ADDONS=preserved-pipeline-211-not-loaded' 'PLASMA_WELCOME=preserved-pipeline-211-not-opened' \
  'PLASMA21=preserved-pipeline-210' 'BLUEDEVIL=preserved-pipeline-210-not-started' 'PLASMA20=preserved-pipeline-209' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'SDDM=preserved-not-started' 'PLASMA_DESKTOP=preserved-pipeline-183-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA29_BUILT=' "$ARTIFACTS/blfs-plasma29-progress.txt")" -eq 1 ]]
grep -qx 'BLFS_PLASMA29_BUILT=spectacle-6.4.4' "$ARTIFACTS/blfs-plasma29-progress.txt"
grep -qx 'BUILD_TESTING:BOOL=OFF' "$ARTIFACTS/blfs-plasma29-spectacle-config.txt"
grep -qx 'SPECTACLE_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma29-spectacle-config.txt"
grep -qx 'SCREENSHOT=not-captured' "$ARTIFACTS/blfs-plasma29-spectacle-config.txt"
grep -qx 'SCREEN_RECORDING=not-started' "$ARTIFACTS/blfs-plasma29-spectacle-config.txt"
grep -qx 'KCONF_UPDATE_TOOLS=not-executed' "$ARTIFACTS/blfs-plasma29-spectacle-config.txt"
cat "$REPORT"
