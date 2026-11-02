#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qttools1-report.txt
PROGRESS=/root/blfs-qttools1-progress.txt
CONFIG_SUMMARY=/root/blfs-qttools1-config-summary.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/g++ ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/ninja ]]
[[ -x "$QT6PREFIX/bin/qmake6" ]]
[[ -x "$QT6PREFIX/bin/qt-configure-module" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake" ]]
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=qttools-everywhere-src-6.9.2.tar.xz
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == qttools-everywhere-src-6.9.2 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
mkdir "$SOURCES/$PACKAGE_DIR/build"
cd "$SOURCES/$PACKAGE_DIR/build"
printf 'BUILD_BLFS_QTTOOLS1=qttools-linguist\n'
/opt/qt6/bin/qt-configure-module "$SOURCES/$PACKAGE_DIR" -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_BUILD_EXAMPLES=OFF \
  -DQT_BUILD_TESTS=OFF \
  -DQT_BUILD_MANUAL_TESTS=OFF \
  -DQT_GENERATE_SBOM=OFF \
  -DFEATURE_linguist=ON \
  -DFEATURE_assistant=OFF \
  -DFEATURE_designer=OFF \
  -DFEATURE_distancefieldgenerator=OFF \
  -DFEATURE_pixeltool=OFF \
  -DFEATURE_qdbus=OFF \
  -DFEATURE_qtdiag=OFF \
  -DFEATURE_qtplugininfo=OFF \
  -DFEATURE_qtattributionsscanner=OFF \
  -DFEATURE_qdoc=OFF \
  -DFEATURE_clang=OFF \
  -DFEATURE_clangcpp=OFF
[[ -s config.summary ]]
ninja
ninja install
cp config.summary "$CONFIG_SUMMARY"
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_QTTOOLS1_BUILT=qttools-everywhere-src-6.9.2-linguist\n' >>"$PROGRESS"
find "$QT6PREFIX" -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_QTTOOLS1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -x "$QT6PREFIX/bin/lrelease" ]]
[[ -x "$QT6PREFIX/bin/lconvert" ]]
[[ -x "$QT6PREFIX/bin/lupdate" ]]
[[ -f "$QT6PREFIX/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake" ]]
"$QT6PREFIX/bin/lupdate" -version >/dev/null

rm -rf /tmp/blfs-qttools1-smoke /tmp/blfs-qttools1-smoke-build
mkdir -p /tmp/blfs-qttools1-smoke
cat >/tmp/blfs-qttools1-smoke/blfs_ru.ts <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="ru_RU">
<context>
  <name>Blfs</name>
  <message>
    <source>Continue</source>
    <translation>Продолжить</translation>
  </message>
</context>
</TS>
EOF
"$QT6PREFIX/bin/lrelease" /tmp/blfs-qttools1-smoke/blfs_ru.ts \
  -qm /tmp/blfs-qttools1-smoke/blfs_ru.qm
[[ -s /tmp/blfs-qttools1-smoke/blfs_ru.qm ]]
"$QT6PREFIX/bin/lconvert" -i /tmp/blfs-qttools1-smoke/blfs_ru.qm \
  -o /tmp/blfs-qttools1-smoke/blfs_roundtrip.ts
grep -q 'Продолжить' /tmp/blfs-qttools1-smoke/blfs_roundtrip.ts

cat >/tmp/blfs-qttools1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qttools1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core LinguistTools)
if(NOT TARGET Qt6::lrelease OR NOT TARGET Qt6::lconvert OR NOT TARGET Qt6::lupdate)
  message(FATAL_ERROR "Qt6 LinguistTools executable targets are missing")
endif()
add_executable(blfs-qttools1-smoke main.cpp)
target_link_libraries(blfs-qttools1-smoke PRIVATE Qt6::Core)
EOF
cat >/tmp/blfs-qttools1-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <QString>
#include <QTranslator>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication application(argc, argv);
  QTranslator translator;
  if (!translator.load(QStringLiteral("/tmp/blfs-qttools1-smoke/blfs_ru.qm"))) return 1;
  if (!QCoreApplication::installTranslator(&translator)) return 2;
  const QString translated = QCoreApplication::translate("Blfs", "Continue");
  if (translated != QString::fromUtf8("Продолжить")) return 3;
  std::printf("BLFS_QTTOOLS1_EXEC_OK=%s=translation-ok\n", qVersion());
  QCoreApplication::removeTranslator(&translator);
  return 0;
}
EOF
cmake -S /tmp/blfs-qttools1-smoke -B /tmp/blfs-qttools1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qttools1-smoke-build
OUTPUT="$(/tmp/blfs-qttools1-smoke-build/blfs-qttools1-smoke)"
[[ "$OUTPUT" == BLFS_QTTOOLS1_EXEC_OK=6.9.2=translation-ok ]]
readelf -h /tmp/blfs-qttools1-smoke-build/blfs-qttools1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qttools1-smoke-build/blfs-qttools1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_QTTOOLS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QTTOOLS1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\n'
  printf 'QTTOOLS=6.9.2\n'
  printf 'ECM=6.17.0\n'
  printf 'LINGUIST_TOOLS=present\n'
  printf 'TRANSLATION_SMOKE=%s\n' "$OUTPUT"
  printf 'QDOC=disabled\n'
  printf 'DESIGNER=disabled\n'
  printf 'ASSISTANT=disabled\n'
  printf 'KDE=ecm-only\n'
  printf 'KDE_FRAMEWORKS=absent\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qttools1-smoke /tmp/blfs-qttools1-smoke-build
