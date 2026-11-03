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
REPORT=/root/blfs-kf6-base13-report.txt
PROGRESS=/root/blfs-kf6-base13-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Qml Qt6Quick Qt6Sql Qt6DBus; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6TextEditor KF6Parts KF6SyntaxHighlighting KF6CoreAddons KF6ItemViews; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Contacts KF6People KF6PeopleBackend KF6PeopleWidgets KF6ModemManagerQt; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
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
packages=(kcontacts kpeople)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE13=%s\n' "$name"
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
  printf 'BLFS_KF6_BASE13_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE13_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Contacts/KF6ContactsConfig.cmake \
  /opt/kf6/lib/cmake/KF6People/KF6PeopleConfig.cmake \
  /opt/kf6/lib/libKF6Contacts.so \
  /opt/kf6/lib/libKF6People.so \
  /opt/kf6/lib/libKF6PeopleBackend.so \
  /opt/kf6/lib/libKF6PeopleWidgets.so \
  /opt/kf6/lib/qml/org/kde/contacts/qmldir \
  /opt/kf6/lib/qml/org/kde/people/qmldir; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base13-smoke /tmp/blfs-kf6-base13-smoke-build /tmp/blfs-kf6-base13-runtime /tmp/blfs-kf6-base13-config
mkdir -p /tmp/blfs-kf6-base13-smoke /tmp/blfs-kf6-base13-config
cat >/tmp/blfs-kf6-base13-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base13_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick Widgets Sql DBus)
find_package(KF6Contacts 6.17.0 REQUIRED CONFIG)
find_package(KF6People 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base13-smoke main.cpp)
target_link_libraries(blfs-kf6-base13-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Widgets Qt6::Sql Qt6::DBus
  KF6::Contacts KF6::People)
EOF
cat >/tmp/blfs-kf6-base13-smoke/main.cpp <<'EOF'
#include <KContacts/Addressee>
#include <KPeople/PersonPluginManager>
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
  app.setApplicationName(QStringLiteral("blfs-kf6-base13-smoke"));
  KContacts::Addressee contact;
  contact.setName(QStringLiteral("native"));
  contact.setFormattedName(QStringLiteral("Native Smoke"));
  if (contact.name() != QStringLiteral("native") || contact.formattedName() != QStringLiteral("Native Smoke")) return 1;
  KPeople::PersonPluginManager::setAutoloadDataSourcePlugins(false);
  if (!KPeople::PersonPluginManager::dataSourcePlugins().isEmpty()) return 2;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.contacts\nimport org.kde.people\nItem { width: 18; height: 9 }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    return 3;
  }
  std::unique_ptr<QObject> object(component.create());
  if (!object) return 4;
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 18.0) return 5;
  std::printf("BLFS_KF6_BASE13_EXEC_OK=%s=contacts=ok=people=empty=18\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base13-smoke -B /tmp/blfs-kf6-base13-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base13-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base13-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-kf6-base13-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base13-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /tmp/blfs-kf6-base13-smoke-build/blfs-kf6-base13-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE13_EXEC_OK=6.9.2=contacts=ok=people=empty=18 ]]
readelf -h /tmp/blfs-kf6-base13-smoke-build/blfs-kf6-base13-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base13-smoke-build/blfs-kf6-base13-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE13_RESULT=ok\nPACKAGE_COUNT=2\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE13_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=kcontacts+kpeople\nDEPENDENCIES=none\n'
  printf 'KCONTACTS=native-addressee-qml-import\nKPEOPLE=native-plugin-manager-qml-import-no-backend\n'
  printf 'CONTACT_BACKEND=autoload-disabled-no-daemon\nMODEMMANAGER_QT=deferred-modemmanager-required\n'
  printf 'NETWORK_RUNTIME=not-tested\nWINDOW_RUNTIME=not-tested-no-window-shown\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE12=preserved-pipeline-121\nQT_MEDIA_SPEECH1=preserved-pipeline-120\nBASE11=preserved-pipeline-119\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base13-smoke /tmp/blfs-kf6-base13-smoke-build /tmp/blfs-kf6-base13-runtime /tmp/blfs-kf6-base13-config
