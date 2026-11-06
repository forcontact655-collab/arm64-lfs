#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma33-report.txt
PROGRESS=/root/blfs-plasma33-progress.txt
NSPR_MANIFEST=/root/blfs-plasma33-nspr-install-manifest.txt
NSS_MANIFEST=/root/blfs-plasma33-nss-install-manifest.txt
NSS_CONFIG=/root/blfs-plasma33-nss-config.txt
NM_CONFIG=/root/blfs-plasma33-networkmanager-config.txt
NDP_MANIFEST=/root/blfs-plasma33-ndp-install-manifest.txt
NM_MANIFEST=/root/blfs-plasma33-networkmanager-install-manifest.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/gcc && -x /usr/bin/g++ && -x /usr/bin/meson && -x /usr/bin/ninja && -x /usr/bin/python3 && -x /usr/bin/patch && -x /usr/bin/readelf && -x /usr/bin/pkg-config ]]
pkg-config --exists uuid 'libudev >= 175' 'dbus-1 >= 1.1' 'gio-unix-2.0 >= 2.42' gmodule-2.0 libnl-3.0 libnl-route-3.0 'libpsl >= 0.1' 'libcurl >= 7.24.0' zlib gobject-introspection-1.0
[[ "$(pkg-config --modversion libnl-3.0)" == 3.11.0 ]]
[[ "$(pkg-config --modversion libpsl)" == 0.21.5 ]]
if pkg-config --exists nspr || pkg-config --exists nss || pkg-config --exists libndp || pkg-config --exists libnm; then
  printf 'unexpected-existing-networkmanager-dependency\n' >&2
  exit 1
fi
for path in \
  /usr/lib/libnspr4.so \
  /usr/lib/libplc4.so \
  /usr/lib/libplds4.so \
  /usr/lib/pkgconfig/nspr.pc \
  /usr/include/nspr \
  /usr/bin/nspr-config \
  /usr/lib/libnss3.so \
  /usr/lib/libssl3.so \
  /usr/lib/pkgconfig/nss.pc \
  /usr/include/nss \
  /usr/bin/certutil \
  /usr/bin/nss-config \
  /usr/bin/pk12util \
  /usr/lib/libndp.so \
  /usr/lib/pkgconfig/libndp.pc \
  /usr/bin/ndptool \
  /usr/lib/libnm.so \
  /usr/lib/pkgconfig/libnm.pc \
  /usr/include/libnm \
  /usr/sbin/NetworkManager \
  /usr/bin/nmcli \
  /usr/bin/nm-online; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
EXTRACTED_DIR=''
extract_package() {
  local archive="$1" expected="$2" first
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  EXTRACTED_DIR="${first%%/*}"
  EXTRACTED_DIR="${EXTRACTED_DIR#./}"
  [[ "$EXTRACTED_DIR" == "$expected" ]]
  rm -rf "$SOURCES/$EXTRACTED_DIR"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$EXTRACTED_DIR"
}
remove_package() {
  cd /sources
  rm -rf "$EXTRACTED_DIR"
}
snapshot_tree() {
  find /etc /usr /var -xdev \( -type f -o -type l \) -print | sort
}

# Build NSPR and NSS so NetworkManager keeps its real NSS crypto backend.
snapshot_tree >/tmp/blfs-plasma33-before-nspr.txt
extract_package nspr-4.37.tar.gz nspr-4.37
printf 'BUILD_BLFS_PLASMA33=NSPR\n'
cd nspr
sed -i '/^RELEASE/s|^|#|' pr/src/misc/Makefile.in
sed -i 's|$(LIBRARY) ||' config/rules.mk
./configure --prefix=/usr --with-mozilla --with-pthreads
make -j2
make install
remove_package
snapshot_tree >/tmp/blfs-plasma33-after-nspr.txt
comm -13 /tmp/blfs-plasma33-before-nspr.txt /tmp/blfs-plasma33-after-nspr.txt >"$NSPR_MANIFEST"
rm -f /tmp/blfs-plasma33-before-nspr.txt /tmp/blfs-plasma33-after-nspr.txt
[[ -s "$NSPR_MANIFEST" ]]
for path in /usr/lib/libnspr4.so /usr/lib/libplc4.so /usr/lib/libplds4.so /usr/lib/pkgconfig/nspr.pc /usr/include/nspr/prinit.h /usr/bin/nspr-config; do
  grep -qxF "$path" "$NSPR_MANIFEST"
