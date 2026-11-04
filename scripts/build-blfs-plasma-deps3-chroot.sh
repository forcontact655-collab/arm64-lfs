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
REPORT=/root/blfs-plasma-deps3-report.txt
PROGRESS=/root/blfs-plasma-deps3-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/meson && -x /usr/bin/pip3 ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -f /opt/kf6/lib/cmake/KF6CoreAddons/KF6CoreAddonsConfig.cmake && -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake ]]
[[ "$(pkg-config --modversion alsa)" == 1.2.14 && "$(pkg-config --modversion glib-2.0)" == 2.84.4 ]]
[[ -f /usr/lib/libpulse.so && -f /usr/include/pulse/pulseaudio.h ]]
[[ ! -e /usr/include/crack.h && ! -e /usr/include/pwquality.h && ! -e /usr/include/phonon4qt6 && ! -e /usr/include/pipewire-0.3 ]]
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

extract_package cracklib-2.10.3.tar.xz cracklib-2.10.3
printf 'BUILD_BLFS_PLASMA_DEPS3=cracklib\n'
CPPFLAGS="${CPPFLAGS:-} -I/usr/include/python3.13" ./configure \
  --prefix=/usr \
  --disable-static \
  --with-default-dict=/usr/lib/cracklib/pw_dict
make
make install
install -v -m755 -d /usr/share/dict /usr/lib/cracklib
xzcat /sources/cracklib-words-2.10.3.xz > /usr/share/dict/cracklib-words
ln -v -sf cracklib-words /usr/share/dict/words
printf '%s\n' "$(hostname)" > /usr/share/dict/cracklib-extra-words
create-cracklib-dict /usr/share/dict/cracklib-words /usr/share/dict/cracklib-extra-words
make test
cd /sources; rm -rf cracklib-2.10.3
printf 'BLFS_PLASMA_DEPS3_BUILT=cracklib-2.10.3\n' >>"$PROGRESS"

extract_package libpwquality-1.4.5.tar.bz2 libpwquality-1.4.5
printf 'BUILD_BLFS_PLASMA_DEPS3=libpwquality\n'
./configure --prefix=/usr \
  --disable-static \
  --with-securedir=/usr/lib/security \
  --disable-python-bindings
make
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$PWD/python"
make install
/sbin/ldconfig
pip3 install --no-index --find-links dist --no-user pwquality
python3 -c 'import pwquality'
cd /sources; rm -rf libpwquality-1.4.5
printf 'BLFS_PLASMA_DEPS3_BUILT=libpwquality-1.4.5\n' >>"$PROGRESS"

extract_package phonon-4.12.0.tar.xz phonon-4.12.0
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS3=phonon\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D PHONON_BUILD_QT5=OFF \
  -D PHONON_BUILD_QT6=ON \
  -D "CMAKE_PREFIX_PATH=/opt/qt6;/opt/kf6;/usr" \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -W no-dev ..
ninja
ninja install
cd /sources; rm -rf phonon-4.12.0
printf 'BLFS_PLASMA_DEPS3_BUILT=phonon-4.12.0\n' >>"$PROGRESS"

extract_package pipewire-1.4.7.tar.bz2 pipewire-1.4.7
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS3=pipewire\n'
meson setup --prefix=/usr \
  --libdir=/usr/lib \
  --buildtype=release \
  -D session-managers="[]" \
  ..
ninja
ninja test
ninja install
cd /sources; rm -rf pipewire-1.4.7
printf 'BLFS_PLASMA_DEPS3_BUILT=pipewire-1.4.7\n' >>"$PROGRESS"

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA_DEPS3_BUILT=' "$PROGRESS")" -eq 4 ]]
[[ "$(pkg-config --modversion pwquality)" == 1.4.5 ]]
[[ "$(pkg-config --modversion phonon4qt6)" == 4.12.0 ]]
[[ "$(pkg-config --modversion libpipewire-0.3)" == 1.4.7 ]]
for path in \
  /usr/include/crack.h \
  /usr/lib/libcrack.so \
  /usr/share/dict/cracklib-words \
  /usr/include/pwquality.h \
  /usr/lib/libpwquality.so \
  /usr/bin/pwscore \
  /usr/include/phonon4qt6/phonon/phononnamespace.h \
  /usr/lib/libphonon4qt6.so \
  /usr/lib/cmake/phonon4qt6/Phonon4Qt6Config.cmake \
  /usr/include/pipewire-0.3/pipewire/pipewire.h \
  /usr/lib/libpipewire-0.3.so \
  /usr/bin/pipewire; do [[ -e "$path" ]]; done

rm -rf /tmp/blfs-plasma-deps3-smoke /tmp/blfs-plasma-deps3-smoke-build /tmp/blfs-plasma-deps3-smoke-stderr.log
mkdir -p /tmp/blfs-plasma-deps3-smoke
cat >/tmp/blfs-plasma-deps3-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_plasma_deps3_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Widgets Core5Compat)
find_package(Phonon4Qt6 4.12.0 REQUIRED CONFIG)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PWQUALITY REQUIRED IMPORTED_TARGET pwquality)
pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)
find_path(CRACK_INCLUDE_DIR NAMES crack.h REQUIRED)
find_library(CRACK_LIBRARY NAMES crack REQUIRED)
add_executable(blfs-plasma-deps3-smoke main.cpp)
target_include_directories(blfs-plasma-deps3-smoke PRIVATE "${CRACK_INCLUDE_DIR}")
target_link_libraries(blfs-plasma-deps3-smoke PRIVATE
  Qt6::Core Qt6::Widgets Phonon::phonon4qt6
  PkgConfig::PWQUALITY PkgConfig::PIPEWIRE "${CRACK_LIBRARY}")
