#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base2-report.txt
PROGRESS=/root/blfs-kf6-base2-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6Attica KF6Archive KF6Codecs KF6Config KF6CoreAddons KF6DBusAddons; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6GuiAddons KF6I18n KF6IdleTime; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
[[ -x /usr/bin/xfce4-terminal ]]
: >"$PROGRESS"
packages=(kguiaddons ki18n kidletime)
for name in "${packages[@]}"; do
  archive="$name-6.17.0.tar.xz"; [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$name-6.17.0" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  mkdir "$SOURCES/$package_dir/build"; cd "$SOURCES/$package_dir/build"
  printf 'BUILD_BLFS_KF6_BASE2=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D BUILD_PYTHON_BINDINGS=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$package_dir"
  printf 'BLFS_KF6_BASE2_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE2_BUILT=' "$PROGRESS")" -eq 3 ]]
for path in \
  /opt/kf6/lib/cmake/KF6GuiAddons/KF6GuiAddonsConfig.cmake \
  /opt/kf6/lib/cmake/KF6I18n/KF6I18nConfig.cmake \
  /opt/kf6/lib/cmake/KF6IdleTime/KF6IdleTimeConfig.cmake \
  /opt/kf6/lib/libKF6GuiAddons.so \
  /opt/kf6/lib/libKF6I18n.so \
  /opt/kf6/lib/libKF6IdleTime.so; do [[ -e "$path" ]]; done
for header in KLocalizedString KIdleTime; do
  find /opt/kf6/include/KF6 -type f -name "$header" -print -quit | grep -q .
done
rm -rf /tmp/blfs-kf6-base2-smoke /tmp/blfs-kf6-base2-smoke-build
mkdir -p /tmp/blfs-kf6-base2-smoke
cat >/tmp/blfs-kf6-base2-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base2_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core)
find_package(KF6GuiAddons 6.17.0 REQUIRED CONFIG)
find_package(KF6I18n 6.17.0 REQUIRED CONFIG)
find_package(KF6IdleTime 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base2-smoke main.cpp)
target_link_libraries(blfs-kf6-base2-smoke PRIVATE Qt6::Core KF6::GuiAddons KF6::I18n KF6::IdleTime)
EOF
cat >/tmp/blfs-kf6-base2-smoke/main.cpp <<'EOF'
#include <KLocalizedString>
#include <QCoreApplication>
#include <QString>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const QString text = ki18n("BLFS").toString();
  if (text != QStringLiteral("BLFS")) return 1;
  std::printf("BLFS_KF6_BASE2_EXEC_OK=%s=%s\n", qVersion(), text.toUtf8().constData());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base2-smoke -B /tmp/blfs-kf6-base2-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base2-smoke-build
OUTPUT="$(LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base2-smoke-build/blfs-kf6-base2-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE2_EXEC_OK=6.9.2=blfs ]]
readelf -h /tmp/blfs-kf6-base2-smoke-build/blfs-kf6-base2-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base2-smoke-build/blfs-kf6-base2-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE2_RESULT=ok\nPACKAGE_COUNT=3\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE2_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\n'
  printf 'PACKAGES=kguiaddons+ki18n+kidletime\n'
  printf 'SMOKE_SCOPE=KLocalizedString;GuiAddons-and-IdleTime-found-and-linked\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'KDNSSD=deferred-avahi-backend\nATTICA_BASE1=preserved\nXFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base2-smoke /tmp/blfs-kf6-base2-smoke-build
