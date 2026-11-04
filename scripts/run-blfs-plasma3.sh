#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma3-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA3_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma3-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KGlobalAccelD/KGlobalAccelDConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Aurorae/AuroraeConfig.cmake" \
  "$LFS/usr/lib64/libpam.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivitiesStats/PlasmaActivitiesStatsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KPipeWire/KPipeWireConfig.cmake"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -f "$HOST_SOURCES/libva-2.22.0.tar.gz" ]] || preflight_fail "missing-source-libva"
for name in plasma5support plasma-activities-stats kpipewire; do
  [[ -f "$HOST_SOURCES/$name-6.4.4.tar.xz" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA3_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma3-chroot.sh" "$LFS/root/build-blfs-plasma3-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma3-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma3-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma3-$name.txt" >"$ARTIFACTS/blfs-plasma3-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA3_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma3-chroot.sh" \
  "$LFS/root/blfs-plasma3-report.txt" "$LFS/root/blfs-plasma3-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma3-report.txt"
for expected in \
  'BLFS_PLASMA3_RESULT=ok' 'PACKAGE_COUNT=4' 'SOURCE_COUNT=4' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA3_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA3_EXEC_OK=6.9.2=6.4.4=plasma5support=activities-stats=kpipewire-type' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=libva+plasma5support+plasma-activities-stats+kpipewire' \
  'LIBVA=2.22.0' 'LIBVA_API=1.22.0' 'PLASMA5SUPPORT=6.4.4' 'PLASMA_ACTIVITIES_STATS=6.4.4' 'KPIPEWIRE=6.4.4' \
  'LIBVA_SMOKE=pkg-config-libva-and-drm-no-hardware' 'PLASMA5SUPPORT_SMOKE=native-version-string' 'PLASMA_ACTIVITIES_STATS_SMOKE=native-typeinfo-no-database' 'KPIPEWIRE_SMOKE=native-typeinfo-no-stream-no-session' \
  'NATIVE_SMOKE=cmake-targets+version+typeinfo-no-pipewire-session' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'PLASMA2=preserved-pipeline-171' 'PLASMA=third-stage-libraries-built-not-running' 'KWIN=not-built' 'PLASMA_WORKSPACE=not-built' 'PLASMA_DESKTOP=not-built' 'PIPEWIRE_SESSION=not-tested' 'PHONON_VLC=not-tested' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA3_BUILT=' "$ARTIFACTS/blfs-plasma3-progress.txt")" -eq 4 ]]
cat "$REPORT"
