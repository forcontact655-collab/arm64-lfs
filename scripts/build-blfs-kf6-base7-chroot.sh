#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base7-report.txt
PROGRESS=/root/blfs-kf6-base7-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ "$(pkg-config --modversion libcanberra)" == 0.30 ]]
for path in KF6ColorScheme KF6ConfigWidgets KF6Service KF6GlobalAccel KF6Package KF6Su; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6IconThemes KF6Notifications KF6JobWidgets KF6TextWidgets KF6XmlGui KF6Bookmarks; do
  [[ ! -e "/opt/kf6/lib/cmake/$path" ]]
done
[[ ! -e /usr/lib/cmake/KF6BreezeIcons ]]
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
extract_package breeze-icons-6.17.0.tar.xz breeze-icons-6.17.0
printf 'BUILD_BLFS_KF6_BASE7_DEPENDENCY=breeze-icons\n'
mkdir build; cd build
cmake -G Ninja -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6" -D BUILD_TESTING=OFF -W no-dev ..
ninja
ninja install
cd /sources; rm -rf breeze-icons-6.17.0
printf 'BLFS_KF6_BASE7_DEPENDENCY_BUILT=breeze-icons-6.17.0\n' >>"$PROGRESS"
/sbin/ldconfig
packages=(kiconthemes knotifications kjobwidgets ktextwidgets kxmlgui kbookmarks)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE7=%s\n' "$name"
  cmake_args=(
    -D CMAKE_INSTALL_PREFIX=/opt/kf6
    -D CMAKE_INSTALL_LIBEXECDIR=libexec
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
    -D CMAKE_SKIP_INSTALL_RPATH=ON
    -D CMAKE_BUILD_TYPE=Release
    -D BUILD_TESTING=OFF
    -D BUILD_PYTHON_BINDINGS=OFF
  )
  if [[ "$name" == ktextwidgets ]]; then cmake_args+=(-D WITH_TEXT_TO_SPEECH=OFF); fi
  if [[ "$name" == kjobwidgets ]]; then cmake_args+=(-D WITH_X11=ON); fi
  cmake -G Ninja "${cmake_args[@]}" -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE7_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE7_BUILT=' "$PROGRESS")" -eq 6 ]]
[[ "$(grep -c '^BLFS_KF6_BASE7_DEPENDENCY_BUILT=breeze-icons-6.17.0$' "$PROGRESS")" -eq 1 ]]
[[ -f /usr/lib/cmake/KF6BreezeIcons/KF6BreezeIconsConfig.cmake && -e /usr/lib/libKF6BreezeIcons.so ]]
[[ -f /usr/share/icons/breeze/index.theme && -f /usr/share/icons/breeze-dark/index.theme ]]
for path in \
  /opt/kf6/lib/cmake/KF6IconThemes/KF6IconThemesConfig.cmake \
  /opt/kf6/lib/cmake/KF6Notifications/KF6NotificationsConfig.cmake \
  /opt/kf6/lib/cmake/KF6JobWidgets/KF6JobWidgetsConfig.cmake \
  /opt/kf6/lib/cmake/KF6TextWidgets/KF6TextWidgetsConfig.cmake \
  /opt/kf6/lib/cmake/KF6XmlGui/KF6XmlGuiConfig.cmake \
  /opt/kf6/lib/cmake/KF6Bookmarks/KF6BookmarksConfig.cmake \
  /opt/kf6/lib/libKF6IconThemes.so /opt/kf6/lib/libKF6Notifications.so \
  /opt/kf6/lib/libKF6JobWidgets.so /opt/kf6/lib/libKF6TextWidgets.so \
  /opt/kf6/lib/libKF6XmlGui.so /opt/kf6/lib/libKF6Bookmarks.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base7-smoke /tmp/blfs-kf6-base7-smoke-build
mkdir -p /tmp/blfs-kf6-base7-smoke
cat >/tmp/blfs-kf6-base7-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base7_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets DBus Xml Network PrintSupport Qml Quick Svg)
find_package(KF6IconThemes 6.17.0 REQUIRED CONFIG)
find_package(KF6Notifications 6.17.0 REQUIRED CONFIG)
find_package(KF6JobWidgets 6.17.0 REQUIRED CONFIG)
find_package(KF6TextWidgets 6.17.0 REQUIRED CONFIG)
find_package(KF6XmlGui 6.17.0 REQUIRED CONFIG)
find_package(KF6Bookmarks 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base7-smoke main.cpp)
target_link_libraries(blfs-kf6-base7-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets Qt6::DBus Qt6::Xml Qt6::Network Qt6::PrintSupport Qt6::Qml Qt6::Quick Qt6::Svg
  KF6::IconThemes KF6::Notifications KF6::JobWidgets KF6::TextWidgets KF6::XmlGui KF6::Bookmarks)