done
[[ "$(pkg-config --modversion nspr)" == 4.37.0 ]]
printf 'BLFS_PLASMA33_BUILT=NSPR-4.37\n' >>"$PROGRESS"

snapshot_tree >/tmp/blfs-plasma33-before-nss.txt
extract_package nss-3.115.tar.gz nss-3.115
printf 'BUILD_BLFS_PLASMA33=NSS\n'
patch -Np1 -i ../nss-standalone-1.patch
cd nss
NSS_SQLITE=()
if [[ -f /usr/include/sqlite3.h ]]; then NSS_SQLITE=(NSS_USE_SYSTEM_SQLITE=1); fi
make -j2 BUILD_OPT=1 \
  NSPR_INCLUDE_DIR=/usr/include/nspr \
  USE_SYSTEM_ZLIB=1 \
  ZLIB_LIBS=-lz \
  NSS_ENABLE_WERROR=0 \
  NSS_DISABLE_GTESTS=1 \
  "${NSS_SQLITE[@]}"
cd ../dist
install -v -m755 Linux*/lib/*.so /usr/lib
install -v -m644 Linux*/lib/{*.chk,libcrmf.a} /usr/lib
install -v -m755 -d /usr/include/nss
cp -v -RL {public,private}/nss/* /usr/include/nss
install -v -m755 Linux*/bin/{certutil,nss-config,pk12util} /usr/bin
install -v -m644 Linux*/lib/pkgconfig/nss.pc /usr/lib/pkgconfig
remove_package
snapshot_tree >/tmp/blfs-plasma33-after-nss.txt
comm -13 /tmp/blfs-plasma33-before-nss.txt /tmp/blfs-plasma33-after-nss.txt >"$NSS_MANIFEST"
rm -f /tmp/blfs-plasma33-before-nss.txt /tmp/blfs-plasma33-after-nss.txt
[[ -s "$NSS_MANIFEST" ]]
for path in /usr/lib/libnss3.so /usr/lib/libssl3.so /usr/lib/libsmime3.so /usr/lib/libsoftokn3.so /usr/lib/libnssckbi.so /usr/lib/pkgconfig/nss.pc /usr/include/nss/nss.h /usr/bin/certutil /usr/bin/nss-config /usr/bin/pk12util; do
  grep -qxF "$path" "$NSS_MANIFEST"
done
[[ "$(pkg-config --modversion nss)" == 3.115.0 ]]
{
  printf 'NSPR_VERSION=%s\nNSS_VERSION=%s\n' "$(pkg-config --modversion nspr)" "$(pkg-config --modversion nss)"
  printf 'NSS_SYSTEM_ZLIB=1\nNSS_DISABLE_GTESTS=1\nNSS_TESTS=not-run-gtests-disabled\nNSS_TOOLS=installed-not-executed\nP11_KIT=not-reconfigured\n'
  if [[ -f /usr/include/sqlite3.h ]]; then printf 'NSS_SYSTEM_SQLITE=1\n'; else printf 'NSS_SYSTEM_SQLITE=0\n'; fi
} >"$NSS_CONFIG"
printf 'BLFS_PLASMA33_BUILT=NSS-3.115\n' >>"$PROGRESS"

# libndp is NetworkManager's genuine required IPv6 neighbor-discovery library.
snapshot_tree >/tmp/blfs-plasma33-before-ndp.txt
extract_package libndp-1.9.tar.gz libndp-1.9
printf 'BUILD_BLFS_PLASMA33=libndp\n'
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make -j2
make install
remove_package
snapshot_tree >/tmp/blfs-plasma33-after-ndp.txt
comm -13 /tmp/blfs-plasma33-before-ndp.txt /tmp/blfs-plasma33-after-ndp.txt >"$NDP_MANIFEST"
rm -f /tmp/blfs-plasma33-before-ndp.txt /tmp/blfs-plasma33-after-ndp.txt
[[ -s "$NDP_MANIFEST" ]]
for path in /usr/lib/libndp.so /usr/lib/pkgconfig/libndp.pc /usr/include/ndp.h /usr/bin/ndptool; do
  grep -qxF "$path" "$NDP_MANIFEST"
done
[[ "$(pkg-config --modversion libndp)" == 1.9 ]]
[[ ! -e /usr/lib/libndp.a ]]
printf 'BLFS_PLASMA33_BUILT=libndp-1.9\n' >>"$PROGRESS"

