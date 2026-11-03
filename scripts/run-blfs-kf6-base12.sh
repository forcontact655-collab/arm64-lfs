#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base12-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base12-sources/sources ]]
for path in Qt6TextToSpeech Qt6PrintSupport Qt6Qml; do [[ -f "$LFS/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Parts KF6SyntaxHighlighting KF6Auth KF6Sonnet KF6KIO; do [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e "$LFS/opt/kf6/lib/cmake/KF6TextEditor" ]]
[[ -f "$HOST_SOURCES/ktexteditor-6.17.0.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base12-chroot.sh" "$LFS/root/build-blfs-kf6-base12-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base12-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base12-$name.txt" >"$ARTIFACTS/blfs-kf6-base12-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base12-chroot.sh" \
  "$LFS/root/blfs-kf6-base12-report.txt" "$LFS/root/blfs-kf6-base12-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base12-report.txt"
for expected in \
  'BLFS_KF6_BASE12_RESULT=ok' 'PACKAGE_COUNT=1' 'DEPENDENCY_COUNT=0' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE12_EXEC_OK' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'PACKAGES=ktexteditor' 'DEPENDENCIES=qt-media-speech1-preserved' \
  'KTEXTEDITOR=native-document-view-no-window' 'HIGHLIGHTING=cpp-mode-set' 'TEXT_TO_SPEECH=linked-not-spoken' \
  'AUDIO_RUNTIME=not-tested-no-device-access' 'SPEECH_RUNTIME=not-tested-no-say-call' 'WINDOW_RUNTIME=not-tested-no-window-shown' \
  'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'QT_MEDIA_SPEECH1=preserved-pipeline-120' 'BASE11=preserved-pipeline-119' \
  'BASE10=preserved-pipeline-118' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE12_BUILT=' "$ARTIFACTS/blfs-kf6-base12-progress.txt")" -eq 1 ]]
cat "$REPORT"
trap - EXIT
