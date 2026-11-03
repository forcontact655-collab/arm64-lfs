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
REPORT=/root/blfs-kf6-base15-report.txt
PROGRESS=/root/blfs-kf6-base15-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6DBus Qt6Qml Qt6Quick Qt6Test; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6FileMetaData KF6Runner KF6CoreAddons KF6KIO; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e /opt/kf6/lib/cmake/KF6Baloo && ! -e /usr/include/lmdb.h ]]
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
extract_package LMDB_0.9.33.tar.gz lmdb-LMDB_0.9.33
cd libraries/liblmdb
make
sed -i 's| liblmdb.a||' Makefile
make prefix=/usr install
cd /sources; rm -rf lmdb-LMDB_0.9.33
printf 'BLFS_KF6_BASE15_DEPENDENCY_BUILT=lmdb-0.9.33\n' >>"$PROGRESS"
extract_package baloo-6.17.0.tar.xz baloo-6.17.0
mkdir build; cd build
printf 'BUILD_BLFS_KF6_BASE15=baloo\n'
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
cd /sources; rm -rf baloo-6.17.0
printf 'BLFS_KF6_BASE15_BUILT=baloo-6.17.0\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE15_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(grep -c '^BLFS_KF6_BASE15_DEPENDENCY_BUILT=' "$PROGRESS")" -eq 1 ]]
for path in \
  /usr/include/lmdb.h \
  /usr/lib/liblmdb.so \
  /opt/kf6/lib/cmake/KF6Baloo/KF6BalooConfig.cmake \
  /opt/kf6/lib/libKF6Baloo.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base15-smoke /tmp/blfs-kf6-base15-smoke-build /tmp/blfs-kf6-base15-lmdb /tmp/blfs-kf6-base15-runtime
mkdir -p /tmp/blfs-kf6-base15-smoke
cat >/tmp/blfs-kf6-base15-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base15_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core DBus Widgets Qml Quick Test)
find_package(KF6Baloo 6.17.0 REQUIRED CONFIG)
find_path(LMDB_INCLUDE_DIR NAMES lmdb.h REQUIRED)
find_library(LMDB_LIBRARY NAMES lmdb REQUIRED)
add_executable(blfs-kf6-base15-smoke main.cpp)
target_include_directories(blfs-kf6-base15-smoke PRIVATE ${LMDB_INCLUDE_DIR})
target_link_libraries(blfs-kf6-base15-smoke PRIVATE Qt6::Core Qt6::DBus Qt6::Widgets KF6::Baloo ${LMDB_LIBRARY})
EOF
cat >/tmp/blfs-kf6-base15-smoke/main.cpp <<'EOF'
#include <Baloo/Query>
#include <QCoreApplication>
#include <QString>
#include <QtGlobal>
#include <lmdb.h>
#include <cstdio>
#include <cstring>
#include <sys/stat.h>
#include <unistd.h>
#define LMDB_CHECK(call) do { int rc = (call); if (rc != MDB_SUCCESS) { std::fprintf(stderr, "LMDB: %s\n", mdb_strerror(rc)); return 2; } } while (0)
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const char *directory = "/tmp/blfs-kf6-base15-lmdb";
  mkdir(directory, 0700);
  MDB_env *environment = nullptr;
  LMDB_CHECK(mdb_env_create(&environment));
  LMDB_CHECK(mdb_env_set_mapsize(environment, 1024 * 1024));
  LMDB_CHECK(mdb_env_open(environment, directory, 0, 0600));
  MDB_txn *transaction = nullptr;
  MDB_dbi database = 0;
  char key_data[] = "native";
  char value_data[] = "lmdb";
  MDB_val key{sizeof(key_data) - 1, key_data};
  MDB_val value{sizeof(value_data) - 1, value_data};
  LMDB_CHECK(mdb_txn_begin(environment, nullptr, 0, &transaction));
  LMDB_CHECK(mdb_dbi_open(transaction, nullptr, 0, &database));
  LMDB_CHECK(mdb_put(transaction, database, &key, &value, 0));
  LMDB_CHECK(mdb_txn_commit(transaction));
  transaction = nullptr;
  MDB_val result{};
  LMDB_CHECK(mdb_txn_begin(environment, nullptr, MDB_RDONLY, &transaction));
  LMDB_CHECK(mdb_get(transaction, database, &key, &result));
  if (result.mv_size != 4 || std::memcmp(result.mv_data, "lmdb", 4) != 0) return 3;
  mdb_txn_abort(transaction);
  mdb_env_close(environment);
  unlink("/tmp/blfs-kf6-base15-lmdb/data.mdb");
  unlink("/tmp/blfs-kf6-base15-lmdb/lock.mdb");
  rmdir(directory);
  Baloo::Query query;
  query.setSearchString(QStringLiteral("native"));
  query.setLimit(1);
  if (query.searchString() != QStringLiteral("native") || query.limit() != 1) return 4;
  std::printf("BLFS_KF6_BASE15_EXEC_OK=%s=lmdb=rw=baloo=query\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base15-smoke -B /tmp/blfs-kf6-base15-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base15-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base15-runtime
OUTPUT="$(XDG_RUNTIME_DIR=/tmp/blfs-kf6-base15-runtime QT_QPA_PLATFORM=offscreen \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib /tmp/blfs-kf6-base15-smoke-build/blfs-kf6-base15-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE15_EXEC_OK=6.9.2=lmdb=rw=baloo=query ]]
readelf -h /tmp/blfs-kf6-base15-smoke-build/blfs-kf6-base15-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base15-smoke-build/blfs-kf6-base15-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE15_RESULT=ok\nPACKAGE_COUNT=1\nDEPENDENCY_COUNT=1\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE15_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=baloo\nDEPENDENCIES=lmdb\n'
  printf 'LMDB=native-temp-read-write\nBALOO=native-query-no-indexer-exec\n'
  printf 'LMDB_TEST_SUITE=not-provided\nBALOO_TEST_SUITE=not-run-BUILD_TESTING_OFF\nINDEXER_RUNTIME=not-tested-no-daemon\n'
  printf 'FILE_IO=lmdb-temp-only-no-user-files\nLMDB_SOURCE=upstream-github-tag-LMDB_0.9.33\n'
  printf 'BASE14=preserved-pipeline-126\nBASE13=preserved-pipeline-123\nBASE12=preserved-pipeline-121\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base15-smoke /tmp/blfs-kf6-base15-smoke-build /tmp/blfs-kf6-base15-lmdb /tmp/blfs-kf6-base15-runtime
