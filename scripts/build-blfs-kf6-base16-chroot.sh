#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base16-report.txt
PROGRESS=/root/blfs-kf6-base16-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui Qt6Quick Qt6Multimedia; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Baloo KF6Runner KF6FileMetaData; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e /opt/kf6/lib/cmake/KF6Prison && ! -e /usr/include/qrencode.h ]]
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
extract_package libqrencode-4.1.1.tar.gz libqrencode-4.1.1
sh autogen.sh
./configure --prefix=/usr
make
make install
cd /sources; rm -rf libqrencode-4.1.1
printf 'BLFS_KF6_BASE16_DEPENDENCY_BUILT=libqrencode-4.1.1\n' >>"$PROGRESS"
extract_package prison-6.17.0.tar.xz prison-6.17.0
mkdir build; cd build
printf 'BUILD_BLFS_KF6_BASE16=prison\n'
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
cd /sources; rm -rf prison-6.17.0
printf 'BLFS_KF6_BASE16_BUILT=prison-6.17.0\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE16_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(grep -c '^BLFS_KF6_BASE16_DEPENDENCY_BUILT=' "$PROGRESS")" -eq 1 ]]
for path in \
  /usr/include/qrencode.h \
  /usr/lib/libqrencode.so \
  /opt/kf6/lib/cmake/KF6Prison/KF6PrisonConfig.cmake \
  /opt/kf6/lib/libKF6Prison.so \
  /opt/kf6/lib/qml/org/kde/prison/qmldir; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base16-smoke /tmp/blfs-kf6-base16-smoke-build /tmp/blfs-kf6-base16-runtime
mkdir -p /tmp/blfs-kf6-base16-smoke
cat >/tmp/blfs-kf6-base16-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base16_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Quick Multimedia)
find_package(KF6Prison 6.17.0 REQUIRED CONFIG)
find_path(QRENCODE_INCLUDE_DIR NAMES qrencode.h REQUIRED)
find_library(QRENCODE_LIBRARY NAMES qrencode REQUIRED)
add_executable(blfs-kf6-base16-smoke main.cpp)
target_include_directories(blfs-kf6-base16-smoke PRIVATE ${QRENCODE_INCLUDE_DIR})
target_link_libraries(blfs-kf6-base16-smoke PRIVATE Qt6::Core Qt6::Gui KF6::Prison ${QRENCODE_LIBRARY})
EOF
cat >/tmp/blfs-kf6-base16-smoke/main.cpp <<'EOF'
#include <Prison/Barcode>
#include <Prison/Prison>
#include <QCoreApplication>
#include <QImage>
#include <QSizeF>
#include <QString>
#include <QtGlobal>
#include <qrencode.h>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  QRcode *raw = QRcode_encodeString("native", 0, QR_ECLEVEL_L, QR_MODE_8, 1);
  if (!raw || raw->width <= 0 || !raw->data) return 1;
  QRcode_free(raw);
  auto barcode = Prison::Barcode::create(Prison::QRCode);
  if (!barcode || barcode->format() != Prison::QRCode) return 2;
  barcode->setData(QStringLiteral("native"));
  if (barcode->data() != QStringLiteral("native") || barcode->minimumSize().isEmpty()) return 3;
  QImage image = barcode->toImage(QSizeF(128, 128));
  if (image.isNull() || image.width() <= 0 || image.height() <= 0) return 4;
  std::printf("BLFS_KF6_BASE16_EXEC_OK=%s=qrencode=ok=prison=qr\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base16-smoke -B /tmp/blfs-kf6-base16-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base16-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base16-runtime
OUTPUT="$(XDG_RUNTIME_DIR=/tmp/blfs-kf6-base16-runtime QT_QPA_PLATFORM=offscreen \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib /tmp/blfs-kf6-base16-smoke-build/blfs-kf6-base16-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE16_EXEC_OK=6.9.2=qrencode=ok=prison=qr ]]
readelf -h /tmp/blfs-kf6-base16-smoke-build/blfs-kf6-base16-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base16-smoke-build/blfs-kf6-base16-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE16_RESULT=ok\nPACKAGE_COUNT=1\nDEPENDENCY_COUNT=1\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE16_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=prison\nDEPENDENCIES=libqrencode\n'
  printf 'QRENCODE=native-encode-free\nPRISON=native-qrcode-image-no-file\n'
  printf 'DMTX=optional-not-built\nZXING=optional-not-built\nSCANNER=compiled-not-run\nCAMERA_RUNTIME=not-tested-no-device-access\n'
  printf 'QRENCODE_TEST_SUITE=not-run-SDL2-absent\nPRISON_TEST_SUITE=not-run-BUILD_TESTING_OFF\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE15=preserved-pipeline-128\nBASE14=preserved-pipeline-126\nBASE13=preserved-pipeline-123\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base16-smoke /tmp/blfs-kf6-base16-smoke-build /tmp/blfs-kf6-base16-runtime
