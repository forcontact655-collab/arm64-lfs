#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma-deps4-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() {
  printf 'BLFS_PLASMA_DEPS4_PRECONDITION_FAILED=%s\n' "$1" >&2
  exit 1
}
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma-deps4-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in "$LFS/usr/include/archive.h" "$LFS/usr/include/libavcodec/avcodec.h" "$LFS/usr/include/opencv4/opencv2/core.hpp" "$LFS/usr/include/mtdev.h" "$LFS/usr/include/libevdev-1.0/libevdev/libevdev.h" "$LFS/usr/lib/xorg/modules/input/evdev_drv.so"; do
  [[ ! -e "$path" ]] || preflight_fail "existing-$path"
done
for path in "$LFS/usr/bin/Xorg" "$LFS/usr/bin/cvt" "$LFS/usr/bin/di-edid-decode" "$LFS/usr/share/hwdata/pci.ids"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for name in libarchive-3.8.1.tar.xz ffmpeg-7.1.1.tar.xz ffmpeg-7.1.1-chromium_method-1.patch opencv-4.12.0.tar.gz mtdev-1.1.7.tar.bz2 libevdev-1.13.4.tar.xz xf86-input-evdev-2.11.0.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA_DEPS4_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma-deps4-chroot.sh" "$LFS/root/build-blfs-plasma-deps4-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma-deps4-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-plasma-deps4-$name.txt" >"$ARTIFACTS/blfs-plasma-deps4-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-plasma-deps4-chroot.sh" \
  "$LFS/root/blfs-plasma-deps4-report.txt" "$LFS/root/blfs-plasma-deps4-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma-deps4-report.txt"
for expected in \
  'BLFS_PLASMA_DEPS4_RESULT=ok' 'PACKAGE_COUNT=6' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=7' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS4_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA_DEPS4_EXEC_OK=archive=3.8.1=ffmpeg=7.1.1=opencv=4.12.0=ffmpeg-backend=edid=1.4=evdev=library' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'LIBARCHIVE=3.8.1' 'FFMPEG=7.1.1' 'OPENCV=4.12.0' 'MTDEV=1.1.7' 'LIBEVDEV=1.13.4' 'XORG_EVDEV=2.11.0' 'LIBDISPLAY_INFO=0.3.0-existing' 'LIBXCVT=0.1.3-existing' \
  'PACKAGES=libarchive+ffmpeg+opencv+mtdev+libevdev+xf86-input-evdev' 'DEPENDENCIES=existing-hwdata-libdisplay-info-libxcvt-xorg-server' \
  'LIBARCHIVE_TEST_SUITE=make-check-passed' 'LIBARCHIVE_SMOKE=native-init-version' \
  'FFMPEG_TEST_SUITE=not-run-FATE-not-downloaded' 'FFMPEG_SMOKE=native-ffv1-encode+ffprobe' 'FFMPEG_CONFIGURE=shared-gpl-version3-freetype-vorbis-pulse-openssl' 'FFMPEG_FFPLAY=disabled' 'FFMPEG_NONFREE=disabled' \
  'OPENCV_TEST_SUITE=not-run-BUILD_TESTS_OFF' 'OPENCV_SMOKE=native-matrix+ffmpeg-backend-no-device' 'OPENCV_IPP=disabled-aarch64-no-download' 'OPENCV_CONTRIB=not-built-optional' 'OPENCV_XINE=disabled-not-installed' 'OPENCV_GSTREAMER=disabled-not-installed' 'OPENCV_PYTHON=disabled-not-required' \
  'MTDEV_TEST_SUITE=not-provided' 'MTDEV_SMOKE=native-new-delete' 'LIBEVDEV_TEST_SUITE=disabled-check-not-installed' 'LIBEVDEV_SMOKE=native-name-roundtrip' 'XORG_EVDEV_TEST_SUITE=not-provided' 'XORG_EVDEV_DRIVER=installed-not-loaded-no-input-device' \
  'EXISTING_DISPLAY_INFO=native-edid-verified' 'EXISTING_LIBXCVT=native-cvt-modeline-verified' \
  'PLASMA_DEPS3=preserved-pipeline-154' 'PLASMA_PULSE1=preserved-pipeline-153' 'PLASMA_DEPS2=preserved-pipeline-148' 'PLASMA_DEPS1=preserved-pipeline-147' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA_DEPS4_BUILT=' "$ARTIFACTS/blfs-plasma-deps4-progress.txt")" -eq 6 ]]
cat "$REPORT"
trap - EXIT
