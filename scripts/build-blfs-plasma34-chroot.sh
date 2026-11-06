#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma34-report.txt
PROGRESS=/root/blfs-plasma34-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/meson && -x /usr/bin/pkg-config && -x /usr/bin/readelf && -x /usr/bin/xsltproc ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /usr/lib/libnm.so /usr/lib/pkgconfig/libnm.pc \
  /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake \
  /opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Kirigami/KF6KirigamiConfig.cmake \
  /opt/kf6/lib/cmake/KF6Prison/KF6PrisonConfig.cmake; do
  [[ -e "$path" ]]
done
pkg-config --exists libnm 'gudev-1.0 >= 238' polkit-gobject-1 gobject-introspection-1.0 libelogind
[[ "$(pkg-config --modversion libnm)" == 1.54.0 ]]
for path in \
  /usr/lib/libmbim-glib.so /usr/lib/libqmi-glib.so /usr/lib/libmm-glib.so \
  /opt/kf6/lib/libKF6NetworkManagerQt.so /opt/kf6/lib/libKF6ModemManagerQt.so \
  /opt/kf6/lib/libplasmanm_internal.so /opt/kf6/lib/libplasmanm_editor.so \
  /opt/kf6/share/plasma/plasmoids/org.kde.plasma.networkmanagement/metadata.json; do
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
  find /usr /etc -xdev \( -type f -o -type l \) -print | sort
}
build_meson_package() {
  local package="$1" version="$2" config="$3" manifest="$4"
  shift 4
  snapshot_tree >/tmp/blfs-plasma34-before.txt
  extract_package "$package-$version.tar.gz" "$package-$version"
  printf 'BUILD_BLFS_PLASMA34=%s\n' "$package"
  mkdir build
  cd build
  meson setup .. --prefix=/usr --libdir=/usr/lib --buildtype=release "$@"
  python3 - "$config" "$package" "$version" <<'PY'
import json,sys
from pathlib import Path
options={row['name']:row['value'] for row in json.loads(Path('meson-info/intro-buildoptions.json').read_text())}
project=json.loads(Path('meson-info/intro-projectinfo.json').read_text())
assert project['version']==sys.argv[3],project
def norm(value):
    if isinstance(value,bool): return str(value).lower()
    if isinstance(value,(str,int,float)): return str(value)
    return json.dumps(value,sort_keys=True)
lines=['PROJECT='+sys.argv[2],'PROJECT_VERSION='+project['version']]
lines += [name+'='+norm(options[name]) for name in sorted(options)]
lines += ['TEST_SUITES=not-run','DAEMONS=not-started','TOOLS=installed-not-executed','DBUS_SERVICES=installed-not-activated','UDEV_RULES=installed-not-reloaded','NETWORK_INTERFACES=not-accessed']
Path(sys.argv[1]).write_text('\n'.join(lines)+'\n')
PY
  ninja -j2
  ninja install
  remove_package
  snapshot_tree >/tmp/blfs-plasma34-after.txt
  comm -13 /tmp/blfs-plasma34-before.txt /tmp/blfs-plasma34-after.txt >"$manifest"
  rm -f /tmp/blfs-plasma34-before.txt /tmp/blfs-plasma34-after.txt
  [[ -s "$manifest" ]]
  printf 'BLFS_PLASMA34_BUILT=%s-%s\n' "$package" "$version" >>"$PROGRESS"
}
TARGETS=''
build_cmake_package() {
  local package="$1" version="$2" config="$3" manifest="$4" required_targets="${TARGETS:-}" target
  shift 4
  [[ -n "$required_targets" ]]
  extract_package "$package-$version.tar.xz" "$package-$version"
  printf 'BUILD_BLFS_PLASMA34=%s\n' "$package"
  mkdir build
  cd build
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    "$@" -W no-dev ..
  for target in $required_targets; do grep -q "$target" build.ninja; done
  cp CMakeCache.txt "$config"
  {
    printf '\nPROJECT=%s\nPROJECT_VERSION=%s\nREQUIRED_TARGETS=%s\n' "$package" "$version" "$required_targets"
    if [[ "$package" == plasma-nm ]]; then
      if grep -q 'plasmanetworkmanagement_openconnect' build.ninja; then
        printf 'OPENCONNECT_PLUGIN=built\n'
      else
        printf 'OPENCONNECT_PLUGIN=not-built\n'
      fi
    fi
    printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nPLASMA_NM_RUNTIME=not-started\nQML_UI=not-started\nKDED_MODULES=installed-not-loaded\nKCM_MODULES=installed-not-loaded\nVPN_HELPERS=not-executed\n'
  } >>"$config"
  ninja -j2
  ninja install
  [[ -s install_manifest.txt ]]
  cp install_manifest.txt "$manifest"
  remove_package
  TARGETS=''
  printf 'BLFS_PLASMA34_BUILT=%s-%s\n' "$package" "$version" >>"$PROGRESS"
}

