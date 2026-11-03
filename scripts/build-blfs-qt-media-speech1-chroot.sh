#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export LANG=POSIX
export PATH=/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-qt-media-speech1-report.txt
PROGRESS=/root/blfs-qt-media-speech1-progress.txt
QT6PREFIX=/opt/qt6
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x "$QT6PREFIX/bin/qmake6" && -x "$QT6PREFIX/bin/qt-configure-module" ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui Qt6Qml Qt6Quick Qt6ShaderTools; do [[ -f "$QT6PREFIX/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Parts KF6SyntaxHighlighting; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in Qt6Multimedia Qt6TextToSpeech; do [[ ! -e "$QT6PREFIX/lib/cmake/$path" ]]; done
[[ -d /sources ]]
: >"$PROGRESS"
build_module() {
  local module="$1" archive package_dir build_dir first
  archive="$module-everywhere-src-6.9.2.tar.xz"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$module-everywhere-src-6.9.2" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  build_dir="$SOURCES/$package_dir/build"
  mkdir "$build_dir"; cd "$build_dir"
  printf 'BUILD_BLFS_QT_MEDIA_SPEECH1=%s\n' "$module"
  local extra=()
  if [[ "$module" == qtmultimedia ]]; then
    extra=(-DFEATURE_gstreamer=OFF -DFEATURE_pulseaudio=OFF -DFEATURE_alsa=OFF -DFEATURE_ffmpeg=OFF -DFEATURE_pipewire=OFF)
  else
    extra=(-DFEATURE_flite=OFF -DFEATURE_speechd=OFF)
  fi
  /opt/qt6/bin/qt-configure-module "$SOURCES/$package_dir" -- \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_EXAMPLES=OFF \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_MANUAL_TESTS=OFF \
    -DQT_GENERATE_SBOM=OFF \
    "${extra[@]}"
  [[ -s config.summary ]]
  ninja
  ninja install
  cp config.summary "/root/blfs-qt-media-speech1-config-summary-$module.txt"
  cd /sources; rm -rf "$package_dir"
  printf 'BLFS_QT_MEDIA_SPEECH1_BUILT=%s\n' "$package_dir" >>"$PROGRESS"
}
build_module qtmultimedia
build_module qtspeech
find "$QT6PREFIX" -name '*.prl' -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
/sbin/ldconfig
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
[[ "$(grep -c '^BLFS_QT_MEDIA_SPEECH1_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  "$QT6PREFIX/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake" \
  "$QT6PREFIX/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake" \
  "$QT6PREFIX/lib/libQt6Multimedia.so" \
  "$QT6PREFIX/lib/libQt6TextToSpeech.so"; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-qt-media-speech1-smoke /tmp/blfs-qt-media-speech1-smoke-build /tmp/blfs-qt-media-speech1-runtime
mkdir -p /tmp/blfs-qt-media-speech1-smoke
cat >/tmp/blfs-qt-media-speech1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_qt_media_speech1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Multimedia TextToSpeech)
add_executable(blfs-qt-media-speech1-smoke main.cpp)
target_link_libraries(blfs-qt-media-speech1-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Multimedia Qt6::TextToSpeech)
EOF
cat >/tmp/blfs-qt-media-speech1-smoke/main.cpp <<'EOF'
#include <QCoreApplication>
#include <QMediaPlayer>
#include <QString>
#include <QTextToSpeech>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-qt-media-speech1-smoke"));
  QMediaPlayer player;
  if (player.playbackState() != QMediaPlayer::StoppedState) return 1;
  QTextToSpeech speech;
  const QString engine = speech.engine();
  if (!engine.isEmpty()) return 2;
  std::printf("BLFS_QT_MEDIA_SPEECH1_EXEC_OK=%s=media=stopped=speech=constructed\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-qt-media-speech1-smoke -B /tmp/blfs-qt-media-speech1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D CMAKE_PREFIX_PATH=/opt/qt6
ninja -C /tmp/blfs-qt-media-speech1-smoke-build
install -d -m 0700 /tmp/blfs-qt-media-speech1-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp/blfs-qt-media-speech1-runtime \
  LD_LIBRARY_PATH=/opt/qt6/lib /tmp/blfs-qt-media-speech1-smoke-build/blfs-qt-media-speech1-smoke)"
[[ "$OUTPUT" == BLFS_QT_MEDIA_SPEECH1_EXEC_OK=6.9.2=media=stopped=speech=constructed ]]
readelf -h /tmp/blfs-qt-media-speech1-smoke-build/blfs-qt-media-speech1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-qt-media-speech1-smoke-build/blfs-qt-media-speech1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_QT_MEDIA_SPEECH1_RESULT=ok\nPACKAGE_COUNT=2\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_QT_MEDIA_SPEECH1_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nPACKAGES=qtmultimedia+qtspeech\nDEPENDENCIES=none\n'
  printf 'QT_MULTIMEDIA=native-media-player-stopped\nQT_TEXT_TO_SPEECH=native-object-no-engine\n'
  printf 'MEDIA_BACKENDS=disabled-gstreamer-ffmpeg-pulseaudio-alsa-pipewire\nSPEECH_BACKENDS=disabled-flite-speechd\n'
  printf 'AUDIO_RUNTIME=not-tested-no-device-access\nSPEECH_RUNTIME=not-tested-no-say-call\nWINDOW_RUNTIME=not-tested-no-window-shown\n'
  printf 'TEST_SUITES=not-run-QT_BUILD_TESTS_OFF\nBASE11=preserved-pipeline-119\nBASE10=preserved-pipeline-118\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-qt-media-speech1-smoke /tmp/blfs-qt-media-speech1-smoke-build /tmp/blfs-qt-media-speech1-runtime