# Build the real daemon and libnm. This follows BLFS's sysv options, with the
# upstream no-logind session backend and without nmtui because newt is absent.
# No daemon, client tool, D-Bus service, udev rule or network interface is run.
snapshot_tree >/tmp/blfs-plasma33-before-networkmanager.txt
extract_package NetworkManager-1.54.0.tar.xz NetworkManager-1.54.0
printf 'BUILD_BLFS_PLASMA33=NetworkManager\n'
while IFS= read -r file; do sed -i '1s/python/&3/' "$file"; done < <(grep -rl '^#!.*python$' . || true)
mkdir build
cd build
meson setup .. \
  --prefix=/usr \
  --buildtype=release \
  -Dlibaudit=no \
  -Dnmtui=false \
  -Dovs=false \
  -Dppp=false \
  -Dnbft=false \
  -Dselinux=false \
  -Dsession_tracking=no \
  -Dmodem_manager=false \
  -Dsystemdsystemunitdir=no \
  -Dsystemd_journal=false \
  -Dnm_cloud_setup=false \
  -Dqt=false \
  -Dtests=no \
  -Ddocs=false
python3 - "$NM_CONFIG" <<'PY'
import json,sys
from pathlib import Path
options={row['name']:row['value'] for row in json.loads(Path('meson-info/intro-buildoptions.json').read_text())}
project=json.loads(Path('meson-info/intro-projectinfo.json').read_text())
assert project['version']=='1.54.0',project
expected={
 'prefix':'/usr','buildtype':'release','libaudit':'no','nmtui':False,
 'ovs':False,'ppp':False,'nbft':False,'selinux':False,
 'session_tracking':'no','modem_manager':False,'systemdsystemunitdir':'no',
 'systemd_journal':False,'nm_cloud_setup':False,'qt':'false','tests':'no',
 'docs':False,'crypto':'nss','introspection':True,'wifi':True,
 'nmcli':True,'concheck':True,'libpsl':True,'polkit':True,
}
for name,value in expected.items():
 assert options.get(name)==value,(name,options.get(name),value)
def norm(value):
 return str(value).lower() if isinstance(value,bool) else str(value)
lines=['NETWORKMANAGER_VERSION='+project['version']]
lines += [name+'='+norm(options[name]) for name in sorted(expected)]
lines += [
 'TEST_SUITES=not-run-disabled','NETWORKMANAGER_RUNTIME=not-started',
 'NMCLI=installed-not-executed','NM_ONLINE=installed-not-executed',
 'DBUS_SERVICES=installed-not-activated','UDEV_RULES=installed-not-reloaded',
 'NETWORK_INTERFACES=not-accessed','LIVE_NETWORK_CONFIGURATION=not-changed',
]
Path(sys.argv[1]).write_text('\n'.join(lines)+'\n')
PY
ninja -j2
ninja install
if [[ -d /usr/share/doc/NetworkManager ]]; then
  [[ ! -e /usr/share/doc/NetworkManager-1.54.0 ]]
  mv -v /usr/share/doc/NetworkManager /usr/share/doc/NetworkManager-1.54.0
fi
cd /sources
rm -rf NetworkManager-1.54.0
snapshot_tree >/tmp/blfs-plasma33-after-networkmanager.txt
comm -13 /tmp/blfs-plasma33-before-networkmanager.txt /tmp/blfs-plasma33-after-networkmanager.txt >"$NM_MANIFEST"
rm -f /tmp/blfs-plasma33-before-networkmanager.txt /tmp/blfs-plasma33-after-networkmanager.txt
[[ -s "$NM_MANIFEST" ]]
for path in \
  /usr/lib/libnm.so \
  /usr/lib/pkgconfig/libnm.pc \
  /usr/sbin/NetworkManager \
  /usr/bin/nmcli \
  /usr/bin/nm-online; do
  grep -qxF "$path" "$NM_MANIFEST"
done
[[ "$(pkg-config --modversion libnm)" == 1.54.0 ]]
[[ ! -e /usr/bin/nmtui ]]
[[ ! -e /usr/lib/systemd/system/NetworkManager.service && ! -e /lib/systemd/system/NetworkManager.service ]]
if grep -q '/systemd/.*NetworkManager' "$NM_MANIFEST"; then
  printf 'unexpected-networkmanager-systemd-unit\n' >&2
  exit 1
fi
printf 'BLFS_PLASMA33_BUILT=NetworkManager-1.54.0\n' >>"$PROGRESS"