MBIM_CONFIG=/root/blfs-plasma34-libmbim-config.txt
MBIM_MANIFEST=/root/blfs-plasma34-libmbim-install-manifest.txt
build_meson_package libmbim 1.32.0 "$MBIM_CONFIG" "$MBIM_MANIFEST" -D bash_completion=false -D man=false
for path in /usr/lib/libmbim-glib.so /usr/lib/pkgconfig/mbim-glib.pc /usr/include/libmbim-glib/libmbim-glib.h /usr/bin/mbimcli /usr/bin/mbim-network; do grep -qxF "$path" "$MBIM_MANIFEST"; done
[[ "$(pkg-config --modversion mbim-glib)" == 1.32.0 ]]
for line in prefix=/usr libdir=lib buildtype=release bash_completion=false man=false introspection=true; do grep -qxF "$line" "$MBIM_CONFIG"; done

QMI_CONFIG=/root/blfs-plasma34-libqmi-config.txt
QMI_MANIFEST=/root/blfs-plasma34-libqmi-install-manifest.txt
build_meson_package libqmi 1.36.0 "$QMI_CONFIG" "$QMI_MANIFEST" -D bash_completion=false -D qrtr=false -D man=false
for path in /usr/lib/libqmi-glib.so /usr/lib/pkgconfig/qmi-glib.pc /usr/include/libqmi-glib/libqmi-glib.h /usr/bin/qmicli /usr/bin/qmi-network /usr/bin/qmi-firmware-update; do grep -qxF "$path" "$QMI_MANIFEST"; done
[[ "$(pkg-config --modversion qmi-glib)" == 1.36.0 ]]
for line in prefix=/usr libdir=lib buildtype=release bash_completion=false qrtr=false man=false introspection=true mbim_qmux=true collection=full; do grep -qxF "$line" "$QMI_CONFIG"; done

MM_CONFIG=/root/blfs-plasma34-modemmanager-config.txt
MM_MANIFEST=/root/blfs-plasma34-modemmanager-install-manifest.txt
build_meson_package ModemManager 1.24.2 "$MM_CONFIG" "$MM_MANIFEST" -D bash_completion=false -D qrtr=false -D systemdsystemunitdir=no
for path in /usr/lib/libmm-glib.so /usr/lib/pkgconfig/ModemManager.pc /usr/lib/pkgconfig/mm-glib.pc /usr/include/ModemManager/ModemManager.h /usr/include/libmm-glib/libmm-glib.h /usr/sbin/ModemManager /usr/bin/mmcli; do grep -qxF "$path" "$MM_MANIFEST"; done
[[ "$(pkg-config --modversion ModemManager)" == 1.24.2 ]]
[[ "$(pkg-config --modversion mm-glib)" == 1.24.2 ]]
for line in prefix=/usr libdir=lib buildtype=release bash_completion=false qrtr=false systemdsystemunitdir=no introspection=true mbim=true qmi=true polkit=strict; do grep -qxF "$line" "$MM_CONFIG"; done
if grep -q '/systemd/.*ModemManager' "$MM_MANIFEST"; then printf 'unexpected-modemmanager-systemd-unit\n' >&2; exit 1; fi

