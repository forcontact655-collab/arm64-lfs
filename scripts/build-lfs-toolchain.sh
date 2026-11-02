#!/usr/bin/env bash
set -euo pipefail

# LFS 12.4, Chapter 5. The commands follow the stable SysV book;
# target-specific values are derived from the native ARM64 runner.
export LFS="${LFS:-/home/runner/lfs}"
export LFS_TGT="$(uname -m)-lfs-linux-gnu"
export LC_ALL=POSIX
export PATH="$LFS/tools/bin:/usr/bin:/bin"
export CONFIG_SITE="$LFS/usr/share/config.site"
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES="$LFS/sources"
WORK="$LFS/build/chapter5"
ARTIFACTS="$REPO/artifacts"
START_TS="$(date +%s)"

[[ "$(id -u)" -ne 0 ]]
[[ "$LFS" == /home/runner/lfs ]]
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS_TGT" == aarch64-lfs-linux-gnu ]]
mkdir -p "$ARTIFACTS" "$WORK"
mkdir -pv "$LFS"/{etc,var,tools} "$LFS/usr"/{bin,lib,sbin,include}
for i in bin lib sbin; do
  [[ -e "$LFS/$i" || -L "$LFS/$i" ]] || ln -sv "usr/$i" "$LFS/$i"
done

required=(
  binutils-2.45.tar.xz gcc-15.2.0.tar.xz mpfr-4.2.2.tar.xz
  gmp-6.3.0.tar.xz mpc-1.3.1.tar.gz linux-6.16.1.tar.xz
  glibc-2.42.tar.xz glibc-2.42-fhs-1.patch
)
for name in "${required[@]}"; do
  [[ -f "$SOURCES/$name" ]] || { printf 'MISSING_SOURCE=%s\n' "$name" >&2; exit 1; }
done

extract() {
  local archive="$1" directory="$2"
  rm -rf "$WORK/$directory"
  tar -xf "$SOURCES/$archive" -C "$WORK"
  cd "$WORK/$directory"
}

printf 'BUILD binutils-2.45-pass1\n'
extract binutils-2.45.tar.xz binutils-2.45
mkdir -v build
cd build
../configure --prefix="$LFS/tools" \
             --with-sysroot="$LFS" \
             --target="$LFS_TGT" \
             --disable-nls \
             --enable-gprofng=no \
             --disable-werror \
             --enable-new-dtags \
             --enable-default-hash-style=gnu
make
make install

printf 'BUILD gcc-15.2.0-pass1\n'
extract gcc-15.2.0.tar.xz gcc-15.2.0
tar -xf "$SOURCES/mpfr-4.2.2.tar.xz"
mv -v mpfr-4.2.2 mpfr
tar -xf "$SOURCES/gmp-6.3.0.tar.xz"
mv -v gmp-6.3.0 gmp
tar -xf "$SOURCES/mpc-1.3.1.tar.gz"
mv -v mpc-1.3.1 mpc
case "$(uname -m)" in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    ;;
  aarch64)
    # ARM64 equivalent of the book's x86_64 library-directory adjustment.
    sed -e 's@mabi\.lp64=\.\./lib64@mabi.lp64=../lib@' \
        -i.orig gcc/config/aarch64/t-aarch64-linux
    ;;
esac
mkdir -v build
cd build
../configure \
    --target="$LFS_TGT" \
    --prefix="$LFS/tools" \
    --with-glibc-version=2.42 \
    --with-sysroot="$LFS" \
    --with-newlib \
    --without-headers \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
    --enable-languages=c,c++
make
make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  "$(dirname "$($LFS_TGT-gcc -print-libgcc-file-name)")/include/limits.h"
MULTI_OS_DIRECTORY="$("$LFS_TGT-gcc" -print-multi-os-directory)"
printf 'MULTI_OS_DIRECTORY=%s\n' "$MULTI_OS_DIRECTORY"
[[ "$MULTI_OS_DIRECTORY" == ../lib ]]

printf 'BUILD linux-6.16.1-headers\n'
extract linux-6.16.1.tar.xz linux-6.16.1
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -r usr/include "$LFS/usr"

printf 'BUILD glibc-2.42\n'
extract glibc-2.42.tar.xz glibc-2.42
case "$(uname -m)" in
  i?86)
    ln -sfv ld-linux.so.2 "$LFS/lib/ld-lsb.so.3"
    ;;
  x86_64)
    mkdir -pv "$LFS/lib64"
    ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
    ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"
    ;;
esac
patch -Np1 -i "$SOURCES/glibc-2.42-fhs-1.patch"
mkdir -v build
cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure \
      --prefix=/usr \
      --host="$LFS_TGT" \
      --build="$(../scripts/config.guess)" \
      --disable-nscd \
      libc_cv_slibdir=/usr/lib \
      --enable-kernel=5.4
make
make DESTDIR="$LFS" install
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

printf 'VERIFY cross-toolchain\n'
DUMMY_LOG="$ARTIFACTS/toolchain-dummy.log"
echo 'int main(){}' | "$LFS_TGT-gcc" -x c - -v -Wl,--verbose &>"$DUMMY_LOG"
INTERPRETER="$(readelf -l a.out | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ -n "$INTERPRETER" ]]
[[ "$INTERPRETER" != *"$LFS"* ]]
readelf -l a.out | grep ': /lib'
grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" "$DUMMY_LOG"
[[ "$(grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" "$DUMMY_LOG" | wc -l)" -eq 3 ]]
grep -B3 "^ $LFS/usr/include" "$DUMMY_LOG"
grep 'SEARCH.*/usr/lib' "$DUMMY_LOG" | sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " "$DUMMY_LOG"
grep found "$DUMMY_LOG"
rm -v a.out

printf 'BUILD libstdc++-15.2.0\n'
extract gcc-15.2.0.tar.xz gcc-15.2.0
mkdir -v build
cd build
../libstdc++-v3/configure \
    --host="$LFS_TGT" \
    --build="$(../config.guess)" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/tools/$LFS_TGT/include/c++/15.2.0"
make
make DESTDIR="$LFS" install
rm -v "$LFS"/usr/lib/lib{stdc++{,exp,fs},supc++}.la
[[ ! -e "$LFS/usr/lib64" ]]
[[ ! -e "$LFS/lib64" ]]

[[ -x "$LFS/tools/bin/$LFS_TGT-gcc" ]]
[[ -x "$LFS/tools/bin/$LFS_TGT-g++" ]]
[[ -f "$LFS/usr/lib/libc.so.6" ]]
[[ -f "$LFS/usr/lib/libstdc++.so" ]]
ELAPSED=$(( $(date +%s) - START_TS ))
{
  printf 'TOOLCHAIN_RESULT=ok\n'
  printf 'LFS_VERSION=12.4\n'
  printf 'INIT=sysv\n'
  printf 'CHAPTER=5\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'LFS_TGT=%s\n' "$LFS_TGT"
  printf 'MULTI_OS_DIRECTORY=%s\n' "$MULTI_OS_DIRECTORY"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'BINUTILS=%s\n' "$("$LFS_TGT-ld" --version | head -n1)"
  printf 'GCC=%s\n' "$("$LFS_TGT-gcc" --version | head -n1)"
  printf 'LIBSTDCXX=present\n'
  printf 'SANITY_START_FILES=3\n'
  printf 'ELAPSED_SECONDS=%s\n' "$ELAPSED"
} >"$ARTIFACTS/toolchain-report.txt"
cat "$ARTIFACTS/toolchain-report.txt"
rm -rf "$WORK"
