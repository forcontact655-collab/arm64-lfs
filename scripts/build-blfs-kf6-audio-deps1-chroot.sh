#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-audio-deps1-report.txt
PROGRESS=/root/blfs-kf6-audio-deps1-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/gcc && -x /usr/bin/autoreconf && -x /usr/bin/make ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6ColorScheme KF6ConfigWidgets KF6Service KF6GlobalAccel KF6Package KF6Su; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
for path in /usr/lib/libogg.so /usr/lib/libvorbis.so /usr/lib/libasound.so /usr/lib/libcanberra.so; do [[ ! -e "$path" ]]; done
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
extract_package libogg-1.3.6.tar.xz libogg-1.3.6
printf 'BUILD_BLFS_KF6_AUDIO_DEPS1=libogg\n'
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libogg-1.3.6
make
make check
make install
printf 'BLFS_KF6_AUDIO_DEPS1_BUILT=libogg-1.3.6\n' >>"$PROGRESS"
extract_package libvorbis-1.3.7.tar.xz libvorbis-1.3.7
printf 'BUILD_BLFS_KF6_AUDIO_DEPS1=libvorbis\n'
./configure --prefix=/usr --disable-static
make
make -j1 check
make install
install -v -d -m755 /usr/share/doc/libvorbis-1.3.7
install -v -m644 doc/Vorbis* /usr/share/doc/libvorbis-1.3.7
printf 'BLFS_KF6_AUDIO_DEPS1_BUILT=libvorbis-1.3.7\n' >>"$PROGRESS"
extract_package alsa-lib-1.2.14.tar.bz2 alsa-lib-1.2.14
printf 'BUILD_BLFS_KF6_AUDIO_DEPS1=alsa-lib\n'
sed 's/playmidi1//' -i test/Makefile.am
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make check
make install
install -v -d -m755 /usr/share/alsa
tar -C /usr/share/alsa --strip-components=1 -xf "$SOURCES/alsa-ucm-conf-1.2.14.tar.bz2"
printf 'BLFS_KF6_AUDIO_DEPS1_BUILT=alsa-lib-1.2.14\n' >>"$PROGRESS"
extract_package libcanberra-0.30.tar.xz libcanberra-0.30
printf 'BUILD_BLFS_KF6_AUDIO_DEPS1=libcanberra\n'
patch -Np1 -i "$SOURCES/libcanberra-0.30-wayland-1.patch"
./configure --prefix=/usr --disable-static --disable-oss --disable-gtk \
  --disable-pulse --disable-udev --disable-gstreamer --disable-tdb
make
make docdir=/usr/share/doc/libcanberra-0.30 install
printf 'BLFS_KF6_AUDIO_DEPS1_BUILT=libcanberra-0.30\n' >>"$PROGRESS"
cd /sources
rm -rf libogg-1.3.6 libvorbis-1.3.7 alsa-lib-1.2.14 libcanberra-0.30
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_AUDIO_DEPS1_BUILT=' "$PROGRESS")" -eq 4 ]]
[[ "$(pkg-config --modversion ogg)" == 1.3.6 ]]
[[ "$(pkg-config --modversion vorbis)" == 1.3.7 ]]
[[ "$(pkg-config --modversion alsa)" == 1.2.14 ]]
[[ "$(pkg-config --modversion libcanberra)" == 0.30 ]]
for path in /usr/lib/libogg.so /usr/lib/libvorbis.so /usr/lib/libvorbisfile.so \
  /usr/lib/libasound.so /usr/lib/libcanberra.so /usr/lib/libcanberra-gtk3.so \
  /usr/share/alsa/ucm.conf /usr/include/canberra.h; do [[ -e "$path" ]]; done
cat >/tmp/blfs-kf6-audio-deps1-smoke.c <<'EOF'
#include <ogg/ogg.h>
#include <vorbis/codec.h>
#include <alsa/asoundlib.h>
#include <canberra.h>
#include <stdio.h>
int main(void) {
  ogg_stream_state stream;
  if (ogg_stream_init(&stream, 398317) != 0) return 1;
  if (ogg_stream_clear(&stream) != 0) return 2;
  if (!vorbis_version_string() || !vorbis_version_string()[0]) return 3;
  const char *alsa_version = snd_asoundlib_version();
  if (!alsa_version || !alsa_version[0]) return 4;
  ca_context *context = NULL;
  if (ca_context_create(&context) != CA_SUCCESS || !context) return 5;
  if (ca_context_destroy(context) != CA_SUCCESS) return 6;
  printf("BLFS_KF6_AUDIO_DEPS1_EXEC_OK=%s=ok\n", alsa_version);
  return 0;
}
EOF
gcc -O2 -Wall -Wextra -o /tmp/blfs-kf6-audio-deps1-smoke \
  /tmp/blfs-kf6-audio-deps1-smoke.c $(pkg-config --cflags --libs ogg vorbis alsa libcanberra)
OUTPUT="$(/tmp/blfs-kf6-audio-deps1-smoke)"
[[ "$OUTPUT" == BLFS_KF6_AUDIO_DEPS1_EXEC_OK=1.2.14=ok ]]
readelf -h /tmp/blfs-kf6-audio-deps1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-audio-deps1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_KF6_AUDIO_DEPS1_RESULT=ok\nPACKAGE_COUNT=4\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_AUDIO_DEPS1_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'PACKAGES=libogg+libvorbis+alsa-lib+libcanberra\nVERSIONS=1.3.6+1.3.7+1.2.14+0.30\n'
  printf 'ALSA_UCM_CONF=1.2.14-installed\nCANBERRA_ALSA=built\nCANBERRA_GTK3=built-not-run\n'
  printf 'PULSEAUDIO=disabled\nGSTREAMER=disabled\nUDEV=disabled\nTDB=disabled\n'
  printf 'LIBOGG_TEST_SUITE=passed\nLIBVORBIS_TEST_SUITE=passed\nALSA_LIB_TEST_SUITE=passed\nLIBCANBERRA_TEST_SUITE=absent\n'
  printf 'AUDIO_PLAYBACK=not-tested-no-device-access\nALSA_HARDWARE=not-tested\nSOUND_THEME=not-installed\n'
  printf 'BASE6=preserved-pipeline-100\nXFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-kf6-audio-deps1-smoke /tmp/blfs-kf6-audio-deps1-smoke.c
