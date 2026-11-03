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
REPORT=/root/blfs-plasma-pulse1-report.txt
PROGRESS=/root/blfs-plasma-pulse1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/meson ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -f /opt/kf6/lib/cmake/KF6CoreAddons/KF6CoreAddonsConfig.cmake && -f /opt/kf6/lib/cmake/ECM/ECMConfig.cmake ]]
[[ -x /usr/bin/sassc && -x /usr/bin/xdotool && -f /usr/include/taglib/tstring.h && -f /usr/include/utf8cpp/utf8.h ]]
[[ "$(pkg-config --modversion alsa)" == 1.2.14 && "$(pkg-config --modversion glib-2.0)" == 2.84.4 ]]
[[ ! -e /usr/include/sndfile.h && ! -e /usr/include/pulse && ! -e /opt/kf6/lib/cmake/KF6PulseAudioQt ]]
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

extract_package libsndfile-1.2.2.tar.xz libsndfile-1.2.2
printf 'BUILD_BLFS_PLASMA_PULSE1=libsndfile\n'
sed '/typedef enum/,/bool ;/d' -i src/ALAC/alac_{en,de}coder.c
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libsndfile-1.2.2
make
make check
make install
cd /sources; rm -rf libsndfile-1.2.2
printf 'BLFS_PLASMA_PULSE1_BUILT=libsndfile-1.2.2\n' >>"$PROGRESS"

extract_package pulseaudio-17.0.tar.xz pulseaudio-17.0
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_PULSE1=pulseaudio\n'
meson setup --prefix=/usr \
  --buildtype=release \
  -D database=gdbm \
  -D doxygen=false \
  -D bluez5=disabled \
  -D tests=false \
  -D glib=enabled \
  ..
ninja
ninja install
rm -f /usr/share/dbus-1/system.d/pulseaudio-system.conf
cd /sources; rm -rf pulseaudio-17.0
printf 'BLFS_PLASMA_PULSE1_BUILT=pulseaudio-17.0\n' >>"$PROGRESS"

extract_package pulseaudio-qt-1.7.0.tar.xz pulseaudio-qt-1.7.0
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_PULSE1=pulseaudio-qt\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D "CMAKE_PREFIX_PATH=/opt/qt6;/opt/kf6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF \
  -W no-dev ..
ninja
ninja install
cd /sources; rm -rf pulseaudio-qt-1.7.0
printf 'BLFS_PLASMA_PULSE1_BUILT=pulseaudio-qt-1.7.0\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA_PULSE1_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ "$(pkg-config --modversion sndfile)" == 1.2.2 ]]
[[ "$(pkg-config --modversion libpulse)" == 17.0 ]]
[[ "$(pkg-config --modversion libpulse-mainloop-glib)" == 17.0 ]]
for path in \
  /usr/include/sndfile.h \
  /usr/lib/libsndfile.so \
  /usr/include/pulse/pulseaudio.h \
  /usr/include/pulse/version.h \
  /usr/lib/libpulse.so \
  /usr/lib/libpulse-mainloop-glib.so \
  /usr/bin/pulseaudio \
  /opt/kf6/lib/cmake/KF6PulseAudioQt/KF6PulseAudioQtConfig.cmake \
  /opt/kf6/lib/libKF6PulseAudioQt.so \
  /opt/kf6/include/KF6/KF6PulseAudioQt/PulseAudioQt/Context; do [[ -e "$path" ]]; done

rm -rf /tmp/blfs-plasma-pulse1-smoke /tmp/blfs-plasma-pulse1-smoke-build /tmp/blfs-plasma-pulse1-smoke-stderr.log
mkdir -p /tmp/blfs-plasma-pulse1-smoke
cat >/tmp/blfs-plasma-pulse1-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma_pulse1_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core)
find_package(KF6PulseAudioQt 1.7.0 REQUIRED CONFIG)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SNDFILE REQUIRED IMPORTED_TARGET sndfile)
pkg_check_modules(LIBPULSE REQUIRED IMPORTED_TARGET libpulse)
add_executable(blfs-plasma-pulse1-smoke main.cpp)
target_link_libraries(blfs-plasma-pulse1-smoke PRIVATE
  Qt6::Core KF6::PulseAudioQt PkgConfig::SNDFILE PkgConfig::LIBPULSE)
