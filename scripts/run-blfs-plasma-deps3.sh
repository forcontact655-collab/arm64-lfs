#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma-deps3-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() {
  printf 'BLFS_PLASMA_DEPS3_PRECONDITION_FAILED=%s\n' "$1" >&2
  exit 1
}
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma-deps3-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in "$LFS/usr/include/crack.h" "$LFS/usr/include/pwquality.h" "$LFS/usr/include/phonon4qt6" "$LFS/usr/include/pipewire-0.3"; do
  [[ ! -e "$path" ]] || preflight_fail "existing-$path"
done
for name in cracklib-2.10.3.tar.xz cracklib-words-2.10.3.xz libpwquality-1.4.5.tar.bz2 phonon-4.12.0.tar.xz pipewire-1.4.7.tar.bz2; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA_DEPS3_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma-deps3-chroot.sh" "$LFS/root/build-blfs-plasma-deps3-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma-deps3-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-plasma-deps3-$name.txt" >"$ARTIFACTS/blfs-plasma-deps3-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-plasma-deps3-chroot.sh" \
  "$LFS/root/blfs-plasma-deps3-report.txt" "$LFS/root/blfs-plasma-deps3-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma-deps3-report.txt"
for expected in \
  'BLFS_PLASMA_DEPS3_RESULT=ok' 'PACKAGE_COUNT=4' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=5' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS3_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA_DEPS3_EXEC_OK=crack=reject=pwq=generate=phonon=4.12.0=pipewire=1.4.7' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'CRACKLIB=2.10.3' 'CRACKLIB_WORDS=2.10.3' 'LIBPWQUALITY=1.4.5' 'PHONON=4.12.0' 'PIPEWIRE=1.4.7' 'PACKAGES=cracklib+libpwquality+phonon+pipewire' 'DEPENDENCIES=existing-qt6-kf6-pulseaudio-alsa-dbus' \
  'CRACKLIB_TESTS=make-test-passed' 'CRACKLIB_SMOKE=native-dictionary-weak-password-rejected' 'LIBPWQUALITY_TEST_SUITE=not-provided-by-upstream' 'LIBPWQUALITY_SMOKE=native-check-and-generate' 'LIBPWQUALITY_PYTHON=native-import' \
  'PHONON_TESTS=not-run-no-test-suite' 'PHONON_SMOKE=native-version-no-playback' 'PHONON_VLC_BACKEND=not-built-deferred' 'PIPEWIRE_TESTS=ninja-test-passed' 'PIPEWIRE_SMOKE=native-init-version-no-daemon' 'PIPEWIRE_SESSION_MANAGER=disabled-empty-list' 'PIPEWIRE_DAEMON=not-started' \
  'PLASMA_PULSE1=preserved-pipeline-153' 'PLASMA_DEPS2=preserved-pipeline-148' 'PLASMA_DEPS1=preserved-pipeline-147' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA_DEPS3_BUILT=' "$ARTIFACTS/blfs-plasma-deps3-progress.txt")" -eq 4 ]]
cat "$REPORT"
trap - EXIT
