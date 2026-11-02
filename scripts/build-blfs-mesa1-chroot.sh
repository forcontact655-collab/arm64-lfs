#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-mesa1-report.txt
PROGRESS=/root/blfs-mesa1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/llvm-config ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -d /sources ]]
pkg-config --exists libdrm x11 xcb xkbcommon wayland-client
python3 -c 'import mako, yaml; assert yaml.__with_libyaml__'
: >"$PROGRESS"
extract() {
  local archive="$1" first
  set +o pipefail
  first="$(tar -tf "$SOURCES/$archive" | head -n1)"
  set -o pipefail
  PACKAGE_DIR="${first%%/*}"
  PACKAGE_DIR="${PACKAGE_DIR#./}"
  [[ "$PACKAGE_DIR" =~ ^[A-Za-z0-9._+-]+$ ]]
  rm -rf "$SOURCES/$PACKAGE_DIR"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$PACKAGE_DIR"
}
finish_package() {
  cd /sources
  rm -rf "$PACKAGE_DIR"
  printf 'BLFS_MESA1_BUILT=%s\n' "$PACKAGE_DIR" >>"$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}

printf 'BUILD_BLFS_MESA1=mesa\n'
extract mesa-25.1.8.tar.xz
mkdir build
cd build
meson setup ..                 \
      --prefix=/usr            \
      --libdir=lib             \
      --buildtype=release      \
      -D platforms=x11,wayland \
      -D gallium-drivers=auto  \
      -D vulkan-drivers=       \
      -D valgrind=disabled     \
      -D video-codecs=         \
      -D libunwind=disabled
ninja
ninja install
cp -r ../docs -T /usr/share/doc/mesa-25.1.8
finish_package

[[ "$(grep -c '^BLFS_MESA1_BUILT=' "$PROGRESS")" -eq 1 ]]
pkg-config --exists egl gl gbm
DRI_ENTRIES="$(find /usr/lib/dri -mindepth 1 -maxdepth 1 \( -type f -o -type l \) | wc -l)"
[[ "$DRI_ENTRIES" -ge 1 ]]
if [ -d /usr/share/vulkan/icd.d ]; then
  VULKAN_ICD_ENTRIES="$(find /usr/share/vulkan/icd.d -mindepth 1 -maxdepth 1 -type f | wc -l)"
else
  VULKAN_ICD_ENTRIES=0
fi
[[ "$VULKAN_ICD_ENTRIES" -eq 0 ]]
cat >/tmp/blfs-mesa1-smoke.c <<'EOF'
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GL/gl.h>
#include <stdio.h>
int main(void) {
  EGLint major = 0, minor = 0, count = 0;
  EGLConfig config;
  EGLint config_attributes[] = {
    EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
    EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
    EGL_NONE
  };
  EGLint surface_attributes[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
  EGLDisplay display = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, 0);
  if (display == EGL_NO_DISPLAY) return 1;
  if (!eglInitialize(display, &major, &minor)) return 2;
  if (!eglBindAPI(EGL_OPENGL_API)) return 3;
  if (!eglChooseConfig(display, config_attributes, &config, 1, &count) || count < 1) return 4;
  EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, 0);
  if (context == EGL_NO_CONTEXT) return 5;
  EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attributes);
  if (surface == EGL_NO_SURFACE) return 6;
  if (!eglMakeCurrent(display, surface, surface, context)) return 7;
  const GLubyte *renderer = glGetString(GL_RENDERER);
  if (!renderer) return 8;
  printf("BLFS_MESA1_EXEC_OK=%s\n", renderer);
  eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroySurface(display, surface);
  eglDestroyContext(display, context);
  eglTerminate(display);
  return 0;
}
EOF
gcc /tmp/blfs-mesa1-smoke.c -o /tmp/blfs-mesa1-smoke \
  $(pkg-config --cflags --libs egl gl)
OUTPUT="$(LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe /tmp/blfs-mesa1-smoke)"
[[ "$OUTPUT" == BLFS_MESA1_EXEC_OK=* ]]
RENDERER="${OUTPUT#BLFS_MESA1_EXEC_OK=}"
[[ -n "$RENDERER" ]]
readelf -h /tmp/blfs-mesa1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-mesa1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_MESA1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_MESA1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'MESA=%s\n' "$(pkg-config --modversion egl)"
  printf 'DRI_ENTRIES=%s\n' "$DRI_ENTRIES"
  printf 'VULKAN_ICD_ENTRIES=%s\n' "$VULKAN_ICD_ENTRIES"
  printf 'VULKAN=absent\n'
  printf 'VIDEO_CODECS=disabled\n'
  printf 'GL_RENDERER=%s\n' "$RENDERER"
  printf 'BOOTABLE=no\n'
  printf 'QT=absent\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-mesa1-smoke /tmp/blfs-mesa1-smoke.c
