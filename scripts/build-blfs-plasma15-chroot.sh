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
REPORT=/root/blfs-plasma15-report.txt
PROGRESS=/root/blfs-plasma15-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /usr/lib/libXxf86vm.so \
  /opt/kf6/lib/cmake/KF6Wallet/KF6WalletConfig.cmake \
  /opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake \
  /opt/kf6/lib/cmake/KF6Archive/KF6ArchiveConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/libexec/org_kde_powerdevil; do
  [[ -e "$path" ]]
done
for path in \
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_kgamma.so \
  /opt/kf6/bin/ksshaskpass \
  /opt/kf6/bin/sddmthemeinstaller; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
[[ -z "$(find /opt/kf6/lib/plugins -type f -name kcm_sddm.so -print -quit)" ]]
[[ -z "$(find /opt/kf6/libexec -type f -name kcmsddm_authhelper -print -quit)" ]]
: >"$PROGRESS"
packages=(kgamma ksshaskpass sddm-kcm)
for name in "${packages[@]}"; do
  archive="$name-6.4.4.tar.xz"
  package_dir="$name-6.4.4"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  [[ "${first%%/*}" == "$package_dir" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA15=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_PLASMA15_BUILT=%s-6.4.4\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA15_BUILT=' "$PROGRESS")" -eq 3 ]]
KGAMMA_KCM=/opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_kgamma.so
KGAMMA_INIT=/opt/kf6/lib/plugins/plasma/kcminit/kcm_kgamma_init.so
SDDM_KCM="$(find /opt/kf6/lib/plugins -type f -name kcm_sddm.so -print -quit)"
SDDM_HELPER="$(find /opt/kf6/libexec -type f -name kcmsddm_authhelper -print -quit)"
[[ -f "$KGAMMA_KCM" && -e "$KGAMMA_INIT" && -n "$SDDM_KCM" && -n "$SDDM_HELPER" ]]
[[ -x /opt/kf6/bin/ksshaskpass && -x /opt/kf6/bin/sddmthemeinstaller ]]
[[ -f /opt/kf6/share/applications/org.kde.ksshaskpass.desktop ]]
stat -c 'SDDM_HELPER_MODE=%n=%a' "$SDDM_HELPER"
for elf in "$KGAMMA_KCM" "$SDDM_KCM" "$SDDM_HELPER" \
  /opt/kf6/bin/ksshaskpass /opt/kf6/bin/sddmthemeinstaller; do
  readelf -h "$elf" | grep -q 'Machine:.*AArch64'
done
for executable in "$SDDM_HELPER" /opt/kf6/bin/ksshaskpass /opt/kf6/bin/sddmthemeinstaller; do
  interpreter="$(readelf -l "$executable" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
  [[ "$interpreter" == /lib/ld-linux-aarch64.so.1 ]]
done
INTERPRETER="$(readelf -l /opt/kf6/bin/ksshaskpass | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
printf 'PLASMA15_POSTCHECK=kgamma-ksshaskpass-sddm-kcm-and-helper-elf\n'
{
  printf 'BLFS_PLASMA15_RESULT=ok\nPACKAGE_COUNT=3\nSOURCE_COUNT=3\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-password-theme-and-auth-tools\nNEW_EXECUTABLES=ksshaskpass+sddmthemeinstaller+kcmsddm_authhelper-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nPACKAGES=kgamma+ksshaskpass+sddm-kcm\nKGAMMA=6.4.4\nKSSHASKPASS=6.4.4\nSDDM_KCM=6.4.4\n'
  printf 'KGAMMA_KCM=built-not-loaded\nKGAMMA_INIT=installed-not-run\nGAMMA=not-changed\nXF86VIDMODE=not-queried\n'
  printf 'KSSHASKPASS_EXEC=not-run-no-password-or-wallet\nKWALLET=not-opened\nSSH_ASKPASS=not-invoked\n'
  printf 'SDDM_KCM_PLUGIN=built-not-loaded\nSDDM_AUTHHELPER=installed-not-executed\nSDDM_HELPER_MODE=observed-in-host-log\nSDDM_THEME_INSTALLER=built-not-executed\nSDDM_CONFIG=not-modified\nSDDM=not-started\n'
  printf 'TEST_SUITES=not-run\nSYSTEMD_USER_UNITS=removed-sysv-inapplicable\n'
  printf 'PLASMA14=preserved-pipeline-198\nPOWERDEVIL=preserved-not-executed\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\nPLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\n'
  printf 'ACTIVITY_SERVICE=preserved-not-started\nKWIN=preserved-not-rebuilt-not-running\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\n'
  printf 'NETWORK=not-used\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
