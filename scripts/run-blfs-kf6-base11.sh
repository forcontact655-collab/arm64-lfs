#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base11-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base11-sources/sources ]]
for path in KF6Syndication KF6NewStuff KF6FrameworkIntegration KF6KIO KF6XmlGui; do
  [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
[[ -e "$LFS/usr/lib/libsecret-1.so" && -f "$LFS/usr/lib/pkgconfig/libsecret-1.pc" ]]
for path in KF6Parts KF6SyntaxHighlighting KF6TextEditor; do [[ ! -e "$LFS/opt/kf6/lib/cmake/$path" ]]; done
[[ ! -e "$LFS/opt/qt6/lib/cmake/Qt6TextToSpeech" ]]
[[ -x "$LFS/usr/bin/xfce4-terminal" && -f "$LFS/usr/lib/pkgconfig/libcanberra.pc" ]]
for name in kparts syntax-highlighting; do [[ -f "$HOST_SOURCES/$name-6.17.0.tar.xz" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base11-chroot.sh" "$LFS/root/build-blfs-kf6-base11-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base11-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base11-$name.txt" >"$ARTIFACTS/blfs-kf6-base11-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base11-chroot.sh" \
  "$LFS/root/blfs-kf6-base11-report.txt" "$LFS/root/blfs-kf6-base11-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base11-report.txt"
for expected in \
  'BLFS_KF6_BASE11_RESULT=ok' 'PACKAGE_COUNT=2' 'DEPENDENCY_COUNT=0' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE11_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'PACKAGES=kparts+syntax-highlighting' 'DEPENDENCIES=none' \
  'KPARTS=native-part-object-no-window' 'SYNTAX_HIGHLIGHTING=native-offline-cpp-highlight' \
  'KTEXTEDITOR=deferred-required-qtspeech-not-built' 'QT_TEXT_TO_SPEECH=absent-required-by-ktexteditor' \
  'NETWORK_RUNTIME=not-tested' 'WINDOW_RUNTIME=not-tested-no-window-shown' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'BASE10=preserved-pipeline-118' 'BASE9=preserved-pipeline-116' 'BASE8=preserved-pipeline-115' \
  'SECURITY_DEPS1=preserved-pipeline-109' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE11_BUILT=' "$ARTIFACTS/blfs-kf6-base11-progress.txt")" -eq 2 ]]
cat "$REPORT"
trap - EXIT
