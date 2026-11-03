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
REPORT=/root/blfs-kf6-base19-report.txt
PROGRESS=/root/blfs-kf6-base19-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui Qt6Widgets Qt6DBus Qt6Test; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Completion KF6Config KF6I18n KF6KIO KF6CalendarCore; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ "$(pkg-config --modversion libcanberra)" == 0.30 ]]
[[ ! -e /opt/kf6/lib/cmake/KF6NotifyConfig && ! -e /opt/kf6/lib/cmake/KF6DAV ]]
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
build_kf6() {
  local name="$1"
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE19=%s\n' "$name"
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D BUILD_PYTHON_BINDINGS=OFF \
    -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE19_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
}
build_kf6 knotifyconfig
build_kf6 kdav
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE19_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6NotifyConfig/KF6NotifyConfigConfig.cmake \
  /opt/kf6/lib/libKF6NotifyConfig.so \
  /opt/kf6/lib/cmake/KF6DAV/KF6DAVConfig.cmake \
  /opt/kf6/lib/libKF6DAV.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base19-smoke /tmp/blfs-kf6-base19-smoke-build /tmp/blfs-kf6-base19-runtime
mkdir -p /tmp/blfs-kf6-base19-smoke
cat >/tmp/blfs-kf6-base19-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base19_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6NotifyConfig 6.17.0 REQUIRED CONFIG)
find_package(KF6DAV 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base19-smoke main.cpp)
target_link_libraries(blfs-kf6-base19-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets KF6::NotifyConfig KF6::DAV)
EOF
cat >/tmp/blfs-kf6-base19-smoke/main.cpp <<'EOF'
#include <KDAV/DavItem>
#include <KDAV/DavUrl>
#include <KNotifyConfigWidget>
#include <QApplication>
#include <QByteArray>
#include <QDataStream>
#include <QIODevice>
#include <QString>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  KNotifyConfigWidget widget(nullptr);
  if (widget.isVisible() || !widget.layout()) return 1;
  KDAV::DavUrl url(QUrl(QStringLiteral("https://example.invalid/calendar")), KDAV::CalDav);
  if (url.protocol() != KDAV::CalDav || url.toDisplayString() != QStringLiteral("https://example.invalid/calendar")) return 2;
  KDAV::DavItem item(url, QStringLiteral("text/calendar"), QByteArray("BEGIN:VCALENDAR"), QStringLiteral("etag-1"));
  QByteArray bytes;
  QDataStream writer(&bytes, QIODevice::WriteOnly);
  writer << item;
  QDataStream reader(&bytes, QIODevice::ReadOnly);
  KDAV::DavItem restored;
  reader >> restored;
  if (reader.status() != QDataStream::Ok || restored.url().url() != url.url() || restored.url().protocol() != KDAV::CalDav || restored.contentType() != item.contentType() || restored.data() != item.data() || restored.etag() != item.etag()) return 3;
  std::printf("BLFS_KF6_BASE19_EXEC_OK=%s=notify=widget=dav=data\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base19-smoke -B /tmp/blfs-kf6-base19-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-kf6-base19-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base19-runtime
OUTPUT="$(XDG_RUNTIME_DIR=/tmp/blfs-kf6-base19-runtime QT_QPA_PLATFORM=offscreen \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib /tmp/blfs-kf6-base19-smoke-build/blfs-kf6-base19-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE19_EXEC_OK=6.9.2=notify=widget=dav=data ]]
printf 'NATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\n' "$OUTPUT"
readelf -h /tmp/blfs-kf6-base19-smoke-build/blfs-kf6-base19-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base19-smoke-build/blfs-kf6-base19-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE19_RESULT=ok\nPACKAGE_COUNT=2\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE19_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=knotifyconfig+kdav\nDEPENDENCIES=none\n'
  printf 'KNOTIFYCONFIG=native-widget-unshown\nKDAV=native-data-roundtrip\nCANBERRA=present\n'
  printf 'NETWORK_RUNTIME=not-tested-no-dav-job\nWINDOW_RUNTIME=not-tested-no-window-shown\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nBASE18=preserved-pipeline-136\nBASE17=preserved-pipeline-134\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base19-smoke /tmp/blfs-kf6-base19-smoke-build /tmp/blfs-kf6-base19-runtime
