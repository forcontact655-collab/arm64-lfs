#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma19-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA19_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma19-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/usr/include/sensors/sensors.h" \
  "$LFS/usr/lib/libsensors.so" \
  "$LFS/usr/include/libnl3/netlink/socket.h" \
  "$LFS/usr/lib/libnl-3.so" \
  "$LFS/usr/include/libudev.h" \
  "$LFS/usr/lib/libudev.so" \
  "$LFS/opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KirigamiPlatform/KF6KirigamiPlatformConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6ColorScheme/KF6ColorSchemeConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6IconThemes/KF6IconThemesConfig.cmake" \
  "$LFS/opt/kf6/bin/plasma-systemmonitor" \
  "$LFS/opt/kf6/bin/kde-print-queue"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/cmake/QQC2BreezeStyle/QQC2BreezeStyleConfig.cmake" \
  "$LFS/opt/kf6/lib/qml/org/kde/breeze/qmldir" \
  "$LFS/opt/kf6/lib/qml/org/kde/breeze/impl/qmldir" \
  "$LFS/opt/kf6/lib/plugins/kf6/kirigami/platform/org.kde.breeze.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kirigami/platform/liborg.kde.breeze.so" \
  "$LFS/opt/kf6/bin/ksystemstats" \
  "$LFS/opt/kf6/bin/kstatsviewer" \
  "$LFS/opt/kf6/libexec/ksystemstats_intel_helper" \
  "$LFS/opt/kf6/lib/plugins/ksystemstats" \
  "$LFS/opt/kf6/share/dbus-1/services/org.kde.ksystemstats1.service"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in qqc2-breeze-style-6.4.4.tar.xz ksystemstats-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA19_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma19-chroot.sh" "$LFS/root/build-blfs-plasma19-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma19-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress ksystemstats-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma19-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma19-$name.txt" >"$ARTIFACTS/blfs-plasma19-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA19_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma19-chroot.sh" \
  "$LFS/root/blfs-plasma19-report.txt" "$LFS/root/blfs-plasma19-progress.txt" \
  "$LFS/root/blfs-plasma19-ksystemstats-config.txt"
REPORT="$ARTIFACTS/blfs-plasma19-report.txt"
for expected in \
  'BLFS_PLASMA19_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-ksystemstats-kstatsviewer-or-gpu-helper' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' 'PACKAGES=qqc2-breeze-style+ksystemstats' \
  'QQC2_BREEZE_STYLE=6.4.4' 'QQC2_STYLE_QML=installed-not-loaded' 'QQC2_QML_PLUGIN_COUNT=2' 'KIRIGAMI_BREEZE_PLUGIN=installed-not-loaded' 'QQC2_STYLE_UI=not-opened' \
  'KSYSTEMSTATS=6.4.4' 'KSYSTEMSTATS_DAEMON=installed-not-executed' 'KSTATSVIEWER=installed-not-executed' 'KSYSTEMSTATS_DBUS_SERVICE=installed-not-activated' \
  'KSYSTEMSTATS_PLUGIN_COUNT=9' 'SENSOR_PLUGINS=installed-not-loaded' 'GPU_PLUGIN=installed-not-loaded' \
  'GPU_HELPER=installed-not-executed-capability-not-set' 'LIBCAP_FIND_PACKAGE=disabled' 'CAP_PERFMON=not-set' \
  'SENSORS=not-queried' 'NETWORK_STATS=not-queried' 'HARDWARE_GPU=not-accessed' 'PROCESSES=not-listed-or-signalled' \
  'SYSTEMMONITOR=preserved-pipeline-206-not-opened' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' 'TEST_SUITES=not-run' \
  'PLASMA18=preserved-pipeline-206' 'PLASMA17=preserved-pipeline-204' 'PLASMA16=preserved-pipeline-201' 'SDDM=preserved-not-started' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'KDED=not-started' \
  'NETWORK=not-used-by-built-programs' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA19_BUILT=' "$ARTIFACTS/blfs-plasma19-progress.txt")" -eq 2 ]]
grep -Eq '^CMAKE_DISABLE_FIND_PACKAGE_Libcap(:[^=]+)?=TRUE$' "$ARTIFACTS/blfs-plasma19-ksystemstats-config.txt"
grep -Eq '^SENSORS_LIBRARIES(:[^=]+)?=/usr/lib/libsensors\.so$' "$ARTIFACTS/blfs-plasma19-ksystemstats-config.txt"
for expected in GPU_PLUGIN=enabled-build-graph GPU_HELPER=enabled-build-graph LMSENSORS_PLUGIN=enabled-build-graph CAPABILITY_INSTALL=disabled; do
  grep -qx "$expected" "$ARTIFACTS/blfs-plasma19-ksystemstats-config.txt"
done
cat "$REPORT"
