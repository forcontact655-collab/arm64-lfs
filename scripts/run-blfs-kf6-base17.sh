#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base17-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base17-sources/sources ]]
for path in Qt6Qml Qt6Quick Qt6QuickControls2 Qt6ShaderTools Qt6Network Qt6Test; do [[ -f "$LFS/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Prison KF6Baloo KF6KirigamiPlatform KF6Notifications KF6KIO; do [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6QQC2DesktopStyle KF6Holidays KF6Purpose KF6QuickCharts KF6CalendarCore; do [[ ! -e "$LFS/opt/kf6/lib/cmake/$path" ]]; done
for name in qqc2-desktop-style kholidays purpose kquickcharts; do [[ -f "$HOST_SOURCES/$name-6.17.0.tar.xz" ]]; done
mkdir -p "$ARTIFACTS"
sudo -n true
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base17-chroot.sh" "$LFS/root/build-blfs-kf6-base17-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base17-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base17-$name.txt" >"$ARTIFACTS/blfs-kf6-base17-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base17-chroot.sh" \
  "$LFS/root/blfs-kf6-base17-report.txt" "$LFS/root/blfs-kf6-base17-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base17-report.txt"
for expected in \
  'BLFS_KF6_BASE17_RESULT=ok' 'PACKAGE_COUNT=4' 'DEPENDENCY_COUNT=0' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE17_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'PACKAGES=qqc2-desktop-style+kholidays+purpose+kquickcharts' 'DEPENDENCIES=none' \
  'QQC2=native-qml-desktop-import' 'KHOLIDAYS=native-us-holiday' 'PURPOSE=native-alternatives-model-no-start' 'QUICKCHARTS=qml-barchart-unshown' \
  'SPIRV_OPT=absent-qsb-fallback' 'KCALENDARCORE=deferred-libical-required' 'NETWORK_RUNTIME=not-tested-no-job-start' 'WINDOW_RUNTIME=not-tested-no-window-shown' \
  'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'BASE16=preserved-pipeline-129' 'BASE15=preserved-pipeline-128' 'BASE14=preserved-pipeline-126' \
  'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE17_BUILT=' "$ARTIFACTS/blfs-kf6-base17-progress.txt")" -eq 4 ]]
cat "$REPORT"
trap - EXIT
