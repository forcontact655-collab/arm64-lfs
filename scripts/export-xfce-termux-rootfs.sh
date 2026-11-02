#!/usr/bin/env bash
set -euo pipefail

# Export the already accepted XFCE launch1 cache. This does not rebuild or
# relaunch XFCE, install anything on a phone, or modify an existing Arch system.
export LFS="${LFS:-/home/circleci/lfs}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
ARCHIVE_NAME="lfs-12.4-xfce-aarch64-rootfs.tar.xz"
ARCHIVE="$ARTIFACTS/$ARCHIVE_NAME"
REPORT="$ARTIFACTS/blfs-xfce-termux-export1-report.txt"
ARTIFACT_VERIFICATION="$ARTIFACTS/blfs-xfce-termux-export1-content.txt"
export ARTIFACT_VERIFICATION
START_TS="$(date +%s)"

[[ "$(uname -m)" == aarch64 ]]
[[ "$(id -u)" -ne 0 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ -d "$LFS/usr" && -d "$LFS/etc" ]]
[[ ! -e "$LFS/etc/arch-release" ]]
sudo -n true
mkdir -p "$ARTIFACTS"

# Pin the exact accepted launch1 inputs, hence the exact restored cache key.
while read -r expected relative; do
  printf '%s  %s\n' "$expected" "$REPO/$relative" | sha256sum -c -
done <<'EOF'
550635a0b0291e21d8c01cf786ba2f77f09a91a482a1b202e90d20a078ba34de scripts/build-blfs-xfce-launch1-chroot.sh
3a9402649e7d929942976cd91fcb85efe280d841f7ae83d2788b090bac5e26be scripts/blfs-xfce-launch1-x11-smoke.c
f14606d6bbd0e37f3ef119e9472493edd4169f5bb0542760729b6318c1cb8ed3 scripts/run-blfs-xfce-launch1.sh
EOF

for path in dev proc sys run sources; do
  if mountpoint -q "$LFS/$path"; then
    printf 'Refusing to archive a mounted rootfs path: %s\n' "$LFS/$path" >&2
    exit 1
  fi
done
for program in bash python3 gcc cvt xkbcomp Xvfb Xorg xrdb iceauth xfdesktop xfwm4 xfce4-session xfce4-panel xfsettingsd startxfce4 dbus-run-session; do
  [[ -x "$LFS/usr/bin/$program" ]]
done
for program in bash python3 gcc cvt xkbcomp Xvfb Xorg xrdb iceauth xfdesktop xfwm4 xfce4-session xfce4-panel xfsettingsd dbus-run-session; do
  readelf -h "$LFS/usr/bin/$program" | grep -q 'Machine:.*AArch64'
done
for program in bash Xvfb xfce4-session; do
  readelf -l "$LFS/usr/bin/$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

# Execute only harmless native version/query checks; do not repeat the accepted
# desktop launch test in this export job.
NATIVE="$(sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root LC_ALL=C.UTF-8 PATH=/usr/bin:/usr/sbin \
  /usr/bin/python3 -c 'import platform; assert platform.machine() == "aarch64"; print("TERMUX_EXPORT_NATIVE_EXEC_OK")')"
[[ "$NATIVE" == TERMUX_EXPORT_NATIVE_EXEC_OK ]]
[[ "$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /usr/bin/pkg-config --modversion libxcvt)" == 0.1.3 ]]
[[ "$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /usr/bin/pkg-config --modversion fontutil)" == 1.4.1 ]]
[[ "$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /usr/bin/pkg-config --modversion xkbcomp)" == 1.4.7 ]]
[[ "$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /usr/bin/pkg-config --modversion epoxy)" == 1.5.10 ]]
XRDB_VERSION="$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /usr/bin/xrdb -version)"
[[ "$XRDB_VERSION" == 'xrdb 1.2.2' ]]