/sbin/ldconfig
NMQT_CONFIG=/root/blfs-plasma34-networkmanager-qt-config.txt
NMQT_MANIFEST=/root/blfs-plasma34-networkmanager-qt-install-manifest.txt
TARGETS='KF6NetworkManagerQt networkmanagerqtqml' build_cmake_package networkmanager-qt 6.17.0 "$NMQT_CONFIG" "$NMQT_MANIFEST" -D BUILD_EXAMPLES=OFF
for path in /opt/kf6/lib/libKF6NetworkManagerQt.so /opt/kf6/lib/cmake/KF6NetworkManagerQt/KF6NetworkManagerQtConfig.cmake /opt/kf6/lib/qml/org/kde/networkmanager/qmldir; do grep -qxF "$path" "$NMQT_MANIFEST"; done
grep -Eq '^/opt/kf6/lib/qml/org/kde/networkmanager/.*\.so$' "$NMQT_MANIFEST"
for line in 'BUILD_TESTING:BOOL=OFF' 'BUILD_EXAMPLES:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6'; do grep -qxF "$line" "$NMQT_CONFIG"; done

MMQT_CONFIG=/root/blfs-plasma34-modemmanager-qt-config.txt
MMQT_MANIFEST=/root/blfs-plasma34-modemmanager-qt-install-manifest.txt
TARGETS='KF6ModemManagerQt' build_cmake_package modemmanager-qt 6.17.0 "$MMQT_CONFIG" "$MMQT_MANIFEST" -D BUILD_EXAMPLES=OFF
for path in /opt/kf6/lib/libKF6ModemManagerQt.so /opt/kf6/lib/cmake/KF6ModemManagerQt/KF6ModemManagerQtConfig.cmake; do grep -qxF "$path" "$MMQT_MANIFEST"; done
for line in 'BUILD_TESTING:BOOL=OFF' 'BUILD_EXAMPLES:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6'; do grep -qxF "$line" "$MMQT_CONFIG"; done

PNM_CONFIG=/root/blfs-plasma34-plasma-nm-config.txt
PNM_MANIFEST=/root/blfs-plasma34-plasma-nm-install-manifest.txt
TARGETS='plasmanm_internal plasmanm_editor kded_networkmanagement kcm_networkmanagement kcm_mobile_wifi kcm_cellular_network kcm_mobile_hotspot plasmanetworkmanagement_openvpnui plasmanetworkmanagement_vpncui plasmanetworkmanagement_l2tpui' build_cmake_package plasma-nm 6.4.4 "$PNM_CONFIG" "$PNM_MANIFEST"
for path in /opt/kf6/lib/libplasmanm_internal.so /opt/kf6/lib/libplasmanm_editor.so /opt/kf6/lib/qml/org/kde/plasma/networkmanagement/qmldir /opt/kf6/share/plasma/plasmoids/org.kde.plasma.networkmanagement/metadata.json; do grep -qxF "$path" "$PNM_MANIFEST"; done
for name in networkmanagement kcm_networkmanagement kcm_mobile_wifi kcm_cellular_network kcm_mobile_hotspot; do grep -Eq "^/opt/kf6/lib/plugins/.*/(lib)?${name}\\.so$" "$PNM_MANIFEST"; done
for name in openvpn vpnc l2tp; do grep -Eq "^/opt/kf6/lib/plugins/plasma/network/vpn/(lib)?plasmanetworkmanagement_${name}ui\\.so$" "$PNM_MANIFEST"; done
for line in 'BUILD_TESTING:BOOL=OFF' 'CMAKE_INSTALL_PREFIX:PATH=/opt/kf6' 'OPENCONNECT_PLUGIN=not-built'; do grep -qxF "$line" "$PNM_CONFIG"; done

