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
REPORT=/root/blfs-plasma2-report.txt
PROGRESS=/root/blfs-plasma2-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/meson ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in \
  /opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake \
  /opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake \
  /opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake \
  /opt/kf6/lib/cmake/KF6Package/KF6PackageConfig.cmake \
  /opt/kf6/lib/cmake/KF6Screen/KF6ScreenConfig.cmake \
  /usr/lib/libsensors.so; do
  [[ -e "$path" ]]
done
# These are new outputs, not another copy of the accepted Plasma1 stage.
for path in \
  /opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake \
  /opt/kf6/lib/cmake/KGlobalAccelD/KGlobalAccelDConfig.cmake \
  /opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake \
  /opt/kf6/lib/cmake/Aurorae/AuroraeConfig.cmake \
  /opt/kf6/bin/kinfocenter \
  /usr/include/security/pam_appl.h \
  /usr/lib/libpam.so; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
# Linux-PAM is a required kscreenlocker dependency and was absent from the
# accepted rootfs (pipeline 164 stopped at its CMake probe).  This is the
# BLFS first-time Meson build, with its pre-install test configuration.
archive=Linux-PAM-1.7.1.tar.xz
package_dir=Linux-PAM-1.7.1
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
[[ "${first%%/*}" == "$package_dir" ]]
rm -rf "$SOURCES/$package_dir"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
cd "$SOURCES/$package_dir"
mkdir build
cd build
printf 'BUILD_BLFS_PLASMA2=linux-pam\n'
meson setup .. \
  --prefix=/usr \
  --buildtype=release \
  -D docdir=/usr/share/doc/Linux-PAM-1.7.1
ninja
install -v -m755 -d /etc/pam.d
PAM_OTHER_CREATED=0
if [[ ! -e /etc/pam.d/other ]]; then
  cat >/etc/pam.d/other <<'EOF'
auth     required       pam_deny.so
account  required       pam_deny.so
password required       pam_deny.so
session  required       pam_deny.so
EOF
  PAM_OTHER_CREATED=1
fi
ninja test
if [[ "$PAM_OTHER_CREATED" -eq 1 ]]; then rm -f /etc/pam.d/other; fi
ninja install
chmod -v 4755 /usr/sbin/unix_chkpwd
rm -rf /usr/lib/systemd
cd /sources
rm -rf "$package_dir"
printf 'BLFS_PLASMA2_BUILT=linux-pam-1.7.1\n' >>"$PROGRESS"
# Create the generic BLFS PAM configuration only when it is not already
# present; this stage must not silently replace an existing system policy.
for pam_file in system-account system-auth system-session system-password; do
  [[ ! -e "/etc/pam.d/$pam_file" ]] || continue
  case "$pam_file" in
    system-account) pam_line='account   required    pam_unix.so' ;;
    system-auth) pam_line='auth      required    pam_unix.so' ;;
    system-session) pam_line='session   required    pam_unix.so' ;;
    system-password) pam_line='password  required    pam_unix.so       yescrypt shadow try_first_pass' ;;
  esac
  printf '# Begin /etc/pam.d/%s\n%s\n# End /etc/pam.d/%s\n' "$pam_file" "$pam_line" "$pam_file" >"/etc/pam.d/$pam_file"
