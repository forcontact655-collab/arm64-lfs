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
REPORT=/root/blfs-kf6-base12-report.txt
PROGRESS=/root/blfs-kf6-base12-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6TextToSpeech Qt6PrintSupport Qt6Qml; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Parts KF6SyntaxHighlighting KF6Auth KF6Sonnet KF6KIO; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e /opt/kf6/lib/cmake/KF6TextEditor ]]
: >"$PROGRESS"
archive=ktexteditor-6.17.0.tar.xz
[[ -f "$SOURCES/$archive" ]]
first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
package_dir="${first%%/*}"; package_dir="${package_dir#./}"
[[ "$package_dir" == ktexteditor-6.17.0 ]]
rm -rf "$SOURCES/$package_dir"
tar -xf "$SOURCES/$archive" -C "$SOURCES"
mkdir "$SOURCES/$package_dir/build"
cd "$SOURCES/$package_dir/build"
printf 'BUILD_BLFS_KF6_BASE12=ktexteditor\n'
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
cd /sources; rm -rf "$package_dir"
printf 'BLFS_KF6_BASE12_BUILT=ktexteditor-6.17.0\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE12_BUILT=' "$PROGRESS")" -eq 1 ]]
for path in \
  /opt/kf6/lib/cmake/KF6TextEditor/KF6TextEditorConfig.cmake \
  /opt/kf6/lib/libKF6TextEditor.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base12-smoke /tmp/blfs-kf6-base12-smoke-build /tmp/blfs-kf6-base12-runtime /tmp/blfs-kf6-base12-config
mkdir -p /tmp/blfs-kf6-base12-smoke /tmp/blfs-kf6-base12-config
cat >/tmp/blfs-kf6-base12-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base12_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets Qml PrintSupport TextToSpeech)
find_package(KF6TextEditor 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base12-smoke main.cpp)
target_link_libraries(blfs-kf6-base12-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::PrintSupport Qt6::TextToSpeech KF6::TextEditor)
EOF
cat >/tmp/blfs-kf6-base12-smoke/main.cpp <<'EOF'
#include <KTextEditor/Document>
#include <KTextEditor/Editor>
#include <KTextEditor/View>
#include <QApplication>
#include <QString>
#include <QtGlobal>
#include <cstdio>
#include <memory>
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-kf6-base12-smoke"));
  auto *editor = KTextEditor::Editor::instance();
  if (!editor) return 1;
  std::unique_ptr<KTextEditor::Document> document(editor->createDocument(nullptr));
  if (!document || !document->setText(QStringLiteral("int x = 1;\n"))) return 2;
  if (!document->setHighlightingMode(QStringLiteral("C++"))) return 3;
  if (document->text() != QStringLiteral("int x = 1;\n")) return 4;
  std::unique_ptr<KTextEditor::View> view(document->createView(nullptr));
  if (!view || view->document() != document.get() || view->isVisible()) return 5;
  std::printf("BLFS_KF6_BASE12_EXEC_OK=%s=document=ok=view=unshown\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base12-smoke -B /tmp/blfs-kf6-base12-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base12-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base12-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-kf6-base12-config XDG_DATA_DIRS=/opt/kf6/share:/usr/share \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base12-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins QML_DISABLE_DISK_CACHE=1 \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base12-smoke-build/blfs-kf6-base12-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE12_EXEC_OK=6.9.2=document=ok=view=unshown ]]
readelf -h /tmp/blfs-kf6-base12-smoke-build/blfs-kf6-base12-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base12-smoke-build/blfs-kf6-base12-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE12_RESULT=ok\nPACKAGE_COUNT=1\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE12_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=ktexteditor\nDEPENDENCIES=qt-media-speech1-preserved\n'
  printf 'KTEXTEDITOR=native-document-view-no-window\nHIGHLIGHTING=cpp-mode-set\nTEXT_TO_SPEECH=linked-not-spoken\n'
  printf 'AUDIO_RUNTIME=not-tested-no-device-access\nSPEECH_RUNTIME=not-tested-no-say-call\nWINDOW_RUNTIME=not-tested-no-window-shown\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\nQT_MEDIA_SPEECH1=preserved-pipeline-120\nBASE11=preserved-pipeline-119\n'
  printf 'BASE10=preserved-pipeline-118\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base12-smoke /tmp/blfs-kf6-base12-smoke-build /tmp/blfs-kf6-base12-runtime /tmp/blfs-kf6-base12-config
