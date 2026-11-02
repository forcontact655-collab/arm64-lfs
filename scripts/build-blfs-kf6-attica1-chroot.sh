#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-attica1-report.txt
PROGRESS=/root/blfs-kf6-attica1-progress.txt
QT6PREFIX=/opt/qt6
KF6PREFIX=/opt/kf6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -x "$QT6PREFIX/bin/qmake6" ]]
[[ -x "$QT6PREFIX/bin/lrelease" ]]
[[ -x "$QT6PREFIX/bin/lconvert" ]]
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /etc/profile.d/qt6.sh ]]
[[ -f /etc/ld.so.conf.d/qt6.conf ]]
[[ ! -e "$KF6PREFIX" && ! -L "$KF6PREFIX" ]]
[[ ! -e /etc/profile.d/kf6.sh ]]
[[ ! -e /etc/ld.so.conf.d/kf6.conf ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -d /sources ]]
: >"$PROGRESS"

# First KF6 framework: initialize the BLFS /opt/kf6 hierarchy once.
install -dm755 "$KF6PREFIX"/{etc,share} "$KF6PREFIX/share/icons"
ln -s /etc/dbus-1 "$KF6PREFIX/etc/dbus-1"
ln -s /usr/share/dbus-1 "$KF6PREFIX/share/dbus-1"
ln -s /usr/share/polkit-1 "$KF6PREFIX/share/polkit-1"
ln -s /usr/share/icons/hicolor "$KF6PREFIX/share/icons/hicolor"
printf '/opt/kf6/lib\n' >/etc/ld.so.conf.d/kf6.conf
cat >/etc/profile.d/kf6.sh <<'EOF'
export KF6_PREFIX=/opt/kf6
export PATH="$KF6_PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$KF6_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export XDG_CONFIG_DIRS="$KF6_PREFIX/etc/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_DATA_DIRS="$KF6_PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export QT_PLUGIN_PATH="$KF6_PREFIX/lib/plugins:$KF6_PREFIX/lib/plugins/kcms:${QT_PLUGIN_PATH:-}"
export QML2_IMPORT_PATH="$KF6_PREFIX/lib/qml:${QML2_IMPORT_PATH:-}"
export PYTHONPATH="$KF6_PREFIX/lib/python3.13/site-packages:${PYTHONPATH:-}"
export CPLUS_INCLUDE_PATH="$KF6_PREFIX/include:${CPLUS_INCLUDE_PATH:-}"
export GTK_PATH="$KF6_PREFIX/lib/gtk-3.0:${GTK_PATH:-}"
EOF
cat >>/etc/profile.d/qt6.sh <<'EOF'
# Begin Qt6 changes for KF6
export QT_PLUGIN_PATH="/usr/lib/plugins:$QT6DIR/plugins:${QT_PLUGIN_PATH:-}"
export QML2_IMPORT_PATH="$QT6DIR/qml:${QML2_IMPORT_PATH:-}"
# End Qt6 changes for KF6
EOF

ARCHIVE=attica-6.17.0.tar.xz
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == attica-6.17.0 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
mkdir "$SOURCES/$PACKAGE_DIR/build"
cd "$SOURCES/$PACKAGE_DIR/build"
printf 'BUILD_BLFS_KF6_ATTICA1=attica\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D CMAKE_PREFIX_PATH=/opt/qt6 \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -D BUILD_PYTHON_BINDINGS=OFF \
  -W no-dev \
  ..
ninja
ninja install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_KF6_ATTICA1_BUILT=attica-6.17.0\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_KF6_ATTICA1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -f /opt/kf6/lib/cmake/KF6Attica/KF6AtticaConfig.cmake ]]
[[ -f /opt/kf6/include/KF6/Attica/Attica/Category ]]
[[ -L /opt/kf6/lib/libKF6Attica.so ]]
[[ "$(readlink /opt/kf6/etc/dbus-1)" == /etc/dbus-1 ]]
[[ "$(readlink /opt/kf6/share/dbus-1)" == /usr/share/dbus-1 ]]
[[ "$(readlink /opt/kf6/share/polkit-1)" == /usr/share/polkit-1 ]]
[[ "$(readlink /opt/kf6/share/icons/hicolor)" == /usr/share/icons/hicolor ]]
grep -q '^export KF6_PREFIX=/opt/kf6$' /etc/profile.d/kf6.sh
grep -q '^/opt/kf6/lib$' /etc/ld.so.conf.d/kf6.conf

rm -rf /tmp/blfs-kf6-attica1-smoke /tmp/blfs-kf6-attica1-smoke-build
mkdir -p /tmp/blfs-kf6-attica1-smoke
cat >/tmp/blfs-kf6-attica1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_attica1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Network)
find_package(KF6Attica 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-attica1-smoke main.cpp)
target_link_libraries(blfs-kf6-attica1-smoke PRIVATE KF6::Attica)
EOF
cat >/tmp/blfs-kf6-attica1-smoke/main.cpp <<'EOF'
#include <Attica/Category>
#include <QString>
#include <QtGlobal>
#include <cstdio>
int main() {
  Attica::Category category;
  category.setId(QStringLiteral("42"));
  category.setName(QStringLiteral("blfs"));
  category.setDisplayName(QStringLiteral("BLFS"));
  if (!category.isValid()) return 1;
  if (category.id() != QStringLiteral("42")) return 2;
  if (category.name() != QStringLiteral("blfs")) return 3;
  if (category.displayName() != QStringLiteral("BLFS")) return 4;
  std::printf("BLFS_KF6_ATTICA1_EXEC_OK=%s=%s\n", qVersion(), category.name().toUtf8().constData());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-attica1-smoke -B /tmp/blfs-kf6-attica1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-attica1-smoke-build
OUTPUT="$(LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-attica1-smoke-build/blfs-kf6-attica1-smoke)"
[[ "$OUTPUT" == BLFS_KF6_ATTICA1_EXEC_OK=6.9.2=blfs ]]
readelf -h /tmp/blfs-kf6-attica1-smoke-build/blfs-kf6-attica1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-attica1-smoke-build/blfs-kf6-attica1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_KF6_ATTICA1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_ATTICA1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\n'
  printf 'ECM=6.17.0\n'
  printf 'ATTICA=6.17.0\n'
  printf 'ATTICA_SMOKE=%s\n' "$OUTPUT"
  printf 'KF6_INIT=ok\n'
  printf 'KF6_PREFIX=/opt/kf6\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-attica1-smoke /tmp/blfs-kf6-attica1-smoke-build
