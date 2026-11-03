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
REPORT=/root/blfs-kf6-base21-report.txt
PROGRESS=/root/blfs-kf6-base21-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui Qt6Network Qt6Qml; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ -f /opt/kf6/lib/cmake/KF6Svg/KF6SvgConfig.cmake ]]
[[ ! -e /opt/kf6/lib/cmake/KF6TextTemplate && ! -e /opt/kf6/lib/cmake/KF6UserFeedback ]]
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
  printf 'BUILD_BLFS_KF6_BASE21=%s\n' "$name"
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
  printf 'BLFS_KF6_BASE21_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
}
build_kf6 ktexttemplate
build_kf6 kuserfeedback
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE21_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6TextTemplate/KF6TextTemplateConfig.cmake \
  /opt/kf6/lib/libKF6TextTemplate.so \
  /opt/kf6/lib/cmake/KF6UserFeedback/KF6UserFeedbackConfig.cmake \
  /opt/kf6/lib/libKF6UserFeedbackCore.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base21-smoke /tmp/blfs-kf6-base21-smoke-build /tmp/blfs-kf6-base21-runtime
mkdir -p /tmp/blfs-kf6-base21-smoke
cat >/tmp/blfs-kf6-base21-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base21_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Network)
find_package(KF6TextTemplate 6.17.0 REQUIRED CONFIG)
find_package(KF6UserFeedback 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base21-smoke main.cpp)
target_link_libraries(blfs-kf6-base21-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Network KF6::TextTemplate KF6::UserFeedbackCore)
EOF
cat >/tmp/blfs-kf6-base21-smoke/main.cpp <<'EOF'
#include <KTextTemplate/Context>
#include <KTextTemplate/Engine>
#include <KTextTemplate/Template>
#include <KUserFeedback/Provider>
#include <QCoreApplication>
#include <QString>
#include <QUrl>
#include <QVariant>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  QCoreApplication::setApplicationName(QStringLiteral("native"));
  KTextTemplate::Engine engine;
  auto tmpl = engine.newTemplate(QStringLiteral("Hello {{ name }}"), QStringLiteral("native"));
  if (!tmpl) return 1;
  KTextTemplate::Context context;
  context.insert(QStringLiteral("name"), QVariant(QStringLiteral("native")));
  if (tmpl->render(&context) != QStringLiteral("Hello native")) return 2;
  KUserFeedback::Provider provider;
  if (provider.isEnabled() || provider.telemetryMode() != KUserFeedback::Provider::NoTelemetry || provider.submissionInterval() != -1) return 3;
  provider.setProductIdentifier(QStringLiteral("native"));
  provider.setFeedbackServer(QUrl(QStringLiteral("https://example.invalid")));
  if (provider.productIdentifier() != QStringLiteral("native") || provider.feedbackServer() != QUrl(QStringLiteral("https://example.invalid")) || provider.isEnabled()) return 4;
  std::printf("BLFS_KF6_BASE21_EXEC_OK=%s=template=render=feedback=disabled\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base21-smoke -B /tmp/blfs-kf6-base21-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-kf6-base21-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base21-runtime
OUTPUT="$(XDG_RUNTIME_DIR=/tmp/blfs-kf6-base21-runtime QT_QPA_PLATFORM=offscreen \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib /tmp/blfs-kf6-base21-smoke-build/blfs-kf6-base21-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE21_EXEC_OK=6.9.2=template=render=feedback=disabled ]]
printf 'NATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\n' "$OUTPUT"
readelf -h /tmp/blfs-kf6-base21-smoke-build/blfs-kf6-base21-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base21-smoke-build/blfs-kf6-base21-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE21_RESULT=ok\nPACKAGE_COUNT=2\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE21_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=ktexttemplate+kuserfeedback\nDEPENDENCIES=none\n'
  printf 'TEXT_TEMPLATE=native-render\nUSERFEEDBACK=native-disabled-provider\nTELEMETRY=disabled-no-submission\n'
  printf 'NETWORK_RUNTIME=not-tested-provider-disabled\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'BASE20=preserved-pipeline-140\nBASE19=preserved-pipeline-138\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base21-smoke /tmp/blfs-kf6-base21-smoke-build /tmp/blfs-kf6-base21-runtime
