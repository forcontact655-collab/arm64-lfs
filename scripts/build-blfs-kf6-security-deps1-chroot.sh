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
REPORT=/root/blfs-kf6-security-deps1-report.txt
PROGRESS=/root/blfs-kf6-security-deps1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/makeinfo ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -s /etc/pki/tls/certs/ca-bundle.crt ]]
for path in KF6IconThemes KF6Notifications KF6JobWidgets KF6TextWidgets KF6XmlGui KF6Bookmarks; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in /usr/lib/libgpg-error.so /usr/lib/libgcrypt.so /opt/qt6/lib/libqca-qt6.so; do [[ ! -e "$path" ]]; done
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
extract_package libgpg-error-1.55.tar.bz2 libgpg-error-1.55
printf 'BUILD_BLFS_KF6_SECURITY_DEPS1=libgpg-error\n'
./configure --prefix=/usr --disable-static
make
make check
make install
install -v -m644 -D README /usr/share/doc/libgpg-error-1.55/README
printf 'BLFS_KF6_SECURITY_DEPS1_BUILT=libgpg-error-1.55\n' >>"$PROGRESS"
extract_package libgcrypt-1.11.2.tar.bz2 libgcrypt-1.11.2
printf 'BUILD_BLFS_KF6_SECURITY_DEPS1=libgcrypt\n'
./configure --prefix=/usr --disable-static
make
make -C doc html
makeinfo --html --no-split -o doc/gcrypt_nochunks.html doc/gcrypt.texi
makeinfo --plaintext -o doc/gcrypt.txt doc/gcrypt.texi
make check
make install
install -v -dm755 /usr/share/doc/libgcrypt-1.11.2
install -v -m644 README doc/{README.apichanges,fips*,libgcrypt*} /usr/share/doc/libgcrypt-1.11.2
install -v -dm755 /usr/share/doc/libgcrypt-1.11.2/html
install -v -m644 doc/gcrypt.html/* /usr/share/doc/libgcrypt-1.11.2/html
install -v -m644 doc/gcrypt_nochunks.html /usr/share/doc/libgcrypt-1.11.2
install -v -m644 doc/gcrypt.{txt,texi} /usr/share/doc/libgcrypt-1.11.2
printf 'BLFS_KF6_SECURITY_DEPS1_BUILT=libgcrypt-1.11.2\n' >>"$PROGRESS"
extract_package qca-2.3.10.tar.xz qca-2.3.10
printf 'BUILD_BLFS_KF6_SECURITY_DEPS1=qca\n'
sed -i 's@cert.pem@certs/ca-bundle.crt@' CMakeLists.txt
mkdir build; cd build
cmake -G Ninja -D CMAKE_INSTALL_PREFIX=/opt/qt6 -D CMAKE_BUILD_TYPE=Release \
  -D "CMAKE_PREFIX_PATH=/opt/qt6" -D QT6=ON -D QCA_INSTALL_IN_QT_PREFIX=ON \
  -D QCA_PREFIX_INSTALL_DIR:PATH=/opt/qt6 -D QCA_PLUGINS_INSTALL_DIR:PATH=/opt/qt6/plugins \
  -D QCA_BINARY_INSTALL_DIR:PATH=/opt/qt6/bin -D QCA_LIBRARY_INSTALL_DIR:PATH=/opt/qt6/lib \
  -D QCA_INCLUDE_INSTALL_DIR:PATH=/opt/qt6/include/Qca-qt6 \
  -D QCA_PRIVATE_INCLUDE_INSTALL_DIR:PATH=/opt/qt6/include/Qca-qt6 \
  -D QCA_FEATURE_INSTALL_DIR:PATH=/opt/qt6/mkspecs/features \
  -D QCA_DOC_INSTALL_DIR:PATH=/opt/qt6/doc/html/qca \
  -D PKGCONFIG_INSTALL_PREFIX:PATH=/opt/qt6/lib/pkgconfig \
  -D QCA_MAN_INSTALL_DIR:PATH=/usr/share/man -D BUILD_TESTS=ON -W no-dev ..
ninja
ninja test
ninja install
printf 'BLFS_KF6_SECURITY_DEPS1_BUILT=qca-2.3.10\n' >>"$PROGRESS"
cd /sources; rm -rf libgpg-error-1.55 libgcrypt-1.11.2 qca-2.3.10
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_SECURITY_DEPS1_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ "$(pkg-config --modversion gpg-error)" == 1.55 ]]
[[ "$(pkg-config --modversion gcrypt)" == 1.11.2 ]]
[[ -f /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake && -x /opt/qt6/bin/qcatool-qt6 ]]
QT_PLUGIN_DIR=/opt/qt6/plugins
[[ -e "$QT_PLUGIN_DIR/crypto/libqca-ossl.so" ]]
rm -rf /tmp/blfs-kf6-security-deps1-smoke /tmp/blfs-kf6-security-deps1-smoke-build
mkdir -p /tmp/blfs-kf6-security-deps1-smoke
cat >/tmp/blfs-kf6-security-deps1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_security_deps1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core)
find_package(Qca-qt6 2.3.10 REQUIRED CONFIG)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GCRYPT REQUIRED IMPORTED_TARGET gcrypt)
pkg_check_modules(GPG_ERROR REQUIRED IMPORTED_TARGET gpg-error)
add_executable(blfs-kf6-security-deps1-smoke main.cpp)
target_link_libraries(blfs-kf6-security-deps1-smoke PRIVATE Qt6::Core ${Qca_LIBRARY} PkgConfig::GCRYPT PkgConfig::GPG_ERROR)
EOF
cat >/tmp/blfs-kf6-security-deps1-smoke/main.cpp <<'EOF'
#include <QtCrypto>
#include <QByteArray>
#include <QCoreApplication>
#include <QString>
#include <gpg-error.h>
#include <gcrypt.h>
#include <cstdio>
int main(int argc, char **argv) {
  QCA::Initializer initializer;
  QCoreApplication app(argc, argv);
  gpg_err_init();
  const char *gpgErrorVersion = gpgrt_check_version("1.55");
  if (!gpgErrorVersion) return 1;
  if (!gcry_check_version("1.11.2")) return 2;
  const QString expected = QStringLiteral("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  unsigned char digest[32];
  gcry_md_hash_buffer(GCRY_MD_SHA256, digest, "abc", 3);
  const QString gcryptHash = QByteArray(reinterpret_cast<const char *>(digest), 32).toHex();
  if (gcryptHash != expected) return 3;
  if (!QCA::isSupported(QStringLiteral("sha256"), QStringLiteral("qca-ossl"))) return 4;
  QCA::Hash hash(QStringLiteral("sha256"), QStringLiteral("qca-ossl"));
  if (hash.hashToString(QCA::SecureArray("abc")) != expected) return 5;
  std::printf("BLFS_KF6_SECURITY_DEPS1_EXEC_OK=%s=%s=1\n", gpgErrorVersion, gcry_check_version(nullptr));
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-security-deps1-smoke -B /tmp/blfs-kf6-security-deps1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/qt6;/opt/kf6"
ninja -C /tmp/blfs-kf6-security-deps1-smoke-build
OUTPUT="$(QCA_PLUGIN_PATH="$QT_PLUGIN_DIR/crypto" LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib \
  /tmp/blfs-kf6-security-deps1-smoke-build/blfs-kf6-security-deps1-smoke)"
[[ "$OUTPUT" == BLFS_KF6_SECURITY_DEPS1_EXEC_OK=1.55=1.11.2=1 ]]
readelf -h /tmp/blfs-kf6-security-deps1-smoke-build/blfs-kf6-security-deps1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-security-deps1-smoke-build/blfs-kf6-security-deps1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_SECURITY_DEPS1_RESULT=ok\nPACKAGE_COUNT=3\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_SECURITY_DEPS1_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PACKAGES=libgpg-error+libgcrypt+qca\nVERSIONS=1.55+1.11.2+2.3.10\n'
  printf 'LIBGPG_ERROR_TEST_SUITE=passed\nLIBGCRYPT_TEST_SUITE=passed\nQCA_TEST_SUITE=passed\n'
  printf 'GCRYPT_SHA256=native-ok\nQCA_SHA256=native-ossl-ok\nQCA_INSTALL_PREFIX=/opt/qt6\n'
  printf 'WALLET_RUNTIME=not-tested\nBASE7=preserved-pipeline-106\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-security-deps1-smoke /tmp/blfs-kf6-security-deps1-smoke-build