done
packages=(kscreenlocker kinfocenter kglobalacceld kwayland aurorae)
for name in "${packages[@]}"; do
  archive="$name-6.4.4.tar.xz"
  package_dir="$name-6.4.4"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  [[ "${first%%/*}" == "$package_dir" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  if [[ "$name" == kinfocenter ]]; then
    [[ -f /root/blfs-plasma2-kinfocenter-opengl-only.patch ]]
    patch -Np1 -i /root/blfs-plasma2-kinfocenter-opengl-only.patch
  fi
  mkdir build
  cd build
  printf 'BUILD_BLFS_PLASMA2=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_QT5=OFF \
    -D BUILD_TESTING=OFF \
    -D BUILD_EXAMPLES=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_PLASMA2_BUILT=%s-6.4.4\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA2_BUILT=' "$PROGRESS")" -eq 6 ]]
for path in \
  /usr/include/security/pam_appl.h \
  /usr/lib/libpam.so \
  /usr/sbin/unix_chkpwd \
  /opt/kf6/libexec/kinfocenter-opengl-helper \
  /opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake \
  /opt/kf6/lib/cmake/KGlobalAccelD/KGlobalAccelDConfig.cmake \
  /opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake \
  /opt/kf6/lib/cmake/Aurorae/AuroraeConfig.cmake \
  /opt/kf6/libexec/kglobalacceld \
  /opt/kf6/lib/qml/org/kde/kwin/decoration/qmldir; do
  [[ -e "$path" ]]
done
printf 'PLASMA2_POSTCHECK=kinfocenter-link\n'
[[ -L /opt/kf6/bin/kinfocenter ]]
[[ "$(readlink /opt/kf6/bin/kinfocenter)" == */systemsettings ]]
KINFOCENTER_LIBRARY=/opt/kf6/lib/libKInfoCenterInternal.so
[[ -f "$KINFOCENTER_LIBRARY" ]]
KINFOCENTER_QMLDIR=/opt/kf6/lib/qml/org/kde/kinfocenter/private/qmldir
[[ -f "$KINFOCENTER_QMLDIR" ]]
printf 'PLASMA2_POSTCHECK=kinfocenter-files\n'
AURORAE_PLUGIN=/opt/kf6/lib/plugins/org.kde.kdecoration3/org.kde.kwin.aurorae.so
[[ -f "$AURORAE_PLUGIN" ]]
printf 'PLASMA2_POSTCHECK=aurorae-file\n'

# The daemon's version path exits before D-Bus registration.  It is a
# version execution only, not a global-shortcut or display-session test.
rm -rf /tmp/blfs-plasma2-runtime /tmp/blfs-plasma2-config
install -d -m 0700 /tmp/blfs-plasma2-runtime /tmp/blfs-plasma2-config
set +e
KGLOBAL_OUTPUT="$(QT_QPA_PLATFORM=offscreen XDG_SESSION_TYPE=x11 \
  XDG_CONFIG_HOME=/tmp/blfs-plasma2-config XDG_RUNTIME_DIR=/tmp/blfs-plasma2-runtime \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib \
  /opt/kf6/libexec/kglobalacceld --version 2>&1)"
KGLOBAL_STATUS=$?
set -e
printf 'KGLOBALACCELD_VERSION_STATUS=%s\nKGLOBALACCELD_VERSION_OUTPUT=%s\n' "$KGLOBAL_STATUS" "$KGLOBAL_OUTPUT"
[[ "$KGLOBAL_STATUS" -eq 0 ]]
[[ "$KGLOBAL_OUTPUT" == *6.4.4* ]]

# Native, display-free smoke.  Typeinfo references make the two internal
# libraries real link-time/runtime dependencies without starting lockers or
# registering D-Bus services.  KWayland is constructed without connecting to
# a compositor.  Aurorae metadata is read without loading its decoration
# plugin, so this does not claim a KWin session.
rm -rf /tmp/blfs-plasma2-smoke /tmp/blfs-plasma2-smoke-build /tmp/blfs-plasma2-smoke-stderr.log
mkdir -p /tmp/blfs-plasma2-smoke
cat >/tmp/blfs-plasma2-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma2_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui DBus Widgets)
find_package(KF6GlobalAccel 6.17.0 REQUIRED CONFIG)
find_package(KF6WindowSystem 6.17.0 REQUIRED CONFIG)
find_package(KF6CoreAddons 6.17.0 REQUIRED CONFIG)
find_package(KF6Config 6.17.0 REQUIRED CONFIG)
find_package(KF6Service 6.17.0 REQUIRED CONFIG)
find_package(KF6KIO 6.17.0 REQUIRED CONFIG)
find_package(KF6JobWidgets 6.17.0 REQUIRED CONFIG)
find_package(KScreenLocker 6.4.4 REQUIRED CONFIG)
find_package(KGlobalAccelD 6.4.4 REQUIRED CONFIG)
find_package(KWayland 6.4.4 REQUIRED CONFIG)
find_package(Aurorae 6.4.4 REQUIRED CONFIG)
find_path(PAM_INCLUDE_DIR NAMES security/pam_appl.h REQUIRED)
find_library(PAM_LIBRARY NAMES pam REQUIRED)
add_executable(blfs-plasma2-smoke main.cpp)
target_include_directories(blfs-plasma2-smoke PRIVATE "${PAM_INCLUDE_DIR}")
target_link_libraries(blfs-plasma2-smoke PRIVATE
  Qt6::Core Qt6::Gui PW::KScreenLocker K::KGlobalAccelD Plasma::KWaylandClient "${PAM_LIBRARY}")
