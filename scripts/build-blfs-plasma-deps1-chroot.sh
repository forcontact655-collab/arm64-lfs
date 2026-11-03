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
REPORT=/root/blfs-plasma-deps1-report.txt
PROGRESS=/root/blfs-plasma-deps1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/meson ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -x /opt/qt6/bin/qt-configure-module && -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake ]]
for path in Qt6Core Qt6Network Qt6DBus Qt6Qml Qt6Quick Qt6Test; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e /opt/qt6/lib/cmake/Qt6WebSockets && ! -e /opt/qt6/lib/cmake/QCoro6 ]]
[[ ! -e /usr/include/boost/version.hpp && ! -e /usr/include/libnl3 && ! -e /usr/include/libqalculate ]]
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

# QtWebSockets is needed for the full QCoro build used by Plasma consumers.
extract_package qtwebsockets-everywhere-src-6.9.2.tar.xz qtwebsockets-everywhere-src-6.9.2
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS1=qtwebsockets\n'
/opt/qt6/bin/qt-configure-module /sources/qtwebsockets-everywhere-src-6.9.2 -- \
  -DCMAKE_BUILD_TYPE=Release -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
  -DQT_BUILD_MANUAL_TESTS=OFF -DQT_GENERATE_SBOM=OFF
[[ -s config.summary ]]
ninja
ninja install
cd /sources; rm -rf qtwebsockets-everywhere-src-6.9.2
printf 'BLFS_PLASMA_DEPS1_BUILT=qtwebsockets-6.9.2\n' >>"$PROGRESS"

extract_package qcoro-0.12.0.tar.gz qcoro-0.12.0
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS1=qcoro\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/qt6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D "CMAKE_PREFIX_PATH=/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -D QCORO_BUILD_TESTING=OFF \
  -D QCORO_BUILD_EXAMPLES=OFF \
  -D QCORO_WITH_QTWEBSOCKETS=ON \
  -D BUILD_SHARED_LIBS=ON \
  -W no-dev ..
ninja
ninja install
cd /sources; rm -rf qcoro-0.12.0
printf 'BLFS_PLASMA_DEPS1_BUILT=qcoro-0.12.0\n' >>"$PROGRESS"

extract_package boost-1.89.0-b2-nodocs.tar.xz boost-1.89.0
printf 'BUILD_BLFS_PLASMA_DEPS1=boost\n'
./bootstrap.sh --prefix=/usr --with-python=python3
./b2 stage -j"$(nproc)" threading=multi link=shared
rm -rf /usr/lib/cmake/[Bb]oost*
./b2 install threading=multi link=shared
cd /sources; rm -rf boost-1.89.0
printf 'BLFS_PLASMA_DEPS1_BUILT=boost-1.89.0\n' >>"$PROGRESS"

extract_package libnl-3.11.0.tar.gz libnl-3.11.0
printf 'BUILD_BLFS_PLASMA_DEPS1=libnl\n'
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
cd /sources; rm -rf libnl-3.11.0
printf 'BLFS_PLASMA_DEPS1_BUILT=libnl-3.11.0\n' >>"$PROGRESS"

extract_package libqalculate-5.7.0.tar.gz libqalculate-5.7.0
printf 'BUILD_BLFS_PLASMA_DEPS1=libqalculate\n'
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libqalculate-5.7.0
make
make install
rm -f /usr/lib/libqalculate.la
cd /sources; rm -rf libqalculate-5.7.0
printf 'BLFS_PLASMA_DEPS1_BUILT=libqalculate-5.7.0\n' >>"$PROGRESS"

find /opt/qt6 -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA_DEPS1_BUILT=' "$PROGRESS")" -eq 5 ]]
for path in \
  /opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake \
  /opt/qt6/lib/libQt6WebSockets.so \
  /opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake \
  /opt/qt6/lib/libQCoro6Core.so \
  /opt/qt6/lib/libQCoro6WebSockets.so \
  /usr/include/boost/version.hpp \
  /usr/lib/libboost_filesystem.so \
  /usr/include/libnl3/netlink/socket.h \
  /usr/lib/libnl-3.so \
  /usr/include/libqalculate/qalculate.h \
  /usr/lib/libqalculate.so; do [[ -e "$path" ]]; done

