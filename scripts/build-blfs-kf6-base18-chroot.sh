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
REPORT=/root/blfs-kf6-base18-report.txt
PROGRESS=/root/blfs-kf6-base18-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/make ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in Qt6Core Qt6Gui; do [[ -f "/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Holidays KF6Purpose KF6QuickCharts; do [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
pkg-config --exists glib-2.0 libxml-2.0 gobject-introspection-1.0
[[ -x /usr/bin/g-ir-scanner && -x /usr/bin/vapigen ]]
[[ ! -e /opt/kf6/lib/cmake/KF6CalendarCore && ! -e /usr/lib/libical.so ]]
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
extract_package libical-3.0.20.tar.gz libical-3.0.20
printf 'BUILD_BLFS_KF6_BASE18=libical\n'
cmake -S . -B build \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D SHARED_ONLY=yes \
  -D ICAL_BUILD_DOCS=false \
  -D GOBJECT_INTROSPECTION=true \
  -D ICAL_GLIB_VAPI=true \
  -D LIBICAL_BUILD_TESTING=ON \
  -W no-dev
make -C build -j1
make -C build test
make -C build install
cd /sources; rm -rf libical-3.0.20
printf 'BLFS_KF6_BASE18_DEPENDENCY_BUILT=libical-3.0.20\n' >>"$PROGRESS"
extract_package kcalendarcore-6.17.0.tar.xz kcalendarcore-6.17.0
mkdir build; cd build
printf 'BUILD_BLFS_KF6_BASE18=kcalendarcore\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBEXECDIR=libexec \
  -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -W no-dev ..
ninja
ninja install
cd /sources; rm -rf kcalendarcore-6.17.0
printf 'BLFS_KF6_BASE18_BUILT=kcalendarcore-6.17.0\n' >>"$PROGRESS"
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE18_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(grep -c '^BLFS_KF6_BASE18_DEPENDENCY_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion libical)" == 3.0.20 ]]
for path in \
  /usr/lib/libical.so \
  /usr/lib/libical_cxx.so \
  /usr/lib/libicalss.so \
  /usr/lib/libical-glib.so \
  /usr/lib/cmake/LibIcal/LibIcalConfig.cmake \
  /usr/lib/pkgconfig/libical.pc \
  /opt/kf6/lib/cmake/KF6CalendarCore/KF6CalendarCoreConfig.cmake \
  /opt/kf6/lib/libKF6CalendarCore.so; do [[ -e "$path" ]]; done
rm -rf /tmp/blfs-kf6-base18-smoke /tmp/blfs-kf6-base18-smoke-build /tmp/blfs-kf6-base18-runtime
mkdir -p /tmp/blfs-kf6-base18-smoke
cat >/tmp/blfs-kf6-base18-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base18_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui)
find_package(LibIcal 3.0 REQUIRED CONFIG)
find_package(KF6CalendarCore 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base18-smoke main.cpp)
target_link_libraries(blfs-kf6-base18-smoke PRIVATE Qt6::Core Qt6::Gui KF6::CalendarCore ical icalss icalvcal)
EOF
cat >/tmp/blfs-kf6-base18-smoke/main.cpp <<'EOF'
#include <KCalendarCore/Event>
#include <KCalendarCore/MemoryCalendar>
#include <QByteArray>
#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QString>
#include <QTime>
#include <QtGlobal>
#include <libical/icalcomponent.h>
#include <libical/icalparser.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const char *text = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nSUMMARY:native\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
  icalcomponent *root = icalparser_parse_string(text);
  if (!root) return 1;
  icalcomponent *event = icalcomponent_get_first_component(root, ICAL_VEVENT_COMPONENT);
  char *serialized = icalcomponent_as_ical_string(root);
  bool parsed = event && serialized && std::strstr(serialized, "native");
  std::free(serialized);
  icalcomponent_free(root);
  if (!parsed) return 2;
  KCalendarCore::MemoryCalendar calendar(QByteArrayLiteral("UTC"));
  KCalendarCore::Event::Ptr item(new KCalendarCore::Event);
  item->setUid(QStringLiteral("native-1"));
  item->setSummary(QStringLiteral("native"));
  item->setDtStart(QDateTime(QDate(2026, 1, 1), QTime(0, 0), Qt::UTC));
  if (!calendar.addEvent(item) || calendar.events().size() != 1) return 3;
  if (calendar.events().constFirst()->summary() != QStringLiteral("native")) return 4;
  std::printf("BLFS_KF6_BASE18_EXEC_OK=%s=libical=parse=calendar=native\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base18-smoke -B /tmp/blfs-kf6-base18-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-kf6-base18-smoke-build
install -d -m 0700 /tmp/blfs-kf6-base18-runtime
OUTPUT="$(XDG_RUNTIME_DIR=/tmp/blfs-kf6-base18-runtime QT_QPA_PLATFORM=offscreen \
  LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib /tmp/blfs-kf6-base18-smoke-build/blfs-kf6-base18-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE18_EXEC_OK=6.9.2=libical=parse=calendar=native ]]
readelf -h /tmp/blfs-kf6-base18-smoke-build/blfs-kf6-base18-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base18-smoke-build/blfs-kf6-base18-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_BASE18_RESULT=ok\nPACKAGE_COUNT=1\nDEPENDENCY_COUNT=1\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE18_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\nPACKAGES=kcalendarcore\nDEPENDENCIES=libical\n'
  printf 'LIBICAL=native-ical-parse\nKCALENDARCORE=native-memory-calendar-event\n'
  printf 'LIBICAL_TEST_SUITE=passed\nKCALENDARCORE_TEST_SUITE=not-run-BUILD_TESTING_OFF\n'
  printf 'TEST_SUITES=libical-passed-kcalendarcore-off\n'
  printf 'BASE17=preserved-pipeline-134\nBASE16=preserved-pipeline-129\nBASE15=preserved-pipeline-128\n'
  printf 'PLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base18-smoke /tmp/blfs-kf6-base18-smoke-build /tmp/blfs-kf6-base18-runtime
