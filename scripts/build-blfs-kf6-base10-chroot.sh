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
REPORT=/root/blfs-kf6-base10-report.txt
PROGRESS=/root/blfs-kf6-base10-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6Declarative KF6KCMUtils KF6Kirigami KF6Wallet KF6KDED KF6KIO; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6Syndication KF6NewStuff KF6NewStuffCore KF6FrameworkIntegration; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
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
packages=(syndication knewstuff frameworkintegration)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE10=%s\n' "$name"
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
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE10_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE10_BUILT=' "$PROGRESS")" -eq 3 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Syndication/KF6SyndicationConfig.cmake \
  /opt/kf6/lib/cmake/KF6NewStuff/KF6NewStuffConfig.cmake \
  /opt/kf6/lib/cmake/KF6NewStuffCore/KF6NewStuffCoreConfig.cmake \
  /opt/kf6/lib/cmake/KF6FrameworkIntegration/KF6FrameworkIntegrationConfig.cmake \
  /opt/kf6/lib/libKF6Syndication.so \
  /opt/kf6/lib/libKF6NewStuffCore.so \
  /opt/kf6/lib/libKF6NewStuffWidgets.so \
  /opt/kf6/lib/libKF6Style.so \
  /opt/kf6/lib/qml/org/kde/newstuff/qmldir; do [[ -e "$path" ]]; done
find /opt/kf6 -type f -name knshandler -print -quit | grep -q .
find /opt/kf6 -type f -name 'FrameworkIntegrationPlugin.so' -print -quit | grep -q .
rm -rf /tmp/blfs-kf6-base10-smoke /tmp/blfs-kf6-base10-smoke-build /tmp/blfs-kf6-base10-runtime /tmp/blfs-kf6-base10-config
mkdir -p /tmp/blfs-kf6-base10-smoke /tmp/blfs-kf6-base10-config
cat >/tmp/blfs-kf6-base10-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base10_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick Widgets Xml)
find_package(KF6Syndication 6.17.0 REQUIRED CONFIG)
find_package(KF6NewStuffCore 6.17.0 REQUIRED CONFIG)
find_package(KF6FrameworkIntegration 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base10-smoke main.cpp)
target_link_libraries(blfs-kf6-base10-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Widgets Qt6::Xml
  KF6::Syndication KF6::NewStuffCore KF6::Style)
EOF
cat >/tmp/blfs-kf6-base10-smoke/main.cpp <<'EOF'
#include <KNSCore/Entry>
#include <KStyle>
#include <Syndication/DocumentSource>
#include <Syndication/Feed>
#include <Syndication/Global>
#include <QApplication>
#include <QByteArray>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickItem>
#include <QString>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
#include <memory>
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-kf6-base10-smoke"));
  const QByteArray xml(
    "<feed xmlns=\"http://www.w3.org/2005/Atom\">"
    "<title>smoke</title><entry><title>one</title></entry></feed>");
  Syndication::DocumentSource source(xml, QStringLiteral("https://example.invalid/feed"));
  Syndication::FeedPtr feed = Syndication::parse(source);
  if (!feed || feed->title() != QStringLiteral("smoke") || feed->items().size() != 1) return 1;
  KNSCore::Entry entry;
  entry.setName(QStringLiteral("native"));
  entry.setVersion(QStringLiteral("1.0"));
  if (entry.name() != QStringLiteral("native") || entry.version() != QStringLiteral("1.0")) return 2;
  KStyle style;
  style.setObjectName(QStringLiteral("native"));
  if (style.objectName() != QStringLiteral("native")) return 3;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.newstuff 1.0\nItem { width: 24; height: 12 }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 4;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) return 5;
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 24.0) return 6;
  std::printf("BLFS_KF6_BASE10_EXEC_OK=%s=%s=%s=%d\n", qVersion(),
              feed->title().toUtf8().constData(), entry.name().toUtf8().constData(), static_cast<int>(item->width()));
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base10-smoke -B /tmp/blfs-kf6-base10-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base10-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base10-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-kf6-base10-config XDG_RUNTIME_DIR=/tmp/blfs-kf6-base10-runtime \
  QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins QML_DISABLE_DISK_CACHE=1 \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base10-smoke-build/blfs-kf6-base10-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE10_EXEC_OK=6.9.2=smoke=native=24 ]]
readelf -h /tmp/blfs-kf6-base10-smoke-build/blfs-kf6-base10-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base10-smoke-build/blfs-kf6-base10-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE10_RESULT=ok\nPACKAGE_COUNT=3\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE10_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=syndication+knewstuff+frameworkintegration\nDEPENDENCIES=none\n'
  printf 'SYNDICATION=local-atom-parse-no-network\nKNEWSTUFF=native-entry-qml-import-no-download\n'
  printf 'FRAMEWORKINTEGRATION=native-kstyle-object\nQML_IMPORTS=newstuff\nKPACKAGE_HANDLER=present-not-run\n'
  printf 'NETWORK_RUNTIME=not-tested\nPACKAGEKIT_RUNTIME=not-tested\nAPPSTREAM_RUNTIME=not-tested\nWINDOW_RUNTIME=not-tested-no-window-shown\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nBASE9=preserved-pipeline-116\nBASE8=preserved-pipeline-115\n'
  printf 'SECURITY_DEPS1=preserved-pipeline-109\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base10-smoke /tmp/blfs-kf6-base10-smoke-build /tmp/blfs-kf6-base10-runtime /tmp/blfs-kf6-base10-config