EOF
cat >/tmp/blfs-plasma-pulse1-smoke/main.cpp <<'EOF'
#include <PulseAudioQt/Context>
#include <QCoreApplication>
#include <pulse/version.h>
#include <pulse/volume.h>
#include <sndfile.h>
#include <QtGlobal>
#include <cstdio>
#include <cstdlib>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const char *path = "/tmp/blfs-plasma-pulse1-smoke.wav";
  SF_INFO info{};
  info.samplerate = 44100;
  info.channels = 1;
  info.format = SF_FORMAT_WAV | SF_FORMAT_PCM_16;
  SNDFILE *file = sf_open(path, SFM_WRITE, &info);
  if (!file) {
    std::fprintf(stderr, "SNDFILE_WRITE_OPEN_FAILED %s\n", sf_strerror(nullptr));
    return 1;
  }
  const short samples[4] = {0, 1, -1, 0};
  if (sf_writef_short(file, samples, 4) != 4 || sf_close(file) != 0) {
    std::fprintf(stderr, "SNDFILE_WRITE_FAILED\n");
    return 2;
  }
  SF_INFO read_info{};
  file = sf_open(path, SFM_READ, &read_info);
  short decoded[4] = {};
  if (!file || read_info.frames != 4 || read_info.samplerate != 44100 ||
      read_info.channels != 1 || sf_readf_short(file, decoded, 4) != 4 || sf_close(file) != 0) {
    std::fprintf(stderr, "SNDFILE_READ_FAILED\n");
    return 3;
  }
  std::remove(path);
  for (int i = 0; i < 4; ++i) {
    if (decoded[i] != samples[i]) {
      std::fprintf(stderr, "SNDFILE_ROUNDTRIP_FAILED\n");
      return 4;
    }
  }
  const char *pulse_version = pa_get_library_version();
  if (!pulse_version || !pulse_version[0]) {
    std::fprintf(stderr, "PULSE_VERSION_FAILED\n");
    return 5;
  }
  if (PulseAudioQt::normalVolume() != static_cast<qint64>(PA_VOLUME_NORM) ||
      PulseAudioQt::minimumVolume() != static_cast<qint64>(PA_VOLUME_MUTED)) {
    std::fprintf(stderr, "PULSEAUDIOQT_VOLUME_FAILED\n");
    return 6;
  }
  std::printf("BLFS_PLASMA_PULSE1_EXEC_OK=%s=sndfile=wav=pulse=version=qt=volume\n", qVersion());
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma-pulse1-smoke -B /tmp/blfs-plasma-pulse1-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6;/usr"
ninja -C /tmp/blfs-plasma-pulse1-smoke-build
set +e
OUTPUT="$(LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib:/usr/lib \
  /tmp/blfs-plasma-pulse1-smoke-build/blfs-plasma-pulse1-smoke \
  2>/tmp/blfs-plasma-pulse1-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma-pulse1-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA_PULSE1_EXEC_OK=6.9.2=sndfile=wav=pulse=version=qt=volume ]]
readelf -h /tmp/blfs-plasma-pulse1-smoke-build/blfs-plasma-pulse1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma-pulse1-smoke-build/blfs-plasma-pulse1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA_PULSE1_RESULT=ok\nPACKAGE_COUNT=3\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=3\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA_PULSE1_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'QT=6.9.2\nLIBSNDFILE=1.2.2\nPULSEAUDIO=17.0\nPULSEAUDIO_QT=1.7.0\nPACKAGES=libsndfile+pulseaudio+pulseaudio-qt\nDEPENDENCIES=existing-kf6-qt6-glib-dbus-alsa-xorg\n'
  printf 'LIBSNDFILE_TESTS=make-check-passed\nLIBSNDFILE_SMOKE=native-wav-write-read-roundtrip\nPULSEAUDIO_SMOKE=native-library-version-no-daemon\nPULSEAUDIO_QT_SMOKE=native-volume-constants-no-daemon\n'
  printf 'PULSEAUDIO_TESTS=disabled-check-unavailable\nPULSEAUDIO_QT_TESTS=not-run-BUILD_TESTING_OFF\nAUDIO_RUNTIME=file-only-no-device\nPULSE_DAEMON=not-started\nPLASMA_DEPS2=preserved-pipeline-148\nPLASMA_DEPS1=preserved-pipeline-147\nKIRIGAMI_ADDONS=preserved-pipeline-145\nPLASMA=not-built\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma-pulse1-smoke /tmp/blfs-plasma-pulse1-smoke-build /tmp/blfs-plasma-pulse1-smoke-stderr.log /tmp/blfs-plasma-pulse1-smoke.wav