/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA34_BUILT=' "$PROGRESS")" -eq 6 ]]
EXPECTED_ELF=(
  /usr/lib/libmbim-glib.so /usr/lib/libqmi-glib.so /usr/lib/libmm-glib.so
  /usr/bin/mbimcli /usr/bin/qmicli /usr/sbin/ModemManager /usr/bin/mmcli
  /opt/kf6/lib/libKF6NetworkManagerQt.so /opt/kf6/lib/libKF6ModemManagerQt.so
  /opt/kf6/lib/libplasmanm_internal.so /opt/kf6/lib/libplasmanm_editor.so
)
for path in "${EXPECTED_ELF[@]}"; do
  [[ -f "$path" ]]
  readelf -h "$path" | grep -q 'Machine:.*AArch64'
done
INTERPRETER="$(readelf -l /usr/bin/mmcli | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
ELF_COUNT=0
ELF_HEADER=/tmp/blfs-plasma34-elf-header.txt
MESON_MANIFESTS=("$MBIM_MANIFEST" "$QMI_MANIFEST" "$MM_MANIFEST")
CMAKE_MANIFESTS=("$NMQT_MANIFEST" "$MMQT_MANIFEST" "$PNM_MANIFEST")
for manifest in "${MESON_MANIFESTS[@]}" "${CMAKE_MANIFESTS[@]}"; do
  while IFS= read -r path; do
    [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]
    case "$manifest" in
      "$MBIM_MANIFEST"|"$QMI_MANIFEST"|"$MM_MANIFEST") [[ "$path" == /usr/* || "$path" == /etc/* ]] ;;
      *) [[ "$path" == /opt/kf6/* ]] ;;
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
[[ "$ELF_COUNT" -ge 20 ]]
printf 'PLASMA34_POSTCHECK=mobile-broadband-networkmanager-qt-modemmanager-qt-plasma-nm-aarch64-files-static-only\n'
{
  printf 'BLFS_PLASMA34_RESULT=ok\nPACKAGE_COUNT=6\nSOURCE_COUNT=6\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-new-installed-tools-post-install\nNEW_EXECUTABLES=installed-not-executed\nELF_ARCH=AArch64\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PACKAGES=libmbim,libqmi,ModemManager,networkmanager-qt,modemmanager-qt,plasma-nm\nLIBMBIM=1.32.0\nLIBQMI=1.36.0\nMODEMMANAGER=1.24.2\nNETWORKMANAGER_QT=6.17.0\nMODEMMANAGER_QT=6.17.0\nPLASMA_NM=6.4.4\nKF6_VERSION=6.17.0\nPLASMA_VERSION=6.4.4\nELF_FILE_COUNT=%s\n' "$ELF_COUNT"
  printf 'LIBDIR=/usr/lib\nMBIM=true\nQMI=true\nQRTR=false\nPOLKIT=strict\nCMAKE_BUILD_TESTING=OFF\nOPENCONNECT_PLUGIN=not-built\nTEST_SUITES=not-run\n'
  printf 'MODEMMANAGER_RUNTIME=not-started\nMMCLI=installed-not-executed\nMBIMCLI=installed-not-executed\nQMICLI=installed-not-executed\nDBUS_SERVICES=installed-not-activated\nUDEV_RULES=installed-not-reloaded\nNETWORK_INTERFACES=not-accessed\nLIVE_NETWORK_CONFIGURATION=not-changed\n'
  printf 'PLASMA_NM_RUNTIME=not-started\nQML_APPLET=installed-not-loaded\nQML_UI=not-started\nKDED_MODULES=installed-not-loaded\nKCM_MODULES=installed-not-loaded\nVPN_HELPERS=not-executed\nNETWORKMANAGER_MODEM_MANAGER=false-preserved-plasma33\n'
  printf 'OFFICIAL_PLASMA_ACTIVE=56\nOFFICIAL_PLASMA_BUILDABLE_COVERED=55\nOFFICIAL_PLASMA_DEFERRED=1\nOFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order\n'
  printf 'DRKONQI=deferred-requires-systemd-journal-and-coredumpd\nPLASMA_NM=built-this-stage\nPLASMA33=preserved-pipeline-229\nPLASMA32=preserved-pipeline-223\n'
  printf 'NETWORK=not-used-by-built-programs\nPLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nAUDIO=not-started\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
