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
REPORT=/root/blfs-kf6-base8-report.txt
PROGRESS=/root/blfs-kf6-base8-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ "$(pkg-config --modversion gpg-error)" == 1.55 ]]
[[ "$(pkg-config --modversion libgcrypt)" == 1.11.2 ]]
for path in KF6IconThemes KF6Notifications KF6JobWidgets KF6TextWidgets KF6XmlGui KF6Bookmarks; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6Wallet KF6KDED KF6KIO; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
[[ -e /opt/qt6/lib/libqca-qt6.so && -f /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake ]]
[[ ! -e /usr/lib/libsecret-1.so ]]
[[ ! -e /usr/lib/python3.13/site-packages/dbus/__init__.py ]]
[[ ! -e /usr/lib/python3.13/site-packages/gi/__init__.py ]]
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
extract_package dbus-python-1.4.0.tar.xz dbus-python-1.4.0
printf 'BUILD_BLFS_KF6_BASE8_DEPENDENCY=dbus-python\n'
mkdir bld; cd bld
meson setup --prefix=/usr --libdir=lib --buildtype=release \
  -D doc=disabled -D tests=auto -D python=python3 ..
ninja
ninja test
ninja install
cd /sources; rm -rf dbus-python-1.4.0
python3 -c 'import dbus; assert dbus.__version__ == "1.4.0"'
printf 'BLFS_KF6_BASE8_DEPENDENCY_BUILT=dbus-python-1.4.0\n' >>"$PROGRESS"

extract_package pygobject-3.52.3.tar.gz pygobject-3.52.3
printf 'BUILD_BLFS_KF6_BASE8_DEPENDENCY=pygobject\n'
mkdir bld; cd bld
meson setup --prefix=/usr --libdir=lib --buildtype=release \
  -D pycairo=disabled -D tests=false -D python=python3 ..
ninja
ninja install
cd /sources; rm -rf pygobject-3.52.3
/sbin/ldconfig
python3 -c 'from gi.repository import GLib; assert GLib.MAJOR_VERSION == 2'
printf 'BLFS_KF6_BASE8_DEPENDENCY_BUILT=pygobject-3.52.3\n' >>"$PROGRESS"

extract_package libsecret-0.21.7.tar.xz libsecret-0.21.7
printf 'BUILD_BLFS_KF6_BASE8_DEPENDENCY=libsecret\n'
mkdir bld; cd bld
meson setup --prefix=/usr --buildtype=release \
  -D gtk_doc=false -D manpage=false -D introspection=false -D vapi=false \
  -D crypto=libgcrypt ..
ninja
ninja test
ninja install
cd /sources; rm -rf libsecret-0.21.7
printf 'BLFS_KF6_BASE8_DEPENDENCY_BUILT=libsecret-0.21.7\n' >>"$PROGRESS"
/sbin/ldconfig
packages=(kwallet kded kio)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE8=%s\n' "$name"
  cmake_args=(
    -D CMAKE_INSTALL_PREFIX=/opt/kf6
    -D CMAKE_INSTALL_LIBEXECDIR=libexec
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
    -D CMAKE_SKIP_INSTALL_RPATH=ON
    -D CMAKE_BUILD_TYPE=Release
    -D BUILD_TESTING=OFF
    -D BUILD_PYTHON_BINDINGS=OFF
  )
  if [[ "$name" == kwallet ]]; then
    cmake_args+=(-D BUILD_KSECRETD=ON -D BUILD_KWALLETD=ON -D BUILD_KWALLET_QUERY=ON -D CMAKE_DISABLE_FIND_PACKAGE_Gpgmepp=ON)
  fi
  if [[ "$name" == kio ]]; then cmake_args+=(-D WITH_WAYLAND=OFF); fi
  cmake -G Ninja "${cmake_args[@]}" -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE8_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE8_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ "$(grep -c '^BLFS_KF6_BASE8_DEPENDENCY_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ -e /usr/lib/libsecret-1.so && -f /usr/lib/pkgconfig/libsecret-1.pc ]]
