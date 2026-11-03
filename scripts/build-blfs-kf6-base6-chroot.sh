#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base6-report.txt
PROGRESS=/root/blfs-kf6-base6-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6Auth KF6Completion KF6Crash KF6DocTools KF6Pty KF6UnitConversion; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6ColorScheme KF6ConfigWidgets KF6Service KF6GlobalAccel KF6Package KF6Su; do
  [[ ! -e "/opt/kf6/lib/cmake/$path" ]]
done
[[ -x /usr/bin/xfce4-terminal ]]
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
packages=(kcolorscheme kconfigwidgets kservice kglobalaccel kpackage kdesu)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE6=%s\n' "$name"
  cmake_args=(
    -D CMAKE_INSTALL_PREFIX=/opt/kf6
    -D CMAKE_INSTALL_LIBEXECDIR=libexec
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
    -D CMAKE_SKIP_INSTALL_RPATH=ON
    -D CMAKE_BUILD_TYPE=Release
    -D BUILD_TESTING=OFF
    -D BUILD_PYTHON_BINDINGS=OFF
  )
  if [[ "$name" == kglobalaccel ]]; then cmake_args+=(-D WITH_X11=ON); fi
  if [[ "$name" == kdesu ]]; then
    cmake_args+=(-D KDESU_USE_SUDO_DEFAULT=OFF -D KDESU_USE_DOAS_DEFAULT=OFF)
  fi
  cmake -G Ninja "${cmake_args[@]}" -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE6_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE6_BUILT=' "$PROGRESS")" -eq 6 ]]
for path in \
  /opt/kf6/lib/cmake/KF6ColorScheme/KF6ColorSchemeConfig.cmake \
  /opt/kf6/lib/cmake/KF6ConfigWidgets/KF6ConfigWidgetsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Service/KF6ServiceConfig.cmake \
  /opt/kf6/lib/cmake/KF6GlobalAccel/KF6GlobalAccelConfig.cmake \
  /opt/kf6/lib/cmake/KF6Package/KF6PackageConfig.cmake \
  /opt/kf6/lib/cmake/KF6Su/KF6SuConfig.cmake \
  /opt/kf6/lib/libKF6ColorScheme.so \
  /opt/kf6/lib/libKF6ConfigWidgets.so \
  /opt/kf6/lib/libKF6Service.so \
  /opt/kf6/lib/libKF6GlobalAccel.so \
  /opt/kf6/lib/libKF6Package.so \
  /opt/kf6/lib/libKF6Su.so; do [[ -e "$path" ]]; done
[[ -x /opt/kf6/bin/kbuildsycoca6 && -x /opt/kf6/bin/kpackagetool6 ]]
rm -rf /tmp/blfs-kf6-base6-smoke /tmp/blfs-kf6-base6-smoke-build
mkdir -p /tmp/blfs-kf6-base6-smoke
cat >/tmp/blfs-kf6-base6-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base6_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets DBus Xml)
find_package(KF6ColorScheme 6.17.0 REQUIRED CONFIG)
find_package(KF6ConfigWidgets 6.17.0 REQUIRED CONFIG)
find_package(KF6Service 6.17.0 REQUIRED CONFIG)
find_package(KF6GlobalAccel 6.17.0 REQUIRED CONFIG)
find_package(KF6Package 6.17.0 REQUIRED CONFIG)
find_package(KF6Su 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base6-smoke main.cpp)
target_link_libraries(blfs-kf6-base6-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets Qt6::DBus Qt6::Xml
  KF6::ColorScheme KF6::ConfigWidgets KF6::Service KF6::GlobalAccel KF6::Package KF6::Su)
EOF
cat >/tmp/blfs-kf6-base6-smoke/main.cpp <<'EOF'
#include <KColorScheme>
#include <KStandardAction>
#include <KService>
#include <KGlobalShortcutInfo>
#include <KPackage/Package>
#include <KPackage/PackageLoader>
#include <KDESu/PtyProcess>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QPalette>
#include <QString>
#include <QTemporaryDir>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  KColorScheme scheme(QPalette::Active, KColorScheme::View);
  if (!scheme.background().color().isValid()) return 1;
  const QString actionName = KStandardAction::name(KStandardAction::Open);
  if (actionName != QStringLiteral("file_open")) return 2;
  KService service(QStringLiteral("BLFS smoke"), QStringLiteral("/bin/true"), QStringLiteral("application-x-executable"));
  if (service.exec() != QStringLiteral("/bin/true")) return 3;
  KGlobalShortcutInfo shortcutInfo;
  if (!shortcutInfo.uniqueName().isEmpty() || !shortcutInfo.keys().isEmpty()) return 4;
  QTemporaryDir packageDir;
  if (!packageDir.isValid() || !QDir().mkpath(packageDir.path() + QStringLiteral("/contents/data"))) return 5;
  QFile data(packageDir.path() + QStringLiteral("/contents/data/hello.txt"));
  if (!data.open(QIODevice::WriteOnly) || data.write("hello") != 5) return 6;
  data.close();
  KPackage::Package package = KPackage::PackageLoader::self()->loadPackage(QStringLiteral("KPackage/Generic"), packageDir.path());
  if (!package.isValid() || !QFile::exists(package.filePath("data", QStringLiteral("hello.txt")))) return 7;
  KDESu::PtyProcess process;
  if (process.exec("/bin/true", {}) != 0 || process.waitForChild() != 0) return 8;
  std::printf("BLFS_KF6_BASE6_EXEC_OK=%s=%s=%s=%d\n", qVersion(), actionName.toUtf8().constData(),
              service.exec().toUtf8().constData(), package.isValid() ? 1 : 0);
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base6-smoke -B /tmp/blfs-kf6-base6-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base6-smoke-build
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base6-smoke-build/blfs-kf6-base6-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE6_EXEC_OK=6.9.2=file_open=/bin/true=1 ]]
readelf -h /tmp/blfs-kf6-base6-smoke-build/blfs-kf6-base6-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base6-smoke-build/blfs-kf6-base6-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE6_RESULT=ok\nPACKAGE_COUNT=6\nDEPENDENCY_COUNT=0\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE6_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\n'
  printf 'PACKAGES=kcolorscheme+kconfigwidgets+kservice+kglobalaccel+kpackage+kdesu\n'
  printf 'KCOLORSCHEME=native-offscreen-color-ok\nKCONFIGWIDGETS=native-standard-action-ok\n'
  printf 'KSERVICE=native-constructor-ok\nKGLOBALACCEL=info-object-no-daemon\n'
  printf 'KPACKAGE=native-generic-package-ok\nKDESU=native-pty-true-no-elevation\n'
  printf 'GLOBAL_SHORTCUT_RUNTIME=not-tested-no-daemon\nPRIVILEGE_ESCALATION=not-tested\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'NETWORKMANAGER_QT=deferred-networkmanager-backend\n'
  printf 'KDNSSD=deferred-avahi-backend\nKIMAGEFORMATS=deferred-plugin-validation\n'
  printf 'BASE5=preserved-pipeline-98\nXFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base6-smoke /tmp/blfs-kf6-base6-smoke-build