/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA33_BUILT=' "$PROGRESS")" -eq 4 ]]
NSPR_ELF=(/usr/lib/libnspr4.so /usr/lib/libplc4.so /usr/lib/libplds4.so)
NSS_ELF=(/usr/lib/libnss3.so /usr/lib/libssl3.so /usr/lib/libsmime3.so /usr/lib/libsoftokn3.so /usr/lib/libnssckbi.so /usr/bin/certutil /usr/bin/pk12util)
NDP_ELF=(/usr/lib/libndp.so /usr/bin/ndptool)
NM_ELF=(/usr/lib/libnm.so /usr/sbin/NetworkManager /usr/bin/nmcli /usr/bin/nm-online)
for path in "${NSPR_ELF[@]}"; do grep -qxF "$path" "$NSPR_MANIFEST"; done
for path in "${NSS_ELF[@]}"; do grep -qxF "$path" "$NSS_MANIFEST"; done
for path in "${NDP_ELF[@]}"; do grep -qxF "$path" "$NDP_MANIFEST"; done
for path in "${NM_ELF[@]}"; do grep -qxF "$path" "$NM_MANIFEST"; done
for path in "${NSPR_ELF[@]}" "${NSS_ELF[@]}" "${NDP_ELF[@]}" "${NM_ELF[@]}"; do
  [[ -f "$path" ]]
  readelf -h "$path" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l /usr/sbin/NetworkManager | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
ELF_COUNT=0
ELF_HEADER=/tmp/blfs-plasma33-elf-header.txt
for manifest in "$NSPR_MANIFEST" "$NSS_MANIFEST" "$NDP_MANIFEST" "$NM_MANIFEST"; do
  while IFS= read -r path; do
    [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]
    case "$path" in
      /usr/*|/etc/*|/var/*) ;;
      *) printf 'unexpected-install-path=%s:%s\n' "$manifest" "$path" >&2; exit 1 ;;
    esac
    if readelf -h "$path" >"$ELF_HEADER" 2>/dev/null; then
      grep -q 'Machine:.*AArch64' "$ELF_HEADER"
      ELF_COUNT=$((ELF_COUNT + 1))
      ELF_INTERPRETER="$(readelf -l "$path" 2>/dev/null | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
      if [[ -n "$ELF_INTERPRETER" ]]; then [[ "$ELF_INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]; fi
    fi
  done <"$manifest"
done
rm -f "$ELF_HEADER"
[[ "$ELF_COUNT" -ge 18 ]]
printf 'PLASMA33_POSTCHECK=nspr-nss-libndp-networkmanager-aarch64-files-static-only\n'
{
  printf 'BLFS_PLASMA33_RESULT=ok\nPACKAGE_COUNT=4\nSOURCE_COUNT=5\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-new-installed-tools-post-install\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PACKAGES=NSPR,NSS,libndp,NetworkManager\nNSPR=4.37\nNSS=3.115\nLIBNDP=1.9\nNETWORKMANAGER=1.54.0\nLIBNM=1.54.0\nELF_FILE_COUNT=%s\n' "$ELF_COUNT"
  printf 'NSPR_TOOLS=installed-not-executed\nNSS_SYSTEM_ZLIB=1\nNSS_DISABLE_GTESTS=1\nNSS_TESTS=not-run-gtests-disabled\nNSS_TOOLS=installed-not-executed\nP11_KIT=not-reconfigured\n'
  printf 'NETWORKMANAGER_RUNTIME=not-started\nNMCLI=installed-not-executed\nNM_ONLINE=installed-not-executed\nNDPTOOL=installed-not-executed\nDBUS_SERVICES=installed-not-activated\nUDEV_RULES=installed-not-reloaded\nNETWORK_INTERFACES=not-accessed\nLIVE_NETWORK_CONFIGURATION=not-changed\n'
  printf 'SESSION_TRACKING=no-logind\nNMTUI=not-built-newt-absent\nSYSTEMD_UNIT=not-installed\nMODEM_MANAGER=false\nPPP=false\nOVS=false\nNM_CLOUD_SETUP=false\nNBFT=false\nTEST_SUITES=not-run-disabled\n'
  printf 'OFFICIAL_PLASMA_ACTIVE=56\nOFFICIAL_PLASMA_BUILDABLE_COVERED=54\nOFFICIAL_PLASMA_DEFERRED=2\nOFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order\n'
  printf 'DRKONQI=deferred-requires-systemd-journal-and-coredumpd\nPLASMA_NM=deferred-awaiting-plasma34-build\nPLASMA32=preserved-pipeline-223\n'
  printf 'NETWORK=not-used-by-built-programs\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
