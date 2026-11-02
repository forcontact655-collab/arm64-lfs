#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qt5compat1-report.txt
PROGRESS=/root/blfs-qt5compat1-progress.txt
CONFIG_SUMMARY=/root/blfs-qt5compat1-config-summary.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -x "$QT6PREFIX/bin/qmake6" ]]
[[ -x "$QT6PREFIX/bin/qt-configure-module" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake" ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=qt5compat-everywhere-src-6.9.2.tar.xz
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == qt5compat-everywhere-src-6.9.2 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
mkdir "$SOURCES/$PACKAGE_DIR/build"
cd "$SOURCES/$PACKAGE_DIR/build"
printf 'BUILD_BLFS_QT5COMPAT1=qt5compat\n'
/opt/qt6/bin/qt-configure-module "$SOURCES/$PACKAGE_DIR" -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_BUILD_EXAMPLES=OFF \
  -DQT_BUILD_TESTS=OFF \
  -DQT_BUILD_MANUAL_TESTS=OFF \
  -DQT_GENERATE_SBOM=OFF
[[ -s config.summary ]]
ninja
ninja install
cp config.summary "$CONFIG_SUMMARY"
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_QT5COMPAT1_BUILT=qt5compat-everywhere-src-6.9.2\n' >>"$PROGRESS"
find "$QT6PREFIX" -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_QT5COMPAT1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake" ]]
[[ -d "$QT6PREFIX/qml/Qt5Compat/GraphicalEffects" ]]

rm -rf /tmp/blfs-qt5compat1-smoke /tmp/blfs-qt5compat1-smoke-build
mkdir -p /tmp/blfs-qt5compat1-smoke
cat >/tmp/blfs-qt5compat1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qt5compat1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Core5Compat)
add_executable(blfs-qt5compat1-smoke main.cpp)
target_link_libraries(blfs-qt5compat1-smoke PRIVATE Qt6::Core Qt6::Core5Compat)
EOF
cat >/tmp/blfs-qt5compat1-smoke/main.cpp <<'EOF'
#include <QRegExp>
#include <QString>
#include <QtGlobal>
#include <cstdio>
int main() {
  const QRegExp expression("^blfs-([0-9]+)$");
  if (expression.indexIn(QStringLiteral("blfs-28")) != 0) return 1;
  if (expression.cap(1) != QStringLiteral("28")) return 2;
  std::printf("BLFS_QT5COMPAT1_EXEC_OK=%s\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-qt5compat1-smoke -B /tmp/blfs-qt5compat1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qt5compat1-smoke-build
OUTPUT="$(/tmp/blfs-qt5compat1-smoke-build/blfs-qt5compat1-smoke)"
[[ "$OUTPUT" == BLFS_QT5COMPAT1_EXEC_OK=6.9.2 ]]
readelf -h /tmp/blfs-qt5compat1-smoke-build/blfs-qt5compat1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qt5compat1-smoke-build/blfs-qt5compat1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_QT5COMPAT1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QT5COMPAT1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QTDECLARATIVE=6.9.2\n'
  printf 'QT5COMPAT=6.9.2\n'
  printf 'CORE5_SMOKE=%s\n' "$OUTPUT"
  printf 'GRAPHICAL_EFFECTS=present\n'
  printf 'BOOTABLE=no\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qt5compat1-smoke /tmp/blfs-qt5compat1-smoke-build