EOF
cat >/tmp/blfs-plasma2-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <QJsonObject>
#include <QPluginLoader>
#include <QString>
#include <security/pam_appl.h>
#include <KScreenLocker/KsldApp>
#include <kglobalacceld.h>
#include <KWayland/Client/connection_thread.h>
#include <QtGlobal>
#include <cstdio>
#include <cstring>
#include <typeinfo>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  if (std::strcmp(typeid(KSldApp).name(), "") == 0 ||
      std::strcmp(typeid(KGlobalAccelD).name(), "") == 0) return 1;
  KWayland::Client::ConnectionThread connection;
  connection.setSocketName(QStringLiteral("vim-plasma2-no-compositor"));
  if (connection.display() != nullptr) return 2;
  const QString plugin_path = qEnvironmentVariable("AURORAE_PLUGIN_PATH");
  if (plugin_path.isEmpty()) return 3;
  QPluginLoader aurorae(plugin_path);
  const QJsonObject metadata = aurorae.metaData();
  if (metadata.isEmpty() || metadata.value(QStringLiteral("IID")).toString().isEmpty()) return 4;
  if (aurorae.isLoaded()) return 5;
  const char *pam_success = pam_strerror(nullptr, PAM_SUCCESS);
  if (!pam_success || std::strcmp(pam_success, "Success") != 0) return 6;
  std::printf("BLFS_PLASMA2_EXEC_OK=%s=6.4.4=pam-success=locker-type=accel-type=kwayland-object=aurorae-metadata\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma2-smoke -B /tmp/blfs-plasma2-smoke-build -G Ninja \
  -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma2-smoke-build
set +e
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-plasma2-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-plasma2-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 AURORAE_PLUGIN_PATH="$AURORAE_PLUGIN" \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib \
  /tmp/blfs-plasma2-smoke-build/blfs-plasma2-smoke 2>/tmp/blfs-plasma2-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma2-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA2_EXEC_OK=6.9.2=6.4.4=pam-success=locker-type=accel-type=kwayland-object=aurorae-metadata ]]
readelf -h /tmp/blfs-plasma2-smoke-build/blfs-plasma2-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma2-smoke-build/blfs-plasma2-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA2_RESULT=ok\nPACKAGE_COUNT=6\nSOURCE_COUNT=6\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA2_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nPLASMA_VERSION=6.4.4\nLINUX_PAM=1.7.1\nPACKAGES=linux-pam+kscreenlocker+kinfocenter+kglobalacceld+kwayland+aurorae\n'
  printf 'KSCREENLOCKER=6.4.4\nKINFOCENTER=6.4.4\nKGLOBALACCELD=6.4.4\nKWAYLAND=6.4.4\nAURORAE=6.4.4\n'
  printf 'LINUX_PAM_TEST_SUITE=ninja-test-passed\nPAM_SMOKE=native-strerror-no-auth\nPAM_CONFIG=standard-files-present-or-created\nKSCREENLOCKER_SMOKE=native-typeinfo-no-lock-no-dbus\nKINFOCENTER_SMOKE=library-qml-and-symlink-only\nKINFOCENTER_VULKAN=disabled-qt-vulkan-unavailable-opengl-only\nKINFOCENTER_OPENGL_HELPER=installed-not-run-no-display\nKINFOCENTER_LAUNCHER=deferred-systemsettings-not-built\n'
  printf 'KGLOBALACCELD_VERSION_EXEC=passed-no-dbus-registration\nKWAYLAND_SMOKE=native-object-no-compositor\nAURORAE_SMOKE=native-plugin-metadata-not-loaded\n'
  printf 'NATIVE_SMOKE=cmake-targets+pam-strerror+typeinfo+kwayland-object+aurorae-metadata\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'PLASMA1=preserved-pipeline-163\nPLASMA=core-libraries-and-second-stage-built-not-running\nPLASMA_DESKTOP=not-built\nREAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma2-smoke /tmp/blfs-plasma2-smoke-build \
  /tmp/blfs-plasma2-runtime /tmp/blfs-plasma2-config /tmp/blfs-plasma2-smoke-stderr.log