EOF
cat >/tmp/blfs-plasma-deps3-smoke/main.cpp <<'EOF'
#include <crack.h>
#include <pwquality.h>
#include <phonon/phononnamespace.h>
#include <pipewire/pipewire.h>
#include <QCoreApplication>
#include <cstdio>
#include <cstdlib>
#include <cstring>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const char *dict = GetDefaultCracklibDict();
  if (!dict || std::strcmp(dict, "/usr/lib/cracklib/pw_dict") != 0) {
    std::fprintf(stderr, "CRACKLIB_DEFAULT_DICT_FAILED\n");
    return 1;
  }
  const char *reason = FascistCheck("password", dict);
  if (!reason || std::strstr(reason, "error loading")) {
    std::fprintf(stderr, "CRACKLIB_DICTIONARY_FAILED\n");
    return 2;
  }
  pwquality_settings_t *pwq = pwquality_default_settings();
  if (!pwq) {
    std::fprintf(stderr, "PWQUALITY_SETTINGS_FAILED\n");
    return 3;
  }
  if (pwquality_set_str_value(pwq, PWQ_SETTING_DICT_PATH, dict) != 0) {
    pwquality_free_settings(pwq);
    std::fprintf(stderr, "PWQUALITY_DICT_SETTING_FAILED\n");
    return 4;
  }
  if (pwquality_check(pwq, "password", nullptr, nullptr, nullptr) >= 0) {
    pwquality_free_settings(pwq);
    std::fprintf(stderr, "PWQUALITY_WEAK_PASSWORD_ACCEPTED\n");
    return 5;
  }
  char *generated = nullptr;
  const int generate_status = pwquality_generate(pwq, 56, &generated);
  pwquality_free_settings(pwq);
  if (generate_status != 0 || !generated || !generated[0]) {
    std::free(generated);
    std::fprintf(stderr, "PWQUALITY_GENERATE_FAILED=%d\n", generate_status);
    return 6;
  }
  std::free(generated);
  if (std::strcmp(Phonon::phononVersion(), "4.12.0") != 0) {
    std::fprintf(stderr, "PHONON_VERSION_FAILED\n");
    return 7;
  }
  int pipe_argc = 0;
  char **pipe_argv = nullptr;
  pw_init(&pipe_argc, &pipe_argv);
  const char *pipe_version = pw_get_library_version();
  const bool pipe_ok = pipe_version && std::strcmp(pipe_version, "1.4.7") == 0;
  pw_deinit();
  if (!pipe_ok) {
    std::fprintf(stderr, "PIPEWIRE_VERSION_FAILED\n");
    return 8;
  }
  std::printf("BLFS_PLASMA_DEPS3_EXEC_OK=crack=reject=pwq=generate=phonon=4.12.0=pipewire=1.4.7\n");
  return 0;
}
EOF
cmake -S /tmp/blfs-plasma-deps3-smoke -B /tmp/blfs-plasma-deps3-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/usr;/opt/qt6;/opt/kf6"
ninja -C /tmp/blfs-plasma-deps3-smoke-build
set +e
OUTPUT="$(LD_LIBRARY_PATH=/usr/lib:/opt/qt6/lib:/opt/kf6/lib \
  /tmp/blfs-plasma-deps3-smoke-build/blfs-plasma-deps3-smoke \
  2>/tmp/blfs-plasma-deps3-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma-deps3-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA_DEPS3_EXEC_OK=crack=reject=pwq=generate=phonon=4.12.0=pipewire=1.4.7 ]]
readelf -h /tmp/blfs-plasma-deps3-smoke-build/blfs-plasma-deps3-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma-deps3-smoke-build/blfs-plasma-deps3-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA_DEPS3_RESULT=ok\nPACKAGE_COUNT=4\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=5\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS3_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'CRACKLIB=2.10.3\nCRACKLIB_WORDS=2.10.3\nLIBPWQUALITY=1.4.5\nPHONON=4.12.0\nPIPEWIRE=1.4.7\nPACKAGES=cracklib+libpwquality+phonon+pipewire\nDEPENDENCIES=existing-qt6-kf6-pulseaudio-alsa-dbus\n'
  printf 'CRACKLIB_TESTS=make-test-passed\nCRACKLIB_SMOKE=native-dictionary-weak-password-rejected\nLIBPWQUALITY_TEST_SUITE=not-provided-by-upstream\nLIBPWQUALITY_SMOKE=native-check-and-generate\nLIBPWQUALITY_PYTHON=native-import\n'
  printf 'PHONON_TESTS=not-run-no-test-suite\nPHONON_SMOKE=native-version-no-playback\nPHONON_VLC_BACKEND=not-built-deferred\nPIPEWIRE_TESTS=ninja-test-passed\nPIPEWIRE_SMOKE=native-init-version-no-daemon\nPIPEWIRE_SESSION_MANAGER=disabled-empty-list\nPIPEWIRE_DAEMON=not-started\n'
  printf 'PLASMA_PULSE1=preserved-pipeline-153\nPLASMA_DEPS2=preserved-pipeline-148\nPLASMA_DEPS1=preserved-pipeline-147\nPLASMA=not-built\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma-deps3-smoke /tmp/blfs-plasma-deps3-smoke-build /tmp/blfs-plasma-deps3-smoke-stderr.log
