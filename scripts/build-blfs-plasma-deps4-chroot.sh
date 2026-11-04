#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
export MAKEFLAGS="-j$(nproc)"
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --disable-static"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma-deps4-report.txt
PROGRESS=/root/blfs-plasma-deps4-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/gcc && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /usr/bin/meson ]]
[[ "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -x /usr/bin/Xorg && -x /usr/bin/cvt && -x /usr/bin/di-edid-decode ]]
[[ -f /usr/share/hwdata/pci.ids && -f /usr/share/hwdata/pnp.ids ]]
[[ "$(pkg-config --modversion libdisplay-info)" == 0.3.0 ]]
[[ "$(pkg-config --modversion libxcvt)" == 0.1.3 ]]
[[ ! -e /usr/include/archive.h && ! -e /usr/include/libavcodec/avcodec.h && ! -e /usr/include/opencv4/opencv2/core.hpp ]]
[[ ! -e /usr/include/mtdev.h && ! -e /usr/include/libevdev-1.0/libevdev/libevdev.h && ! -e /usr/lib/xorg/modules/input/evdev_drv.so ]]
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
finish_package() {
  local package_dir="$1"
  cd /sources
  rm -rf "$package_dir"
  printf 'BLFS_PLASMA_DEPS4_BUILT=%s\n' "$package_dir" >>"$PROGRESS"
  /sbin/ldconfig
}

# libarchive is a required OpenCV dependency in the BLFS 12.4 instructions.
extract_package libarchive-3.8.1.tar.xz libarchive-3.8.1
printf 'BUILD_BLFS_PLASMA_DEPS4=libarchive\n'
./configure --prefix=/usr --disable-static
make
make check
make install
ln -sfv bsdunzip /usr/bin/unzip
finish_package libarchive-3.8.1

# Apply the BLFS-required Chromium API patch.  Optional codec backends that
# are not present in the accepted rootfs are deliberately not enabled.
extract_package ffmpeg-7.1.1.tar.xz ffmpeg-7.1.1
printf 'BUILD_BLFS_PLASMA_DEPS4=ffmpeg\n'
patch -Np1 -i /sources/ffmpeg-7.1.1-chromium_method-1.patch
./configure --prefix=/usr \
  --enable-gpl \
  --enable-version3 \
  --disable-static \
  --enable-shared \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --enable-libfreetype \
  --enable-libvorbis \
  --enable-libpulse \
  --enable-openssl \
  --ignore-tests=enhanced-flv-av1 \
  --docdir=/usr/share/doc/ffmpeg-7.1.1
make
gcc tools/qt-faststart.c -o tools/qt-faststart
make install
install -v -m755 tools/qt-faststart /usr/bin
install -v -m755 -d /usr/share/doc/ffmpeg-7.1.1
install -v -m644 doc/*.txt /usr/share/doc/ffmpeg-7.1.1
finish_package ffmpeg-7.1.1

# OpenCV follows FFmpeg.  IPP is disabled on aarch64 so configuration cannot
# fetch an architecture-specific archive; no contrib modules are downloaded.
extract_package opencv-4.12.0.tar.gz opencv-4.12.0
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS4=opencv\n'
cmake -G Ninja \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D ENABLE_CXX11=ON \
  -D BUILD_PERF_TESTS=OFF \
  -D BUILD_TESTS=OFF \
  -D WITH_FFMPEG=ON \
  -D WITH_XINE=OFF \
  -D WITH_GSTREAMER=OFF \
  -D WITH_IPP=OFF \
  -D BUILD_opencv_python3=OFF \
  -D BUILD_opencv_java=OFF \
  -D ENABLE_PRECOMPILED_HEADERS=OFF \
  -D CMAKE_SKIP_INSTALL_RPATH=ON \
  -D BUILD_WITH_DEBUG_INFO=OFF \
  -D OPENCV_GENERATE_PKGCONFIG=ON \
  -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -W no-dev ..
ninja
ninja install
finish_package opencv-4.12.0

# Xorg Evdev's two required input libraries precede the driver itself.
extract_package mtdev-1.1.7.tar.bz2 mtdev-1.1.7
printf 'BUILD_BLFS_PLASMA_DEPS4=mtdev\n'
./configure --prefix=/usr --disable-static
make
make install
finish_package mtdev-1.1.7

extract_package libevdev-1.13.4.tar.xz libevdev-1.13.4
mkdir build; cd build
printf 'BUILD_BLFS_PLASMA_DEPS4=libevdev\n'
meson setup .. \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -D documentation=disabled \
  -D tests=disabled
ninja
ninja install
finish_package libevdev-1.13.4

extract_package xf86-input-evdev-2.11.0.tar.xz xf86-input-evdev-2.11.0
printf 'BUILD_BLFS_PLASMA_DEPS4=xf86-input-evdev\n'
./configure $XORG_CONFIG
make
make install
finish_package xf86-input-evdev-2.11.0

rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_PLASMA_DEPS4_BUILT=' "$PROGRESS")" -eq 6 ]]
[[ "$(pkg-config --modversion libarchive)" == 3.8.1 ]]
[[ "$(pkg-config --modversion opencv4)" == 4.12.0 ]]
[[ "$(pkg-config --modversion mtdev)" == 1.1.7 ]]
[[ "$(pkg-config --modversion libevdev)" == 1.13.4 ]]
[[ "$(pkg-config --modversion libdisplay-info)" == 0.3.0 ]]
[[ "$(pkg-config --modversion libxcvt)" == 0.1.3 ]]
for path in \
  /usr/include/archive.h \
  /usr/lib/libarchive.so \
  /usr/bin/bsdtar \
  /usr/include/libavcodec/avcodec.h \
  /usr/lib/libavcodec.so \
  /usr/bin/ffmpeg \
  /usr/bin/ffprobe \
  /usr/bin/qt-faststart \
  /usr/include/opencv4/opencv2/core.hpp \
  /usr/lib/libopencv_core.so \
  /usr/lib/pkgconfig/opencv4.pc \
  /usr/include/mtdev.h \
  /usr/lib/libmtdev.so \
  /usr/include/libevdev-1.0/libevdev/libevdev.h \
  /usr/lib/libevdev.so \
  /usr/lib/xorg/modules/input/evdev_drv.so; do [[ -e "$path" ]]; done

# Exercise FFmpeg without a device or network: encode one internal FFV1
# frame and read it back with ffprobe.
rm -f /tmp/blfs-plasma-deps4-ffmpeg.mkv /tmp/blfs-plasma-deps4-ffprobe.txt
ffmpeg -hide_banner -loglevel error -f lavfi -i color=c=blue:s=32x32:d=0.2 \
  -frames:v 1 -c:v ffv1 -y /tmp/blfs-plasma-deps4-ffmpeg.mkv
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height \
  -of default=noprint_wrappers=1 /tmp/blfs-plasma-deps4-ffmpeg.mkv \
  >/tmp/blfs-plasma-deps4-ffprobe.txt
grep -qxF 'codec_name=ffv1' /tmp/blfs-plasma-deps4-ffprobe.txt
grep -qxF 'width=32' /tmp/blfs-plasma-deps4-ffprobe.txt
grep -qxF 'height=32' /tmp/blfs-plasma-deps4-ffprobe.txt
CVT_OUTPUT="$(cvt 640 480 60)"
[[ "$CVT_OUTPUT" == *Modeline* ]]

# One native C++ smoke covers the newly built libraries and the already
# accepted libdisplay-info installation.  No X server, input device, camera,
# audio device or OpenCV GUI is opened.
rm -rf /tmp/blfs-plasma-deps4-smoke /tmp/blfs-plasma-deps4-smoke-build /tmp/blfs-plasma-deps4-smoke-stderr.log
mkdir -p /tmp/blfs-plasma-deps4-smoke
cat >/tmp/blfs-plasma-deps4-smoke/main.cpp <<'EOF'
#include <archive.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libdisplay-info/info.h>
#include <libdisplay-info/edid.h>
#include <libevdev/libevdev.h>
#include <mtdev.h>
#include <mtdev-plumbing.h>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/videoio.hpp>
#include <opencv2/videoio/registry.hpp>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

static int hex_value(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

int main() {
  if (!std::strstr(archive_version_string(), "3.8.1")) return 1;
  struct archive *archive = archive_read_new();
  if (!archive) return 2;
  archive_read_free(archive);
  if (!std::strstr(av_version_info(), "7.1.1")) return 3;
  if (!avcodec_find_encoder(AV_CODEC_ID_FFV1)) return 4;

  cv::Mat input(4, 4, CV_8UC1, cv::Scalar(0));
  input.at<unsigned char>(0, 0) = 255;
  cv::Mat blurred;
  cv::GaussianBlur(input, blurred, cv::Size(3, 3), 0.0);
  if (blurred.empty() || cv::getVersionString() != "4.12.0") return 5;
  if (!cv::videoio_registry::hasBackend(cv::CAP_FFMPEG)) return 6;

  struct libevdev *evdev = libevdev_new();
  if (!evdev) return 7;
  libevdev_set_name(evdev, "vim-native-smoke");
  const bool evdev_ok = std::strcmp(libevdev_get_name(evdev), "vim-native-smoke") == 0;
  libevdev_free(evdev);
  if (!evdev_ok) return 8;
  struct mtdev *mt = mtdev_new();
  if (!mt) return 9;
  mtdev_delete(mt);

  // The unchanged QEMU EDID fixture used by the accepted libdisplay-info
  // stage, embedded here so this stage need not download that package again.
  const char *hex =
    "00ffffffffffff0049143412000000002a180104a520147806ee91a3544c99260f5054210800e1c0d1c0d100a940b3009500"
    "81808140ea2900c051201c304026444045cb10000018000000f7000a004082002820000000000000000000fd00327d1ea0ff"
    "010a202020202020000000fc0051454d55204d6f6e69746f720a013a02030b00467d6560591f610000001000000000000000"
    "0000000000000000000010000000000000000000000000000000000010000000000000000000000000000000000010000000"
    "0000000000000000000000000000100000000000000000000000000000000000100000000000000000000000000000000000"
    "00000000002f";
  std::vector<unsigned char> bytes;
  for (size_t i = 0; hex[i] && hex[i + 1]; i += 2) {
    const int high = hex_value(hex[i]);
    const int low = hex_value(hex[i + 1]);
    if (high < 0 || low < 0) return 10;
    bytes.push_back(static_cast<unsigned char>((high << 4) | low));
  }
  if (bytes.size() != 256) return 11;
  struct di_info *info = di_info_parse_edid(bytes.data(), bytes.size());
  if (!info) return 12;
  const struct di_edid *edid = di_info_get_edid(info);
  char *make = di_info_get_make(info);
  char *model = di_info_get_model(info);
  const bool display_ok = edid && di_edid_get_version(edid) == 1 &&
    di_edid_get_revision(edid) == 4 && make && model &&
    std::strcmp(make, "Red Hat, Inc.") == 0 && std::strcmp(model, "QEMU Monitor") == 0;
  std::free(make);
  std::free(model);
  di_info_destroy(info);
  if (!display_ok) return 13;

  std::printf("BLFS_PLASMA_DEPS4_EXEC_OK=archive=3.8.1=ffmpeg=7.1.1=opencv=4.12.0=ffmpeg-backend=edid=1.4=evdev=library\n");
  return 0;
}
EOF
c++ -O2 -Wall -Wextra -std=c++17 \
  /tmp/blfs-plasma-deps4-smoke/main.cpp \
  -o /tmp/blfs-plasma-deps4-smoke-build \
  $(pkg-config --cflags --libs libarchive libavcodec libavutil opencv4 libevdev mtdev libdisplay-info)
set +e
OUTPUT="$(LD_LIBRARY_PATH=/usr/lib:/opt/qt6/lib:/opt/kf6/lib \
  /tmp/blfs-plasma-deps4-smoke-build 2>/tmp/blfs-plasma-deps4-smoke-stderr.log)"
NATIVE_STATUS=$?
set -e
cat /tmp/blfs-plasma-deps4-smoke-stderr.log
printf 'NATIVE_SMOKE_STATUS=%s\nNATIVE_SMOKE_OUTPUT=%s\n' "$NATIVE_STATUS" "$OUTPUT"
[[ "$NATIVE_STATUS" -eq 0 ]]
[[ "$OUTPUT" == BLFS_PLASMA_DEPS4_EXEC_OK=archive=3.8.1=ffmpeg=7.1.1=opencv=4.12.0=ffmpeg-backend=edid=1.4=evdev=library ]]
readelf -h /tmp/blfs-plasma-deps4-smoke-build | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-plasma-deps4-smoke-build | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_PLASMA_DEPS4_RESULT=ok\nPACKAGE_COUNT=6\nDEPENDENCY_COUNT=0\nSOURCE_COUNT=7\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_PLASMA_DEPS4_EXEC_OK\nNATIVE_SMOKE_OUTPUT=%s\nNATIVE_SMOKE_STATUS=0\nDYNAMIC_LINKER=%s\n' "$OUTPUT" "$INTERPRETER"
  printf 'LIBARCHIVE=3.8.1\nFFMPEG=7.1.1\nOPENCV=4.12.0\nMTDEV=1.1.7\nLIBEVDEV=1.13.4\nXORG_EVDEV=2.11.0\nLIBDISPLAY_INFO=0.3.0-existing\nLIBXCVT=0.1.3-existing\n'
  printf 'PACKAGES=libarchive+ffmpeg+opencv+mtdev+libevdev+xf86-input-evdev\nDEPENDENCIES=existing-hwdata-libdisplay-info-libxcvt-xorg-server\n'
  printf 'LIBARCHIVE_TEST_SUITE=make-check-passed\nLIBARCHIVE_SMOKE=native-init-version\n'
  printf 'FFMPEG_TEST_SUITE=not-run-FATE-not-downloaded\nFFMPEG_SMOKE=native-ffv1-encode+ffprobe\nFFMPEG_CONFIGURE=shared-gpl-version3-freetype-vorbis-pulse-openssl\nFFMPEG_FFPLAY=disabled\nFFMPEG_NONFREE=disabled\n'
  printf 'OPENCV_TEST_SUITE=not-run-BUILD_TESTS_OFF\nOPENCV_SMOKE=native-matrix+ffmpeg-backend-no-device\nOPENCV_IPP=disabled-aarch64-no-download\nOPENCV_CONTRIB=not-built-optional\nOPENCV_XINE=disabled-not-installed\nOPENCV_GSTREAMER=disabled-not-installed\nOPENCV_PYTHON=disabled-not-required\n'
  printf 'MTDEV_TEST_SUITE=not-provided\nMTDEV_SMOKE=native-new-delete\nLIBEVDEV_TEST_SUITE=disabled-check-not-installed\nLIBEVDEV_SMOKE=native-name-roundtrip\nXORG_EVDEV_TEST_SUITE=not-provided\nXORG_EVDEV_DRIVER=installed-not-loaded-no-input-device\n'
  printf 'EXISTING_DISPLAY_INFO=native-edid-verified\nEXISTING_LIBXCVT=native-cvt-modeline-verified\n'
  printf 'PLASMA_DEPS3=preserved-pipeline-154\nPLASMA_PULSE1=preserved-pipeline-153\nPLASMA_DEPS2=preserved-pipeline-148\nPLASMA_DEPS1=preserved-pipeline-147\nPLASMA=not-built\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-plasma-deps4-smoke /tmp/blfs-plasma-deps4-smoke-build /tmp/blfs-plasma-deps4-smoke-stderr.log \
  /tmp/blfs-plasma-deps4-ffmpeg.mkv /tmp/blfs-plasma-deps4-ffprobe.txt
