#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma33-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA33_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma33-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/usr/bin/meson" \
  "$LFS/usr/bin/ninja" \
  "$LFS/usr/bin/pkg-config" \
  "$LFS/usr/bin/python3" \
  "$LFS/usr/bin/patch" \
  "$LFS/usr/bin/readelf"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
# Existing library dependencies are checked by pkg-config inside the chroot;
# do not guess their architecture-specific installation paths on the host.
for path in \
  "$LFS/usr/lib/libnspr4.so" \
  "$LFS/usr/lib/libplc4.so" \
  "$LFS/usr/lib/libplds4.so" \
  "$LFS/usr/lib/pkgconfig/nspr.pc" \
  "$LFS/usr/include/nspr" \
  "$LFS/usr/bin/nspr-config" \
  "$LFS/usr/lib/libnss3.so" \
  "$LFS/usr/lib/libssl3.so" \
  "$LFS/usr/lib/pkgconfig/nss.pc" \
  "$LFS/usr/include/nss" \
  "$LFS/usr/bin/certutil" \
  "$LFS/usr/bin/nss-config" \
  "$LFS/usr/bin/pk12util" \
  "$LFS/usr/lib/libndp.so" \
  "$LFS/usr/lib/pkgconfig/libndp.pc" \
  "$LFS/usr/bin/ndptool" \
  "$LFS/usr/lib/libnm.so" \
  "$LFS/usr/lib/pkgconfig/libnm.pc" \
  "$LFS/usr/include/libnm" \
  "$LFS/usr/sbin/NetworkManager" \
  "$LFS/usr/bin/nmcli" \
  "$LFS/usr/bin/nm-online"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in nspr-4.37.tar.gz nss-3.115.tar.gz nss-standalone-1.patch libndp-1.9.tar.gz NetworkManager-1.54.0.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA33_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma33-chroot.sh" "$LFS/root/build-blfs-plasma33-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma33-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress nspr-install-manifest nss-install-manifest nss-config networkmanager-config ndp-install-manifest networkmanager-install-manifest; do
  if sudo -n test -f "$LFS/root/blfs-plasma33-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma33-$name.txt" >"$ARTIFACTS/blfs-plasma33-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA33_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma33-chroot.sh" \
  "$LFS/root/blfs-plasma33-report.txt" "$LFS/root/blfs-plasma33-progress.txt" \
  "$LFS/root/blfs-plasma33-nspr-install-manifest.txt" \
  "$LFS/root/blfs-plasma33-nss-install-manifest.txt" \
  "$LFS/root/blfs-plasma33-nss-config.txt" \
  "$LFS/root/blfs-plasma33-networkmanager-config.txt" \
  "$LFS/root/blfs-plasma33-ndp-install-manifest.txt" \
  "$LFS/root/blfs-plasma33-networkmanager-install-manifest.txt"
REPORT="$ARTIFACTS/blfs-plasma33-report.txt"
for expected in \
  'BLFS_PLASMA33_RESULT=ok' 'PACKAGE_COUNT=4' 'SOURCE_COUNT=5' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-new-installed-tools-post-install' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'PACKAGES=NSPR,NSS,libndp,NetworkManager' 'NSPR=4.37' 'NSS=3.115' 'LIBNDP=1.9' 'NETWORKMANAGER=1.54.0' 'LIBNM=1.54.0' \
  'NSPR_TOOLS=installed-not-executed' 'NSS_USE_64=1' 'NSS_SYSTEM_ZLIB=1' 'NSS_DISABLE_GTESTS=1' 'NSS_TESTS=not-run-gtests-disabled' 'NSS_TOOLS=installed-not-executed' 'P11_KIT=not-reconfigured' \
  'NETWORKMANAGER_RUNTIME=not-started' 'NMCLI=installed-not-executed' 'NM_ONLINE=installed-not-executed' 'NDPTOOL=installed-not-executed' \
  'DBUS_SERVICES=installed-not-activated' 'UDEV_RULES=installed-not-reloaded' 'NETWORK_INTERFACES=not-accessed' 'LIVE_NETWORK_CONFIGURATION=not-changed' \
  'SESSION_TRACKING=no-logind' 'NMTUI=not-built-newt-absent' 'SYSTEMD_UNIT=not-installed' 'MODEM_MANAGER=false' 'PPP=false' 'OVS=false' 'NM_CLOUD_SETUP=false' 'NBFT=false' 'TEST_SUITES=not-run-disabled' \
  'OFFICIAL_PLASMA_ACTIVE=56' 'OFFICIAL_PLASMA_BUILDABLE_COVERED=54' 'OFFICIAL_PLASMA_DEFERRED=2' 'OFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order' \
  'DRKONQI=deferred-requires-systemd-journal-and-coredumpd' 'PLASMA_NM=deferred-awaiting-plasma34-build' 'PLASMA32=preserved-pipeline-223' \
  'NETWORK=not-used-by-built-programs' 'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA33_BUILT=' "$ARTIFACTS/blfs-plasma33-progress.txt")" -eq 4 ]]
