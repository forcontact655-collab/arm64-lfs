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
REPORT=/root/blfs-kf6-base11-report.txt
PROGRESS=/root/blfs-kf6-base11-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/perl ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6Syndication KF6NewStuff KF6FrameworkIntegration KF6KIO KF6XmlGui; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6Parts KF6SyntaxHighlighting KF6TextEditor; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
[[ ! -e /opt/qt6/lib/cmake/Qt6TextToSpeech ]]
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
packages=(kparts syntax-highlighting)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE11=%s\n' "$name"
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
  printf 'BLFS_KF6_BASE11_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE11_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Parts/KF6PartsConfig.cmake \
  /opt/kf6/lib/cmake/KF6SyntaxHighlighting/KF6SyntaxHighlightingConfig.cmake \
  /opt/kf6/lib/libKF6Parts.so \
  /opt/kf6/lib/libKF6SyntaxHighlighting.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base11-smoke /tmp/blfs-kf6-base11-smoke-build /tmp/blfs-kf6-base11-runtime /tmp/blfs-kf6-base11-config
mkdir -p /tmp/blfs-kf6-base11-smoke /tmp/blfs-kf6-base11-config
cat >/tmp/blfs-kf6-base11-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base11_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets Xml)
find_package(KF6Parts 6.17.0 REQUIRED CONFIG)
find_package(KF6SyntaxHighlighting 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base11-smoke main.cpp)
target_link_libraries(blfs-kf6-base11-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Xml KF6::Parts KF6::SyntaxHighlighting)
EOF
cat >/tmp/blfs-kf6-base11-smoke/main.cpp <<'EOF'
#include <KParts/Part>
#include <KSyntaxHighlighting/AbstractHighlighter>
#include <KSyntaxHighlighting/Definition>
#include <KSyntaxHighlighting/Format>
#include <KSyntaxHighlighting/Repository>
#include <KSyntaxHighlighting/State>
#include <KSyntaxHighlighting/Theme>
#include <QApplication>
#include <QString>
#include <QStringView>
#include <QtGlobal>
#include <cstdio>
class SmokeHighlighter : public KSyntaxHighlighting::AbstractHighlighter {
public:
  int formats = 0;
  KSyntaxHighlighting::State run(const QString &text) {
    return highlightLine(QStringView(text), KSyntaxHighlighting::State());
  }
protected:
  void applyFormat(int, int length, const KSyntaxHighlighting::Format &format) override {
    if (length > 0 && format.isValid()) ++formats;
  }
};
int main(int argc, char **argv) {
  QApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("blfs-kf6-base11-smoke"));
  KParts::Part part;
  part.setObjectName(QStringLiteral("native"));
  if (part.objectName() != QStringLiteral("native")) return 1;
  KSyntaxHighlighting::Repository repository;
  const auto definition = repository.definitionForName(QStringLiteral("C++"));
  const auto theme = repository.defaultTheme(KSyntaxHighlighting::Repository::DarkTheme);
  if (!definition.isValid() || !theme.isValid()) return 2;
  SmokeHighlighter highlighter;
  highlighter.setDefinition(definition);
  highlighter.setTheme(theme);
  highlighter.run(QStringLiteral("int x = 1;"));
  if (highlighter.formats < 1) return 3;
  std::printf("BLFS_KF6_BASE11_EXEC_OK=%s=smoke=ok\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base11-smoke -B /tmp/blfs-kf6-base11-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base11-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base11-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_CONFIG_HOME=/tmp/blfs-kf6-base11-config XDG_RUNTIME_DIR=/tmp/blfs-kf6-base11-runtime \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base11-smoke-build/blfs-kf6-base11-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE11_EXEC_OK=6.9.2=smoke=ok ]]
readelf -h /tmp/blfs-kf6-base11-smoke-build/blfs-kf6-base11-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base11-smoke-build/blfs-kf6-base11-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE11_RESULT=ok\nPACKAGE_COUNT=2\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE11_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=kparts+syntax-highlighting\nDEPENDENCIES=none\n'
  printf 'KPARTS=native-part-object-no-window\nSYNTAX_HIGHLIGHTING=native-offline-cpp-highlight\n'
  printf 'KTEXTEDITOR=deferred-required-qtspeech-not-built\nQT_TEXT_TO_SPEECH=absent-required-by-ktexteditor\n'
  printf 'NETWORK_RUNTIME=not-tested\nWINDOW_RUNTIME=not-tested-no-window-shown\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE10=preserved-pipeline-118\nBASE9=preserved-pipeline-116\nBASE8=preserved-pipeline-115\n'
  printf 'SECURITY_DEPS1=preserved-pipeline-109\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base11-smoke /tmp/blfs-kf6-base11-smoke-build /tmp/blfs-kf6-base11-runtime /tmp/blfs-kf6-base11-config
