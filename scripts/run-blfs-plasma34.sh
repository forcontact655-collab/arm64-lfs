#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma34-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA34_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma34-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in "$LFS/usr/bin/cmake" "$LFS/usr/bin/ninja" "$LFS/usr/bin/meson" "$LFS/usr/bin/pkg-config" "$LFS/usr/bin/python3" "$LFS/usr/bin/readelf" "$LFS/usr/bin/xsltproc" \
  "$LFS/usr/lib/libnm.so" "$LFS/usr/lib/pkgconfig/libnm.pc" \
  "$LFS/opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake" \
  "$LFS/opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/usr/lib/libmbim-glib.so" "$LFS/usr/lib/libqmi-glib.so" "$LFS/usr/lib/libmm-glib.so" \
  "$LFS/opt/kf6/lib/libKF6NetworkManagerQt.so" "$LFS/opt/kf6/lib/libKF6ModemManagerQt.so" \
  "$LFS/opt/kf6/lib/libplasmanm_internal.so" "$LFS/opt/kf6/lib/libplasmanm_editor.so" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.networkmanagement/metadata.json"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in libmbim-1.32.0.tar.gz libqmi-1.36.0.tar.gz ModemManager-1.24.2.tar.gz networkmanager-qt-6.17.0.tar.xz modemmanager-qt-6.17.0.tar.xz plasma-nm-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA34_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma34-chroot.sh" "$LFS/root/build-blfs-plasma34-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma34-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
NAMES=(report progress libmbim-install-manifest libmbim-config libqmi-install-manifest libqmi-config modemmanager-install-manifest modemmanager-config networkmanager-qt-install-manifest networkmanager-qt-config modemmanager-qt-install-manifest modemmanager-qt-config plasma-nm-install-manifest plasma-nm-config)
for name in "${NAMES[@]}"; do
  if sudo -n test -f "$LFS/root/blfs-plasma34-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma34-$name.txt" >"$ARTIFACTS/blfs-plasma34-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA34_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma34-chroot.sh"
for name in "${NAMES[@]}"; do sudo -n rm -f "$LFS/root/blfs-plasma34-$name.txt"; done
REPORT="$ARTIFACTS/blfs-plasma34-report.txt"
for expected in \
  'BLFS_PLASMA34_RESULT=ok' 'PACKAGE_COUNT=6' 'SOURCE_COUNT=6' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-new-installed-tools-post-install' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'PACKAGES=libmbim,libqmi,ModemManager,networkmanager-qt,modemmanager-qt,plasma-nm' \
  'LIBMBIM=1.32.0' 'LIBQMI=1.36.0' 'MODEMMANAGER=1.24.2' 'NETWORKMANAGER_QT=6.17.0' 'MODEMMANAGER_QT=6.17.0' 'PLASMA_NM=6.4.4' 'KF6_VERSION=6.17.0' 'PLASMA_VERSION=6.4.4' \
  'LIBDIR=/usr/lib' 'MBIM=true' 'QMI=true' 'QRTR=false' 'POLKIT=strict' 'CMAKE_BUILD_TESTING=OFF' 'OPENCONNECT_PLUGIN=not-built' 'TEST_SUITES=not-run' \
  'MODEMMANAGER_RUNTIME=not-started' 'MMCLI=installed-not-executed' 'MBIMCLI=installed-not-executed' 'QMICLI=installed-not-executed' \
  'DBUS_SERVICES=installed-not-activated' 'UDEV_RULES=installed-not-reloaded' 'NETWORK_INTERFACES=not-accessed' 'LIVE_NETWORK_CONFIGURATION=not-changed' \
  'PLASMA_NM_RUNTIME=not-started' 'QML_APPLET=installed-not-loaded' 'QML_UI=not-started' 'KDED_MODULES=installed-not-loaded' 'KCM_MODULES=installed-not-loaded' 'VPN_HELPERS=not-executed' 'NETWORKMANAGER_MODEM_MANAGER=false-preserved-plasma33' \
  'OFFICIAL_PLASMA_ACTIVE=56' 'OFFICIAL_PLASMA_BUILDABLE_COVERED=55' 'OFFICIAL_PLASMA_DEFERRED=1' 'OFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order' \
  'DRKONQI=deferred-requires-systemd-journal-and-coredumpd' 'PLASMA_NM=built-this-stage' 'PLASMA33=preserved-pipeline-229' 'PLASMA32=preserved-pipeline-223' \
  'NETWORK=not-used-by-built-programs' 'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA34_BUILT=' "$ARTIFACTS/blfs-plasma34-progress.txt")" -eq 6 ]]
for line in libmbim-1.32.0 libqmi-1.36.0 ModemManager-1.24.2 networkmanager-qt-6.17.0 modemmanager-qt-6.17.0 plasma-nm-6.4.4; do
  grep -qxF "BLFS_PLASMA34_BUILT=$line" "$ARTIFACTS/blfs-plasma34-progress.txt"
