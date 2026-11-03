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
REPORT=/root/blfs-kf6-base14-report.txt
PROGRESS=/root/blfs-kf6-base14-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Qml Qt6Quick Qt6DBus Qt6Network Qt6Xml; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Contacts KF6People KF6TextEditor KF6CoreAddons KF6WindowSystem; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6BluezQt KF6FileMetaData KF6Runner KF6Baloo; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
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
packages=(bluez-qt kfilemetadata krunner)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE14=%s\n' "$name"
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
  printf 'BLFS_KF6_BASE14_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE14_BUILT=' "$PROGRESS")" -eq 3 ]]
for path in \
  /opt/kf6/lib/cmake/KF6BluezQt/KF6BluezQtConfig.cmake \
  /opt/kf6/lib/cmake/KF6FileMetaData/KF6FileMetaDataConfig.cmake \
  /opt/kf6/lib/cmake/KF6Runner/KF6RunnerConfig.cmake \
  /opt/kf6/lib/libKF6BluezQt.so \
  /opt/kf6/lib/libKF6FileMetaData.so \
  /opt/kf6/lib/libKF6Runner.so \
  /opt/kf6/lib/qml/org/kde/bluezqt/qmldir; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base14-smoke /tmp/blfs-kf6-base14-smoke-build /tmp/blfs-kf6-base14-runtime /tmp/blfs-kf6-base14-config
mkdir -p /tmp/blfs-kf6-base14-smoke /tmp/blfs-kf6-base14-config
cat >/tmp/blfs-kf6-base14-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base14_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick Widgets DBus Network Xml)
find_package(KF6BluezQt 6.17.0 REQUIRED CONFIG)
find_package(KF6FileMetaData 6.17.0 REQUIRED CONFIG)
find_package(KF6Runner 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base14-smoke main.cpp)
target_link_libraries(blfs-kf6-base14-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Widgets Qt6::DBus Qt6::Network Qt6::Xml
  KF6::BluezQt KF6::FileMetaData KF6::Runner)
EOF
cat >/tmp/blfs-kf6-base14-smoke/main.cpp <<'EOF'
#include <BluezQt/Device>
#include <KFileMetaData/SimpleExtractionResult>
#include <KFileMetaData/Types>
#include <KRunner/QueryMatch>
#include <KRunner/RunnerContext>
#include <QApplication>
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
  app.setApplicationName(QStringLiteral("blfs-kf6-base14-smoke"));
  if (BluezQt::Device::typeToString(BluezQt::Device::Phone) != QStringLiteral("phone")) return 1;
  KFileMetaData::SimpleExtractionResult extracted(QStringLiteral("memory://base14"), QStringLiteral("text/plain"));
  extracted.append(QStringLiteral("native metadata"));
  extracted.addType(KFileMetaData::Type::Text);
  if (extracted.text().trimmed() != QStringLiteral("native metadata")) return 2;
  KRunner::QueryMatch match;
  match.setText(QStringLiteral("native runner"));
  KRunner::RunnerContext context;
  context.setQuery(QStringLiteral("native"));
  if (match.text() != QStringLiteral("native runner") || context.query() != QStringLiteral("native")) return 3;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.bluezqt\nItem { width: 21; height: 7 }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 4;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) return 5;
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 21.0) return 6;
  std::printf("BLFS_KF6_BASE14_EXEC_OK=%s=bluez=phone=metadata=ok=runner=ok=21\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base14-smoke -B /tmp/blfs-kf6-base14-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base14-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base14-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-kf6-base14-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base14-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /tmp/blfs-kf6-base14-smoke-build/blfs-kf6-base14-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE14_EXEC_OK=6.9.2=bluez=phone=metadata=ok=runner=ok=21 ]]
readelf -h /tmp/blfs-kf6-base14-smoke-build/blfs-kf6-base14-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base14-smoke-build/blfs-kf6-base14-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE14_RESULT=ok\nPACKAGE_COUNT=3\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE14_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=bluez-qt+kfilemetadata+krunner\nDEPENDENCIES=none\n'
  printf 'BLUEZQT=native-device-type-qml-import-no-manager\nKFILEMETADATA=native-memory-result-no-file-io\nKRUNNER=native-query-match-no-manager\n'
  printf 'BLUEZ_RUNTIME=not-tested-no-dbus-init-or-hardware\nFILE_IO=not-tested-no-file-access\nRUNNER_RUNTIME=not-tested-no-dbus\n'
  printf 'BALOO=deferred-lmdb-required\nWINDOW_RUNTIME=not-tested-no-window-shown\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE13=preserved-pipeline-123\nBASE12=preserved-pipeline-121\nQT_MEDIA_SPEECH1=preserved-pipeline-120\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base14-smoke /tmp/blfs-kf6-base14-smoke-build /tmp/blfs-kf6-base14-runtime /tmp/blfs-kf6-base14-config