EOF
cat >/tmp/blfs-kf6-base7-smoke/main.cpp <<'EOF'
#include <KIconTheme>
#include <KIconLoader>
#include <KNotification>
#include <KWidgetJobTracker>
#include <KTextEdit>
#include <KMainWindow>
#include <KActionCollection>
#include <KBookmarkGroup>
#include <QAction>
#include <QApplication>
#include <QDomDocument>
#include <QDomElement>
#include <QFile>
#include <QString>
#include <QUrl>
#include <cstdio>
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  KIconTheme theme(QStringLiteral("breeze"));
  if (!theme.isValid()) return 1;
  const QString icon = theme.iconPath(QStringLiteral("dialog-ok"), 16, KIconLoader::MatchBest);
  if (icon.isEmpty() || !QFile::exists(icon)) return 2;
  KNotification notification(QStringLiteral("blfs-smoke"));
  notification.setText(QStringLiteral("hello"));
  if (notification.text() != QStringLiteral("hello")) return 3;
  KTextEdit edit;
  edit.setPlainText(QStringLiteral("hello"));
  if (edit.toPlainText() != QStringLiteral("hello")) return 4;
  KMainWindow window;
  KWidgetJobTracker tracker(&window);
  Q_UNUSED(tracker);
  QAction action(QStringLiteral("BLFS"), &window);
  KActionCollection collection(&window);
  collection.addAction(QStringLiteral("blfs_action"), &action);
  if (collection.action(QStringLiteral("blfs_action")) != &action) return 5;
  QDomDocument document(QStringLiteral("xbel"));
  QDomElement root = document.createElement(QStringLiteral("xbel"));
  document.appendChild(root);
  KBookmarkGroup group(root);
  KBookmark bookmark = group.addBookmark(QStringLiteral("Example"), QUrl(QStringLiteral("https://example.org/")), QStringLiteral("dialog-ok"));
  if (bookmark.isNull() || bookmark.url() != QUrl(QStringLiteral("https://example.org/")) || group.first().isNull()) return 6;
  std::printf("BLFS_KF6_BASE7_EXEC_OK=%s=%s=%d\n", qVersion(), edit.toPlainText().toUtf8().constData(), QFile::exists(icon) ? 1 : 0);
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base7-smoke -B /tmp/blfs-kf6-base7-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base7-smoke-build
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base7-smoke-build/blfs-kf6-base7-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE7_EXEC_OK=6.9.2=hello=1 ]]
readelf -h /tmp/blfs-kf6-base7-smoke-build/blfs-kf6-base7-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base7-smoke-build/blfs-kf6-base7-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE7_RESULT=ok\nPACKAGE_COUNT=6\nDEPENDENCY_COUNT=1\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE7_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nDEPENDENCIES=breeze-icons\nBREEZE_TEST_SUITE=absent-BUILD_TESTING_OFF\n'
  printf 'PACKAGES=kiconthemes+knotifications+kjobwidgets+ktextwidgets+kxmlgui+kbookmarks\n'
  printf 'KICONTHEMES=native-breeze-icon-ok\nKNOTIFICATIONS=object-only-no-send\nKJOBWIDGETS=native-tracker-object\n'
  printf 'KTEXTWIDGETS=native-text-edit-ok\nKXMLGUI=native-action-collection-ok\nKBOOKMARKS=native-dom-bookmark-ok\n'
  printf 'TEXT_TO_SPEECH=disabled-qtspeech-not-built\nNOTIFICATION_RUNTIME=not-tested-no-daemon\nJOB_RUNTIME=not-tested-no-job\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nAUDIO_PLAYBACK=not-tested\n'
  printf 'AUDIO_DEPS=preserved-pipeline-102\nBASE6=preserved-pipeline-100\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base7-smoke /tmp/blfs-kf6-base7-smoke-build