grep -qx 'BLFS_PLASMA33_BUILT=NSPR-4.37' "$ARTIFACTS/blfs-plasma33-progress.txt"
grep -qx 'BLFS_PLASMA33_BUILT=NSS-3.115' "$ARTIFACTS/blfs-plasma33-progress.txt"
grep -qx 'BLFS_PLASMA33_BUILT=libndp-1.9' "$ARTIFACTS/blfs-plasma33-progress.txt"
grep -qx 'BLFS_PLASMA33_BUILT=NetworkManager-1.54.0' "$ARTIFACTS/blfs-plasma33-progress.txt"
NSS_CONFIG="$ARTIFACTS/blfs-plasma33-nss-config.txt"
for expected in 'NSPR_VERSION=4.37.0' 'NSS_VERSION=3.115.0' 'NSS_USE_64=1' 'NSS_SYSTEM_ZLIB=1' 'NSS_DISABLE_GTESTS=1' 'NSS_TESTS=not-run-gtests-disabled' 'NSS_TOOLS=installed-not-executed' 'P11_KIT=not-reconfigured'; do
  grep -qxF "$expected" "$NSS_CONFIG"
done
grep -qEx 'NSS_SYSTEM_SQLITE=[01]' "$NSS_CONFIG"
NM_CONFIG="$ARTIFACTS/blfs-plasma33-networkmanager-config.txt"
for expected in \
  'NETWORKMANAGER_VERSION=1.54.0' 'prefix=/usr' 'libdir=/usr/lib' 'buildtype=release' 'libaudit=no' 'nmtui=false' \
  'ovs=false' 'ppp=false' 'nbft=false' 'selinux=false' 'session_tracking=no' 'modem_manager=false' \
  'systemdsystemunitdir=no' 'systemd_journal=false' 'nm_cloud_setup=false' 'qt=false' 'tests=no' 'docs=false' \
  'crypto=nss' 'introspection=true' 'wifi=true' 'nmcli=true' 'concheck=true' 'libpsl=true' 'polkit=true' \
  'TEST_SUITES=not-run-disabled' 'NETWORKMANAGER_RUNTIME=not-started' 'NMCLI=installed-not-executed' \
  'NM_ONLINE=installed-not-executed' 'DBUS_SERVICES=installed-not-activated' 'UDEV_RULES=installed-not-reloaded' \
  'NETWORK_INTERFACES=not-accessed' 'LIVE_NETWORK_CONFIGURATION=not-changed'; do
  grep -qxF "$expected" "$NM_CONFIG"
done
NSPR_MANIFEST="$ARTIFACTS/blfs-plasma33-nspr-install-manifest.txt"
NSS_MANIFEST="$ARTIFACTS/blfs-plasma33-nss-install-manifest.txt"
NDP_MANIFEST="$ARTIFACTS/blfs-plasma33-ndp-install-manifest.txt"
NM_MANIFEST="$ARTIFACTS/blfs-plasma33-networkmanager-install-manifest.txt"
[[ -s "$NSPR_MANIFEST" && -s "$NSS_MANIFEST" && -s "$NDP_MANIFEST" && -s "$NM_MANIFEST" ]]
for path in /usr/lib/libnspr4.so /usr/lib/libplc4.so /usr/lib/libplds4.so /usr/lib/pkgconfig/nspr.pc /usr/include/nspr/prinit.h /usr/bin/nspr-config; do
  grep -qxF "$path" "$NSPR_MANIFEST"
done
for path in /usr/lib/libnss3.so /usr/lib/libssl3.so /usr/lib/libsmime3.so /usr/lib/libsoftokn3.so /usr/lib/libnssckbi.so /usr/lib/pkgconfig/nss.pc /usr/include/nss/nss.h /usr/bin/certutil /usr/bin/nss-config /usr/bin/pk12util; do
  grep -qxF "$path" "$NSS_MANIFEST"
done
for path in /usr/lib/libndp.so /usr/lib/pkgconfig/libndp.pc /usr/include/ndp.h /usr/bin/ndptool; do
  grep -qxF "$path" "$NDP_MANIFEST"
done
for path in /usr/lib/libnm.so /usr/lib/pkgconfig/libnm.pc /usr/sbin/NetworkManager /usr/bin/nmcli /usr/bin/nm-online; do
  grep -qxF "$path" "$NM_MANIFEST"
done
if grep -q '/nmtui' "$NM_MANIFEST"; then printf 'unexpected-nmtui\n' >&2; exit 1; fi
if grep -q '/systemd/.*NetworkManager' "$NM_MANIFEST"; then printf 'unexpected-systemd-unit\n' >&2; exit 1; fi
cat "$REPORT"