rm -rf /tmp/blfs-plasma-deps1-smoke /tmp/blfs-plasma-deps1-smoke-build /tmp/blfs-plasma-deps1-smoke-stderr.log
mkdir -p /tmp/blfs-plasma-deps1-smoke
cat >/tmp/blfs-plasma-deps1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma_deps1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Network WebSockets)
find_package(QCoro6 0.12.0 REQUIRED COMPONENTS Core)
find_package(Boost 1.89.0 REQUIRED COMPONENTS filesystem)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBNL REQUIRED IMPORTED_TARGET libnl-3.0)
pkg_check_modules(QALC REQUIRED IMPORTED_TARGET libqalculate)
add_executable(blfs-plasma-deps1-smoke main.cpp)
target_compile_features(blfs-plasma-deps1-smoke PRIVATE cxx_std_20)
target_link_libraries(blfs-plasma-deps1-smoke PRIVATE
  Qt6::Core Qt6::Network Qt6::WebSockets QCoro6::Core Boost::filesystem
  PkgConfig::LIBNL PkgConfig::QALC)
EOF
cat >/tmp/blfs-plasma-deps1-smoke/main.cpp <<'EOF'
#include <QCoro/QCoroTask>
#include <QCoreApplication>
#include <QHostAddress>
#include <QString>
#include <QWebSocketServer>
#include <boost/filesystem.hpp>
#include <libqalculate/qalculate.h>
#include <netlink/socket.h>
#include <QtGlobal>
#include <cstdio>
#include <string>
#include <utility>
QCoro::Task<int> answer() { co_return 42; }
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-plasma-deps1-smoke"));
  auto task = answer();
  if (QCoro::waitFor(std::move(task)) != 42) {
    std::fprintf(stderr, "QCORO_SMOKE_FAILED\n");
    return 1;
  }
  QWebSocketServer server(QStringLiteral("native"), QWebSocketServer::NonSecureMode);
  if (!server.listen(QHostAddress::LocalHost, 0) || server.serverPort() == 0) {
    std::fprintf(stderr, "WEBSOCKETS_SMOKE_FAILED %s\n", qPrintable(server.errorString()));
    return 2;
  }
  server.close();
  const boost::filesystem::path path("/tmp/native");
  if (path.filename().string() != "native") {
    std::fprintf(stderr, "BOOST_SMOKE_FAILED\n");
    return 3;
  }
  struct nl_sock *socket = nl_socket_alloc();
  if (!socket) {
    std::fprintf(stderr, "LIBNL_SMOKE_FAILED\n");
    return 4;
  }
  nl_socket_free(socket);
  new Calculator();
  const std::string result = CALCULATOR->calculateAndPrint("2 + 2", 2000);
  if (result != "4") {
    std::fprintf(stderr, "QALCULATE_SMOKE_FAILED result=%s\n", result.c_str());
    return 5;
  }
  std::printf("BLFS_PLASMA_DEPS1_EXEC_OK=%s=websockets=listen=qcoro=42=boost=path=libnl=alloc=qalculate=4\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma-deps1-smoke -B /tmp/blfs-plasma-deps1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma-deps1-smoke-build
set +e
OUTPUT="$(LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib \
  /tmp/blfs-plasma-deps1-smoke-build/blfs-plasma-deps1-smoke \
  2>/tmp/blfs-plasma-deps1-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma-deps1-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA_DEPS1_EXEC_OK=6.9.2=websockets=listen=qcoro=42=boost=path=libnl=alloc=qalculate=4 ]]
readelf -h /tmp/blfs-plasma-deps1-smoke-build/blfs-plasma-deps1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma-deps1-smoke-build/blfs-plasma-deps1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA_DEPS1_RESULT=ok\nPACKAGE_COUNT=5\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=5\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS1_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nQCORO=0.12.0\nBOOST=1.89.0\nLIBNL=3.11.0\nLIBQALCULATE=5.7.0\nPACKAGES=qtwebsockets+qcoro+boost+libnl+libqalculate\nDEPENDENCIES=none\n'
  printf 'QTWEBSOCKETS=native-loopback-listen\nQCORO_SMOKE=native-coroutine-42\nBOOST_SMOKE=native-filesystem-path\nLIBNL_SMOKE=native-socket-alloc-free\nQALCULATE_SMOKE=native-2-plus-2\n'
  printf 'NETWORK_RUNTIME=loopback-only-no-external\nTEST_SUITES=not-run-BUILD_TESTING_OFF\nKIRIGAMI_ADDONS=preserved-pipeline-145\nBASE21=preserved-pipeline-143\nPLASMA=not-built\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma-deps1-smoke /tmp/blfs-plasma-deps1-smoke-build /tmp/blfs-plasma-deps1-smoke-stderr.log