done
check_config() {
  local file="$1"; shift
  for expected in "$@"; do grep -qxF "$expected" "$ARTIFACTS/$file"; done
}
check_config blfs-plasma34-libmbim-config.txt PROJECT=libmbim PROJECT_VERSION=1.32.0 prefix=/usr libdir=lib buildtype=release bash_completion=false man=false introspection=true
check_config blfs-plasma34-libqmi-config.txt PROJECT=libqmi PROJECT_VERSION=1.36.0 prefix=/usr libdir=lib buildtype=release bash_completion=false qrtr=false man=false introspection=true mbim_qmux=true collection=full
check_config blfs-plasma34-modemmanager-config.txt PROJECT=ModemManager PROJECT_VERSION=1.24.2 prefix=/usr libdir=lib buildtype=release bash_completion=false qrtr=false systemdsystemunitdir=no introspection=true mbim=true qmi=true polkit=strict
check_config blfs-plasma34-networkmanager-qt-config.txt PROJECT=networkmanager-qt PROJECT_VERSION=6.17.0 'BUILD_TESTING:BOOL=OFF' 'BUILD_EXAMPLES:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6'
check_config blfs-plasma34-modemmanager-qt-config.txt PROJECT=modemmanager-qt PROJECT_VERSION=6.17.0 'BUILD_TESTING:BOOL=OFF' 'BUILD_EXAMPLES:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6'
check_config blfs-plasma34-plasma-nm-config.txt PROJECT=plasma-nm PROJECT_VERSION=6.4.4 'BUILD_TESTING:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6' OPENCONNECT_PLUGIN=not-built
MBIM="$ARTIFACTS/blfs-plasma34-libmbim-install-manifest.txt"
QMI="$ARTIFACTS/blfs-plasma34-libqmi-install-manifest.txt"
MM="$ARTIFACTS/blfs-plasma34-modemmanager-install-manifest.txt"
NMQT="$ARTIFACTS/blfs-plasma34-networkmanager-qt-install-manifest.txt"
MMQT="$ARTIFACTS/blfs-plasma34-modemmanager-qt-install-manifest.txt"
PNM="$ARTIFACTS/blfs-plasma34-plasma-nm-install-manifest.txt"
for file in "$MBIM" "$QMI" "$MM" "$NMQT" "$MMQT" "$PNM"; do [[ -s "$file" ]]; done
for path in /usr/lib/libmbim-glib.so /usr/lib/pkgconfig/mbim-glib.pc /usr/include/libmbim-glib/libmbim-glib.h /usr/bin/mbimcli /usr/bin/mbim-network; do grep -qxF "$path" "$MBIM"; done
for path in /usr/lib/libqmi-glib.so /usr/lib/pkgconfig/qmi-glib.pc /usr/include/libqmi-glib/libqmi-glib.h /usr/bin/qmicli /usr/bin/qmi-network /usr/bin/qmi-firmware-update; do grep -qxF "$path" "$QMI"; done
for path in /usr/lib/libmm-glib.so /usr/lib/pkgconfig/ModemManager.pc /usr/lib/pkgconfig/mm-glib.pc /usr/include/ModemManager/ModemManager.h /usr/include/libmm-glib/libmm-glib.h /usr/sbin/ModemManager /usr/bin/mmcli; do grep -qxF "$path" "$MM"; done
if grep -q '/systemd/.*ModemManager' "$MM"; then printf 'unexpected-modemmanager-systemd-unit\n' >&2; exit 1; fi
for path in /opt/kf6/lib/libKF6NetworkManagerQt.so /opt/kf6/lib/cmake/KF6NetworkManagerQt/KF6NetworkManagerQtConfig.cmake /opt/kf6/lib/qml/org/kde/networkmanager/qmldir; do grep -qxF "$path" "$NMQT"; done
for path in /opt/kf6/lib/libKF6ModemManagerQt.so /opt/kf6/lib/cmake/KF6ModemManagerQt/KF6ModemManagerQtConfig.cmake; do grep -qxF "$path" "$MMQT"; done
for path in /opt/kf6/lib/libplasmanm_internal.so /opt/kf6/lib/libplasmanm_editor.so /opt/kf6/lib/qml/org/kde/plasma/networkmanagement/qmldir /opt/kf6/share/plasma/plasmoids/org.kde.plasma.networkmanagement/metadata.json; do grep -qxF "$path" "$PNM"; done
grep -Eq '^/opt/kf6/lib/qml/org/kde/networkmanager/.*\.so$' "$NMQT"
for name in networkmanagement kcm_networkmanagement kcm_mobile_wifi kcm_cellular_network kcm_mobile_hotspot; do grep -Eq "^/opt/kf6/lib/plugins/.*/(lib)?${name}\\.so$" "$PNM"; done
for name in openvpn vpnc l2tp; do grep -Eq "^/opt/kf6/lib/plugins/plasma/network/vpn/(lib)?plasmanetworkmanagement_${name}ui\\.so$" "$PNM"; done
cat "$REPORT"
