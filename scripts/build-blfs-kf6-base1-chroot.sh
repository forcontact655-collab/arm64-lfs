#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base1-report.txt
PROGRESS=/root/blfs-kf6-base1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /opt/kf6/lib/cmake/KF6Attica/KF6AtticaConfig.cmake ]]
[[ -f /etc/profile.d/kf6.sh && -f /etc/ld.so.conf.d/kf6.conf ]]
[[ -x /usr/bin/xfce4-terminal ]]
for path in KF6Archive KF6Codecs KF6Config KF6CoreAddons KF6DBusAddons; do
  [[ ! -e "/opt/kf6/lib/cmake/$path" ]]
done
: >"$PROGRESS"
packages=(karchive kcodecs kconfig kcoreaddons kdbusaddons)
for name in "${packages[@]}"; do
  archive="$name-6.17.0.tar.xz"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$name-6.17.0" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  mkdir "$SOURCES/$package_dir/build"
  cd "$SOURCES/$package_dir/build"
  printf 'BUILD_BLFS_KF6_BASE1=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D BUILD_PYTHON_BINDINGS=OFF \
    -W no-dev \
    ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_KF6_BASE1_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE1_BUILT=' "$PROGRESS")" -eq 5 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Archive/KF6ArchiveConfig.cmake \
  /opt/kf6/lib/cmake/KF6Codecs/KF6CodecsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Config/KF6ConfigConfig.cmake \
  /opt/kf6/lib/cmake/KF6CoreAddons/KF6CoreAddonsConfig.cmake \
  /opt/kf6/lib/cmake/KF6DBusAddons/KF6DBusAddonsConfig.cmake \
  /opt/kf6/lib/libKF6Archive.so \
  /opt/kf6/lib/libKF6Codecs.so \
  /opt/kf6/lib/libKF6ConfigCore.so \
  /opt/kf6/lib/libKF6CoreAddons.so \
  /opt/kf6/lib/libKF6DBusAddons.so; do
  [[ -e "$path" ]]
done
for header in KAboutData KCharsets KConfig KArchive KDBusService; do
  find /opt/kf6/include/KF6 -type f -name "$header" -print -quit | grep -q .
done
rm -rf /tmp/blfs-kf6-base1-smoke /tmp/blfs-kf6-base1-smoke-build
mkdir -p /tmp/blfs-kf6-base1-smoke
cat >/tmp/blfs-kf6-base1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core)
find_package(KF6Archive 6.17.0 REQUIRED CONFIG)
find_package(KF6Codecs 6.17.0 REQUIRED CONFIG)
find_package(KF6Config 6.17.0 REQUIRED CONFIG)
find_package(KF6CoreAddons 6.17.0 REQUIRED CONFIG)
find_package(KF6DBusAddons 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base1-smoke main.cpp)
target_link_libraries(blfs-kf6-base1-smoke PRIVATE
  Qt6::Core KF6::Archive KF6::Codecs KF6::ConfigCore KF6::CoreAddons KF6::DBusAddons)
EOF
cat >/tmp/blfs-kf6-base1-smoke/main.cpp <<'EOF'
#include <KAboutData>
#include <KCharsets>
#include <KConfig>
#include <KConfigGroup>
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  KAboutData about(QStringLiteral("blfs"), QStringLiteral("BLFS"), QStringLiteral("1.0"));
  if (about.componentName() != QStringLiteral("blfs")) return 1;
  QTemporaryDir dir;
  if (!dir.isValid()) return 2;
  {
    KConfig config(dir.filePath(QStringLiteral("smoke.conf")));
    KConfigGroup group = config.group(QStringLiteral("BLFS"));
    group.writeEntry(QStringLiteral("answer"), 42);
    config.sync();
  }
  KConfig reopened(dir.filePath(QStringLiteral("smoke.conf")));
  if (reopened.group(QStringLiteral("BLFS")).readEntry(QStringLiteral("answer"), 0) != 42) return 3;
  const auto encodings = KCharsets::charsets()->availableEncodingNames();
  if (encodings.isEmpty()) return 4;
  std::printf("BLFS_KF6_BASE1_EXEC_OK=%s=%s\n", qVersion(), about.componentName().toUtf8().constData());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base1-smoke -B /tmp/blfs-kf6-base1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base1-smoke-build
OUTPUT="$(LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base1-smoke-build/blfs-kf6-base1-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE1_EXEC_OK=6.9.2=blfs ]]
readelf -h /tmp/blfs-kf6-base1-smoke-build/blfs-kf6-base1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base1-smoke-build/blfs-kf6-base1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=5\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\n'
  printf 'PACKAGES=karchive+kcodecs+kconfig+kcoreaddons+kdbusaddons\n'
  printf 'SMOKE_SCOPE=KAboutData+KConfig-write-read+KCharsets;Archive-and-DBusAddons-found-and-linked\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'KAPIDOX=deferred-documentation-tool\n'
  printf 'ATTICA=preserved\nXFCE_BASE=preserved-from-apps1\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base1-smoke /tmp/blfs-kf6-base1-smoke-build
