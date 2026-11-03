#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base4-report.txt
PROGRESS=/root/blfs-kf6-base4-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /usr/bin/flex && -x /usr/bin/bison && -x /usr/bin/which ]]
pkg-config --exists libudev
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6ItemModels KF6ItemViews KF6Plotting KF6WidgetsAddons KF6WindowSystem; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6Solid KF6Sonnet KF6ThreadWeaver; do [[ ! -e "/opt/kf6/lib/cmake/$path" ]]; done
[[ ! -e /usr/bin/aspell && ! -e /usr/lib/libaspell.so ]]
[[ -x /usr/bin/xfce4-terminal ]]
: >"$PROGRESS"
extract_package() {
  local archive="$1" expected="$2" first
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"; package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
}
extract_package aspell-0.60.8.1.tar.gz aspell-0.60.8.1
sed -e 's/; i.*size)/, e = end(); i != e; ++i, ++size_)/' -i modules/speller/default/vector_hash-t.hpp
printf 'BUILD_BLFS_KF6_BASE4_DEPENDENCY=aspell\n'
./configure --prefix=/usr
make
make install
ln -svfn aspell-0.60 /usr/lib/aspell
install -v -m755 -d /usr/share/doc/aspell-0.60.8.1/aspell{,-dev}.html
install -v -m644 manual/aspell.html/* /usr/share/doc/aspell-0.60.8.1/aspell.html
install -v -m644 manual/aspell-dev.html/* /usr/share/doc/aspell-0.60.8.1/aspell-dev.html
[[ -e /usr/bin/ispell ]] || install -v -m755 scripts/ispell /usr/bin/
[[ -e /usr/bin/spell ]] || install -v -m755 scripts/spell /usr/bin/
cd /sources; rm -rf aspell-0.60.8.1
printf 'BLFS_KF6_BASE4_DEPENDENCY_BUILT=aspell-0.60.8.1\n' >>"$PROGRESS"
extract_package aspell6-en-2020.12.07-0.tar.bz2 aspell6-en-2020.12.07-0
printf 'BUILD_BLFS_KF6_BASE4_DEPENDENCY=aspell-en-dictionary\n'
./configure
make
make install
cd /sources; rm -rf aspell6-en-2020.12.07-0
printf 'BLFS_KF6_BASE4_DEPENDENCY_BUILT=aspell6-en-2020.12.07-0\n' >>"$PROGRESS"
[[ -x /usr/bin/aspell && -e /usr/lib/libaspell.so ]]
aspell dump dicts | grep -q '^en'
[[ -z "$(printf 'hello\n' | aspell list --lang=en)" ]]
/sbin/ldconfig
packages=(solid sonnet threadweaver)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE4=%s\n' "$name"
  cmake_args=(
    -D CMAKE_INSTALL_PREFIX=/opt/kf6
    -D CMAKE_INSTALL_LIBEXECDIR=libexec
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
    -D CMAKE_SKIP_INSTALL_RPATH=ON
    -D CMAKE_BUILD_TYPE=Release
    -D BUILD_TESTING=OFF
    -D BUILD_PYTHON_BINDINGS=OFF
  )
  if [[ "$name" == solid ]]; then cmake_args+=(-D USE_DBUS=ON -D UDEV_DISABLED=OFF); fi
  if [[ "$name" == sonnet ]]; then
    cmake_args+=(-D SONNET_USE_WIDGETS=ON -D SONNET_USE_QML=ON -D SONNET_NO_BACKENDS=OFF)
  fi
  cmake -G Ninja "${cmake_args[@]}" -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE4_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE4_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ "$(grep -c '^BLFS_KF6_BASE4_DEPENDENCY_BUILT=' "$PROGRESS")" -eq 2 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Solid/KF6SolidConfig.cmake \
  /opt/kf6/lib/cmake/KF6Sonnet/KF6SonnetConfig.cmake \
  /opt/kf6/lib/cmake/KF6ThreadWeaver/KF6ThreadWeaverConfig.cmake \
  /opt/kf6/lib/libKF6Solid.so \
  /opt/kf6/lib/libKF6SonnetCore.so \
  /opt/kf6/lib/libKF6SonnetUi.so \
  /opt/kf6/lib/libKF6ThreadWeaver.so \
  /opt/kf6/lib/qml/org/kde/sonnet/qmldir; do [[ -e "$path" ]]; done
find /opt/kf6/lib/plugins/kf6/sonnet -type f -name '*sonnet_aspell.so' -print -quit | grep -q .
rm -rf /tmp/blfs-kf6-base4-smoke /tmp/blfs-kf6-base4-smoke-build /tmp/blfs-kf6-base4-runtime
mkdir -p /tmp/blfs-kf6-base4-smoke
cat >/tmp/blfs-kf6-base4-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base4_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF6Solid 6.17.0 REQUIRED CONFIG)
find_package(KF6Sonnet 6.17.0 REQUIRED CONFIG)
find_package(KF6ThreadWeaver 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base4-smoke main.cpp)
target_link_libraries(blfs-kf6-base4-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
  KF6::Solid KF6::SonnetCore KF6::ThreadWeaver)
EOF
cat >/tmp/blfs-kf6-base4-smoke/main.cpp <<'EOF'
#include <Solid/Device>
#include <Sonnet/Speller>
#include <ThreadWeaver/Job>
#include <ThreadWeaver/JobPointer>
#include <ThreadWeaver/Queue>
#include <QAtomicInt>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QSharedPointer>
#include <QString>
#include <QUrl>
#include <QtGlobal>
#include <cstdio>
#include <memory>
class TestJob final : public ThreadWeaver::Job {
public:
  explicit TestJob(QAtomicInt &value) : value_(value) {}
protected:
  void run(ThreadWeaver::JobPointer, ThreadWeaver::Thread *) override { value_.fetchAndAddRelaxed(1); }
private:
  QAtomicInt &value_;
};
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  Solid::Device device{QString()};
  if (device.isValid()) return 1;
  const QString word = QStringLiteral("hello");
  Sonnet::Speller speller(QStringLiteral("en_US"));
  if (!speller.isValid() || !speller.isCorrect(word) || !speller.isMisspelled(QStringLiteral("zzzzqqqq"))) return 2;
  QAtomicInt counter(0);
  ThreadWeaver::Queue queue;
  ThreadWeaver::JobPointer job = QSharedPointer<TestJob>::create(counter);
  queue.enqueue(job);
  queue.finish();
  if (counter.loadRelaxed() != 1 || !queue.isIdle()) return 3;
  QQmlEngine engine;
  QQmlComponent component(&engine);
  component.setData(QByteArrayLiteral(
    "import QtQuick\nimport org.kde.sonnet 1.0\nItem { width: 18; height: 9 }\n"), QUrl());
  if (component.isError()) {
    const auto errors = component.errors();
    for (const auto &error : errors) qWarning("%s", error.toString().toUtf8().constData());
    return 4;
  }
  std::unique_ptr<QObject> object(component.create());
  QQuickItem *item = qobject_cast<QQuickItem *>(object.get());
  if (!item || item->width() != 18.0 || item->height() != 9.0) return 5;
  std::printf("BLFS_KF6_BASE4_EXEC_OK=%s=%s=%d=%d\n", qVersion(), word.toUtf8().constData(),
              counter.loadRelaxed(), static_cast<int>(item->width()));
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base4-smoke -B /tmp/blfs-kf6-base4-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base4-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base4-runtime
OUTPUT="$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_RUNTIME_DIR=/tmp/blfs-kf6-base4-runtime QML2_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml \
  QML_IMPORT_PATH=/opt/kf6/lib/qml:/opt/qt6/qml QT_PLUGIN_PATH=/opt/kf6/lib/plugins:/opt/qt6/plugins \
  QML_DISABLE_DISK_CACHE=1 LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /tmp/blfs-kf6-base4-smoke-build/blfs-kf6-base4-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE4_EXEC_OK=6.9.2=hello=1=18 ]]
readelf -h /tmp/blfs-kf6-base4-smoke-build/blfs-kf6-base4-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base4-smoke-build/blfs-kf6-base4-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE4_RESULT=ok\nPACKAGE_COUNT=3\nDEPENDENCY_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE4_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\n'
  printf 'PACKAGES=solid+sonnet+threadweaver\nDEPENDENCIES=aspell+aspell-en-dictionary\n'
  printf 'SONNET_BACKEND=aspell-with-en-dictionary\nASPELL_EN_SMOKE=hello-correct\n'
  printf 'THREADWEAVER_JOB=executed-and-finished\nSONNET_QML=native-offscreen-import-ok\n'
  printf 'SOLID_RUNTIME=not-tested-no-hardware\nUDISKS_RUNTIME=not-tested\n'
  printf 'ASPELL_TEST_SUITE=not-provided-upstream\nTEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'NETWORKMANAGER_QT=deferred-networkmanager-backend\n'
  printf 'KDNSSD=deferred-avahi-backend\nKIMAGEFORMATS=deferred-plugin-validation\n'
  printf 'BASE3=preserved-pipeline-94\nXFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base4-smoke /tmp/blfs-kf6-base4-smoke-build /tmp/blfs-kf6-base4-runtime