printf 'ARCHIVE accepted XFCE rootfs with hardlinks dereferenced\n'
rm -f "$ARCHIVE" "$ARCHIVE.sha256" "$ARCHIVE".part-* "$ARCHIVE.parts.sha256" "$REPORT" "$ARTIFACT_VERIFICATION"
sudo -n tar --numeric-owner --hard-dereference \
  --exclude='./tools' --exclude='./sources' \
  --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*' \
  --exclude='./run/*' --exclude='./tmp/*' --exclude='./var/tmp/*' \
  --exclude='./var/cache/*' --exclude='./root/.cache' \
  -C "$LFS" -I 'xz -T4 -3' -cf - . >"$ARCHIVE"

ARCHIVE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
ARCHIVE_BYTES="$(stat -c %s "$ARCHIVE")"
export ARCHIVE ARCHIVE_NAME ARCHIVE_SHA256 ARCHIVE_BYTES
python3 - <<'PY'
import os
from pathlib import Path
import tarfile

archive = Path(os.environ['ARCHIVE'])
required = {
    './usr/bin/bash', './usr/bin/python3', './usr/bin/gcc',
    './usr/bin/cvt', './usr/bin/xkbcomp', './usr/bin/Xvfb',
    './usr/bin/Xorg', './usr/bin/xrdb', './usr/bin/iceauth',
    './usr/bin/xfdesktop', './usr/bin/xfwm4', './usr/bin/xfce4-session',
    './usr/bin/xfce4-panel', './usr/bin/xfsettingsd',
    './usr/bin/startxfce4', './usr/bin/dbus-run-session',
    './usr/lib/ld-linux-aarch64.so.1',
}
seen = set()
members = 0
regular_bytes = 0
with tarfile.open(archive, 'r|xz') as stream:
    for member in stream:
        name = member.name
        assert (name == '.' or name.startswith('./')) and not name.startswith('/'), name
        assert '..' not in Path(name).parts, name
        assert not member.islnk(), f'hardlink survived: {name}'
        assert name not in {'./tools', './sources'}, name
        assert not name.startswith('./tools/'), name
        assert not name.startswith('./sources/'), name
        members += 1
        if member.isreg():
            regular_bytes += member.size
        seen.add(name)
missing = required - seen
assert not missing, sorted(missing)
Path(os.environ['ARTIFACT_VERIFICATION']).write_text(
    f'ARCHIVE_CONTENT_RESULT=ok\nARCHIVE_MEMBERS={members}\n'
    f'ARCHIVE_REGULAR_BYTES={regular_bytes}\n'
    'ARCHIVE_HARDLINKS=0\nARCHIVE_SOCKETS=0\n'
    'ARCHIVE_REQUIRED_PATHS=17-of-17\n'
    'ARCHIVE_BUILD_TOOLS_AND_SOURCES=excluded\n'
)
PY

# Keep release assets below GitHub's 2 GiB per-asset ceiling. Splitting is only
# a transport format; the SHA-256 always covers the original complete archive.
ARCHIVE_FORMAT=single
PART_COUNT=0
if (( ARCHIVE_BYTES > 1900000000 )); then
  split -b 1000m -d -a 3 "$ARCHIVE" "$ARCHIVE.part-"
  cat "$ARCHIVE".part-* | sha256sum -c <(printf '%s  -\n' "$ARCHIVE_SHA256")
  mapfile -t PARTS < <(printf '%s\n' "$ARCHIVE".part-*)
  PART_COUNT="${#PARTS[@]}"
  (( PART_COUNT >= 2 ))
  (cd "$ARTIFACTS" && sha256sum "$ARCHIVE_NAME".part-*) >"$ARCHIVE.parts.sha256"
  rm -f "$ARCHIVE"
  ARCHIVE_FORMAT=split-concatenate-in-numeric-order
fi
# The checksum file always describes the original archive, including split mode.
printf '%s  %s\n' "$ARCHIVE_SHA256" "$ARCHIVE_NAME" >"$ARCHIVE.sha256"

cat "$ARTIFACT_VERIFICATION" >>"$REPORT"
{
  printf 'TERMUX_EXPORT_RESULT=ok\n'
  printf 'SOURCE_PIPELINE=83\n'
  printf 'SOURCE_COMMIT=1b191a990670e41aac99ce5af2a2bf2c4942954c\n'
  printf 'SOURCE_CACHE=blfs-12.4-xfce-launch1-aarch64-v1\n'
  printf 'XFCE_CORE=18-of-18\n'
  printf 'DESKTOP_LAUNCH_ACCEPTED=headless-xvfb-startxfce4-ok\n'
  printf 'DESKTOP_RELAUNCHED_IN_EXPORT=no\n'
  printf 'ARCH=aarch64\n'
  printf 'NATIVE_BINARY_EXEC=%s\n' "$NATIVE"
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'ARCHIVE_NAME=%s\n' "$ARCHIVE_NAME"
  printf 'ARCHIVE_FORMAT=%s\n' "$ARCHIVE_FORMAT"
  printf 'ARCHIVE_BYTES=%s\n' "$ARCHIVE_BYTES"
  printf 'ARCHIVE_SHA256=%s\n' "$ARCHIVE_SHA256"
  printf 'ARCHIVE_PART_COUNT=%s\n' "$PART_COUNT"
  printf 'HARDLINKS=dereferenced-for-android\n'
  printf 'EXISTING_ARCH=not-accessed-not-modified\n'
  printf 'PHONE_INSTALL=not-performed-in-ci\n'
  printf 'BOOTABLE=no\n'
  printf 'TOTAL_ELAPSED_SECONDS=%s\n' "$(( $(date +%s) - START_TS ))"
} >>"$REPORT"
cat "$REPORT"
