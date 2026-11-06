#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma23-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA23_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma23-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
[[ -x "$LFS/opt/kf6/bin/plasma-welcome" ]] || preflight_fail missing-existing-plasma-welcome
for path in "$LFS/opt/kf6/share/sounds/oxygen" "$LFS/opt/kf6/share/sounds/ocean" "$LFS/opt/kf6/share/sounds/Oxygen-Sys-Log-In-Short.ogg"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in oxygen-sounds-6.4.4.tar.xz ocean-sound-theme-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA23_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma23-chroot.sh" "$LFS/root/build-blfs-plasma23-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  /bin/bash --login /root/build-blfs-plasma23-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma23-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma23-$name.txt" >"$ARTIFACTS/blfs-plasma23-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA23_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma23-chroot.sh" \
  "$LFS/root/blfs-plasma23-report.txt" "$LFS/root/blfs-plasma23-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma23-report.txt"
for expected in \
  'BLFS_PLASMA23_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-data-only-stage' 'NEW_EXECUTABLES=none' 'NEW_ELF_FILES=0' 'ELF_ARCH=not-applicable-data-only' 'DYNAMIC_LINKER=not-applicable-data-only' \
  'PLASMA_VERSION=6.4.4' 'PACKAGES=oxygen-sounds+ocean-sound-theme' 'OXYGEN_SOUNDS=6.4.4' 'OCEAN_SOUND_THEME=6.4.4' \
  'OXYGEN_OGG_COUNT=113' 'OXYGEN_LEGACY_SYMLINK_COUNT=50' 'SOUND_SYMLINK_COUNT=77' 'OXYGEN_WAV_COUNT=1' 'OCEAN_OGA_COUNT=44' 'SOUND_FILE_COUNT=158' 'KF5_LEGACY_SOUNDS=installed-not-used' \
  'SOUND_FILES_MAGIC=verified-static-not-played' 'SOUND_FILES=installed-not-played' 'SOUND_THEME=not-applied' 'AUDIO_PLAYBACK=not-run' 'CONVERTERS=not-run' 'AUDIO=not-started' \
  'TEST_SUITES=not-run' 'NETWORK=not-used-by-built-programs' 'PLASMA22=preserved-pipeline-211' 'KDEPLASMA_ADDONS=preserved-pipeline-211-not-loaded' 'PLASMA_WELCOME=preserved-pipeline-211-not-opened' \
  'PLASMA21=preserved-pipeline-210' 'BLUEDEVIL=preserved-pipeline-210-not-started' 'PLASMA20=preserved-pipeline-209' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'SDDM=preserved-not-started' 'PLASMA_DESKTOP=preserved-pipeline-183-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA23_BUILT=' "$ARTIFACTS/blfs-plasma23-progress.txt")" -eq 2 ]]
grep -qx 'BLFS_PLASMA23_BUILT=oxygen-sounds-6.4.4' "$ARTIFACTS/blfs-plasma23-progress.txt"
grep -qx 'BLFS_PLASMA23_BUILT=ocean-sound-theme-6.4.4' "$ARTIFACTS/blfs-plasma23-progress.txt"
cat "$REPORT"