for path in \
  /opt/kf6/lib/cmake/KF6Wallet/KF6WalletConfig.cmake \
  /opt/kf6/lib/cmake/KF6KDED/KF6KDEDConfig.cmake \
  /opt/kf6/lib/cmake/KF6KIO/KF6KIOConfig.cmake \
  /opt/kf6/lib/libKF6Wallet.so /opt/kf6/bin/kded6 \
  /opt/kf6/lib/libKF6KIOCore.so /opt/kf6/lib/libKF6KIOGui.so \
  /opt/kf6/lib/libKF6KIOWidgets.so /opt/kf6/lib/libKF6KIOFileWidgets.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base8-smoke /tmp/blfs-kf6-base8-smoke-build /tmp/blfs-kf6-base8-config
mkdir -p /tmp/blfs-kf6-base8-smoke /tmp/blfs-kf6-base8-config
cat >/tmp/blfs-kf6-base8-config/kwalletrc <<'EOF'
[Wallet]
Enabled=false
EOF
cat >/tmp/blfs-kf6-base8-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base8_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets DBus)
find_package(KF6Wallet 6.17.0 REQUIRED CONFIG)
find_package(KF6KDED 6.17.0 REQUIRED CONFIG)
find_package(KF6KIO 6.17.0 REQUIRED CONFIG)
if(NOT KDED_DBUS_INTERFACE MATCHES "/org.kde.kded6.xml$" OR NOT EXISTS "${KDED_DBUS_INTERFACE}")
  message(FATAL_ERROR "KDED D-Bus interface was not installed")
endif()
add_executable(blfs-kf6-base8-smoke main.cpp)
target_link_libraries(blfs-kf6-base8-smoke PRIVATE Qt6::Core KF6::Wallet KF6::KIOCore)
EOF
cat >/tmp/blfs-kf6-base8-smoke/main.cpp <<'EOF'
#include <KWallet>
#include <KFileItem>
#include <QCoreApplication>
#include <QString>
#include <QUrl>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-kf6-base8-smoke"));
  if (KWallet::Wallet::isEnabled()) return 1;
  const QUrl url = QUrl::fromLocalFile(QStringLiteral("/tmp/blfs-kf6-base8"));
  KFileItem item(url, QStringLiteral("application/octet-stream"), 0100644);
  if (item.url() != url || item.mimeType() != QStringLiteral("application/octet-stream") || !item.isFile()) return 2;
  std::printf("BLFS_KF6_BASE8_EXEC_OK=%s=%s=%d\n", qVersion(), item.mimeType().toUtf8().constData(), KWallet::Wallet::isEnabled() ? 1 : 0);
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base8-smoke -B /tmp/blfs-kf6-base8-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base8-smoke-build
OUTPUT="$(XDG_CONFIG_HOME=/tmp/blfs-kf6-base8-config LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base8-smoke-build/blfs-kf6-base8-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE8_EXEC_OK=6.9.2=application/octet-stream=0 ]]
KDED_OUTPUT="$(QT_QPA_PLATFORM=offscreen LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /opt/kf6/bin/kded6 --version)"
grep -q '6.17.0' <<<"$KDED_OUTPUT"
readelf -h /tmp/blfs-kf6-base8-smoke-build/blfs-kf6-base8-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base8-smoke-build/blfs-kf6-base8-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE8_RESULT=ok\nPACKAGE_COUNT=3\nDEPENDENCY_COUNT=3\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE8_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nDEPENDENCIES=dbus-python+pygobject+libsecret\nPACKAGES=kwallet+kded+kio\n'
  printf 'DBUS_PYTHON_TEST_SUITE=passed-with-gi-skips\nPYGOBJECT_TEST_SUITE=not-run-tests-disabled-headless\nPYGOBJECT_NATIVE_IMPORT=GLib-ok\n'
  printf 'LIBSECRET_TEST_SUITE=passed\nLIBSECRET_RUNTIME=not-tested-no-gnome-keyring\nLIBSECRET_INTROSPECTION=disabled\n'
  printf 'KWALLET=config-disabled-native-api-no-daemon\nKDED=version-only-no-daemon\nKIO=native-file-item-ok\n'
  printf 'WALLET_RUNTIME=not-tested-no-open\nKDED_RUNTIME=not-tested-no-start\nKIO_RUNTIME=not-tested-no-job\n'
  printf 'KIO_WAYLAND=disabled\nACL_RUNTIME=not-tested\nGPGMEPP=optional-disabled\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nSECURITY_DEPS1=preserved-pipeline-109\n'
  printf 'BASE7=preserved-pipeline-106\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base8-smoke /tmp/blfs-kf6-base8-smoke-build /tmp/blfs-kf6-base8-config
