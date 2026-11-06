#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma11-report.txt
PROGRESS=/root/blfs-plasma11-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/make ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ "$(pkg-config --modversion libgcrypt)" == 1.11.2 ]]
for path in \
  /usr/include/security/pam_appl.h \
  /usr/lib64/libpam.so \
  /usr/lib/libgcrypt.so \
  /opt/kf6/lib/cmake/KF6Wallet/KF6WalletConfig.cmake \
  /opt/kf6/bin/kwalletd6 \
  /opt/kf6/bin/kwrited \
  /opt/kf6/lib/qml/org/kde/milou/libmilouqmlplugin.so; do
  [[ -e "$path" ]]
done
KWRITED_CACHE_MODE="$(stat -c %a /opt/kf6/bin/kwrited)"
printf 'PLASMA11_KWRITED_CACHE_MODE=%s\n' "$KWRITED_CACHE_MODE"
for path in /usr/bin/socat /opt/kf6/lib/security/pam_kwallet5.so /opt/kf6/libexec/pam_kwallet_init; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
extract_package() {
  local archive="$1" expected="$2" first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
}

# socat is the upstream runtime prerequisite of pam_kwallet_init.  Build it
# first so kwallet-pam's CMake probe sees the real executable, not a stub.
extract_package socat-1.8.0.3.tar.bz2 socat-1.8.0.3
printf 'BUILD_BLFS_PLASMA11=socat\n'
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
/sbin/ldconfig
cd /sources
rm -rf socat-1.8.0.3
printf 'BLFS_PLASMA11_BUILT=socat-1.8.0.3\n' >>"$PROGRESS"

[[ -x /usr/bin/socat && -x /usr/bin/filan && -x /usr/bin/procan ]]
SOCAT_REAL="$(readlink -f /usr/bin/socat)"
readelf -h "$SOCAT_REAL" | grep -q 'Machine:.*AArch64'
SOCAT_INTERPRETER="$(readelf -l "$SOCAT_REAL" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$SOCAT_INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
SOCAT_VERSION_OUTPUT="$(/usr/bin/socat -V 2>&1)"
[[ "$SOCAT_VERSION_OUTPUT" == *"socat version 1.8.0.3"* ]]
# A local STDIO -> EXEC:/bin/cat relay proves execution without sockets,
# network access, PAM, a desktop session, or any kwalletd interaction.
rm -f /tmp/blfs-plasma11-socat-stderr.log
SOCAT_RELAY_OUTPUT="$(printf 'blfs-plasma11-local-relay-ok\n' | \
  /usr/bin/timeout 15 /usr/bin/socat - EXEC:/bin/cat 2>/tmp/blfs-plasma11-socat-stderr.log)"
[[ "$SOCAT_RELAY_OUTPUT" == blfs-plasma11-local-relay-ok ]]
[[ ! -s /tmp/blfs-plasma11-socat-stderr.log ]]
NATIVE_OUTPUT='BLFS_PLASMA11_EXEC_OK=1.8.0.3=local-stdio-exec-cat-relay'
printf '%s\n' "$NATIVE_OUTPUT"

extract_package kwallet-pam-6.4.4.tar.xz kwallet-pam-6.4.4
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA11=kwallet-pam\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_QT5=OFF \
  -D BUILD_TESTING=OFF \
  -D KWALLETD_BIN_PATH=/opt/kf6/bin/kwalletd6 \
  -W no-dev ..
ninja
ninja install
cd /sources
rm -rf kwallet-pam-6.4.4
printf 'BLFS_PLASMA11_BUILT=kwallet-pam-6.4.4\n' >>"$PROGRESS"

# This SysV rootfs must not retain the inapplicable systemd user unit.
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA11_BUILT=' "$PROGRESS")" -eq 2 ]]
PAM_MODULE=/opt/kf6/lib/security/pam_kwallet5.so
PAM_INIT=/opt/kf6/libexec/pam_kwallet_init
[[ -f "$PAM_MODULE" && -x "$PAM_INIT" ]]
[[ -f /opt/kf6/etc/xdg/autostart/pam_kwallet_init.desktop ]]
readelf -h "$PAM_MODULE" | grep -q 'Machine:.*AArch64'
for symbol in pam_sm_authenticate pam_sm_open_session pam_sm_close_session pam_sm_setcred pam_sm_chauthtok; do
  readelf --wide -Ws "$PAM_MODULE" | grep -Eq "[[:space:]]${symbol}$"
done
strings "$PAM_MODULE" | grep -qxF /opt/kf6/bin/kwalletd6
grep -qF 'env | socat STDIN UNIX-CONNECT:' "$PAM_INIT"
printf 'PLASMA11_POSTCHECK=socat-native-relay-and-pam-module-elf\n'
{
  printf 'BLFS_PLASMA11_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA11_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$NATIVE_OUTPUT" "$SOCAT_INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=socat+kwallet-pam\nSOCAT=1.8.0.3\nKWALLET_PAM=6.4.4\n'
  printf 'NEW_EXECUTABLES=socat+filan+procan+pam_kwallet_init\nEXECUTED_EXECUTABLES=socat-only-local-version-and-relay\n'
  printf 'SOCAT_EXEC=version-and-local-relay-passed\nSOCAT_NETWORK=not-used\nSOCAT_VERSION=1.8.0.3-verified-native\n'
  printf 'KWALLET_PAM_STATUS=built-socat-present-not-configured\nPAM_MODULE=elf-entrypoints-verified-not-loaded\nPAM_MODULE_PATH=/opt/kf6/lib/security/pam_kwallet5.so\n'
  printf 'PAM_AUTH=not-run\nPAM_SESSION=not-run\nPAM_CONFIG=not-modified\nKWALLET_PAM_INIT=not-run\nKWALLETD=not-started\n'
  printf 'KWALLETD_BIN_PATH=/opt/kf6/bin/kwalletd6\nKWALLET_RUNTIME=functional-login-unlock-not-tested\n'
  printf 'TEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA10=preserved-pipeline-191\nKWRITED=preserved-not-rebuilt-not-executed\nKWRITED_BUILD_MODE=pipeline-191-verified-4755\nKWRITED_CACHE_MODE=observed-in-host-log-not-reasserted\nMILOU=preserved-built-not-loaded\n'
  printf 'PLASMA_DESKTOP=preserved-not-rebuilt-not-running\nACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used-by-native-smoke\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-plasma11-socat-stderr.log
