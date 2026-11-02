#!/usr/bin/env bash
set -euo pipefail

# LFS 12.4, Chapter 6: cross-compile the temporary tools on native ARM64.
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
WORK="$LFS/build/chapter6"
ARTIFACTS="$REPO/artifacts"
START_TS="$(date +%s)"

[[ "$(id -u)" -ne 0 ]]
[[ "$LFS" == /home/runner/lfs ]]
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS_TGT" == aarch64-lfs-linux-gnu ]]
[[ -x "$LFS/tools/bin/$LFS_TGT-gcc" ]]
[[ -f "$LFS/usr/lib/libc.so.6" ]]
mkdir -p "$ARTIFACTS" "$WORK"

required=(
  m4-1.4.20.tar.xz ncurses-6.5-20250809.tgz bash-5.3.tar.gz
  coreutils-9.7.tar.xz diffutils-3.12.tar.xz file-5.46.tar.gz
  findutils-4.10.0.tar.xz gawk-5.3.2.tar.xz grep-3.12.tar.xz
  gzip-1.14.tar.xz make-4.4.1.tar.gz patch-2.8.tar.xz sed-4.9.tar.xz
  tar-1.35.tar.xz xz-5.8.1.tar.xz binutils-2.45.tar.xz
  gcc-15.2.0.tar.xz mpfr-4.2.2.tar.xz gmp-6.3.0.tar.xz mpc-1.3.1.tar.gz
  gettext-0.26.tar.xz bison-3.8.2.tar.xz perl-5.42.0.tar.xz
  Python-3.13.7.tar.xz texinfo-7.2.tar.xz util-linux-2.41.1.tar.xz
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

printf 'BUILD chapter6 m4-1.4.20\n'
extract m4-1.4.20.tar.xz m4-1.4.20
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 ncurses-6.5-20250809\n'
extract ncurses-6.5-20250809.tgz ncurses-6.5-20250809
mkdir build
pushd build
../configure --prefix="$LFS/tools" AWK=gawk
make -C include
make -C progs tic
install progs/tic "$LFS/tools/bin"
popd
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)" \
            --mandir=/usr/share/man --with-manpage-format=normal \
            --with-shared --without-normal --with-cxx-shared \
            --without-debug --without-ada --disable-stripping AWK=gawk
make
make DESTDIR="$LFS" install
ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$LFS/usr/include/curses.h"

printf 'BUILD chapter6 bash-5.3\n'
extract bash-5.3.tar.gz bash-5.3
./configure --prefix=/usr --build="$(sh support/config.guess)" \
            --host="$LFS_TGT" --without-bash-malloc
make
make DESTDIR="$LFS" install
ln -sv bash "$LFS/bin/sh"

printf 'BUILD chapter6 coreutils-9.7\n'
extract coreutils-9.7.tar.xz coreutils-9.7
./configure --prefix=/usr --host="$LFS_TGT" \
            --build="$(build-aux/config.guess)" \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
make
make DESTDIR="$LFS" install
mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin"
mkdir -pv "$LFS/usr/share/man/man8"
mv -v "$LFS/usr/share/man/man1/chroot.1" "$LFS/usr/share/man/man8/chroot.8"
sed -i 's/"1"/"8"/' "$LFS/usr/share/man/man8/chroot.8"

printf 'BUILD chapter6 diffutils-3.12\n'
extract diffutils-3.12.tar.xz diffutils-3.12
./configure --prefix=/usr --host="$LFS_TGT" \
            gl_cv_func_strcasecmp_works=y --build="$(./build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 file-5.46\n'
extract file-5.46.tar.gz file-5.46
mkdir build
pushd build
../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
make
popd
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)"
make FILE_COMPILE="$(pwd)/build/src/file"
make DESTDIR="$LFS" install
rm -v "$LFS/usr/lib/libmagic.la"

printf 'BUILD chapter6 findutils-4.10.0\n'
extract findutils-4.10.0.tar.xz findutils-4.10.0
./configure --prefix=/usr --localstatedir=/var/lib/locate \
            --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 gawk-5.3.2\n'
extract gawk-5.3.2.tar.xz gawk-5.3.2
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 grep-3.12\n'
extract grep-3.12.tar.xz grep-3.12
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 gzip-1.14\n'
extract gzip-1.14.tar.xz gzip-1.14
./configure --prefix=/usr --host="$LFS_TGT"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 make-4.4.1\n'
extract make-4.4.1.tar.gz make-4.4.1
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 patch-2.8\n'
extract patch-2.8.tar.xz patch-2.8
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 sed-4.9\n'
extract sed-4.9.tar.xz sed-4.9
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 tar-1.35\n'
extract tar-1.35.tar.xz tar-1.35
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make
make DESTDIR="$LFS" install

printf 'BUILD chapter6 xz-5.8.1\n'
extract xz-5.8.1.tar.xz xz-5.8.1
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)" \
            --disable-static --docdir=/usr/share/doc/xz-5.8.1
make
make DESTDIR="$LFS" install
rm -v "$LFS/usr/lib/liblzma.la"

printf 'BUILD chapter6 binutils-2.45-pass2\n'
extract binutils-2.45.tar.xz binutils-2.45
sed '6031s/$add_dir//' -i ltmain.sh
mkdir -v build
cd build
../configure --prefix=/usr --build="$(../config.guess)" --host="$LFS_TGT" \
             --disable-nls --enable-shared --enable-gprofng=no \
             --disable-werror --enable-64-bit-bfd --enable-new-dtags \
             --enable-default-hash-style=gnu
make
make DESTDIR="$LFS" install
rm -v "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

printf 'BUILD chapter6 gcc-15.2.0-pass2\n'
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
    sed -e 's@mabi\.lp64=\.\./lib64@mabi.lp64=../lib@' \
        -i.orig gcc/config/aarch64/t-aarch64-linux
    ;;
esac
sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
mkdir -v build
cd build
../configure --build="$(../config.guess)" --host="$LFS_TGT" --target="$LFS_TGT" \
             --prefix=/usr --with-build-sysroot="$LFS" \
             --enable-default-pie --enable-default-ssp --disable-nls \
             --disable-multilib --disable-libatomic --disable-libgomp \
             --disable-libquadmath --disable-libsanitizer --disable-libssp \
             --disable-libvtv --enable-languages=c,c++ \
             LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc"
make
make DESTDIR="$LFS" install
ln -sv gcc "$LFS/usr/bin/cc"

[[ -x "$LFS/usr/bin/bash" ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -x "$LFS/usr/bin/g++" ]]
[[ -x "$LFS/usr/bin/make" ]]
[[ -x "$LFS/usr/sbin/chroot" ]]
[[ ! -e "$LFS/usr/lib64" ]]
[[ ! -e "$LFS/lib64" ]]
printf 'CHAPTER6_RESULT=ok\nELAPSED_SECONDS=%s\n' "$(( $(date +%s) - START_TS ))"
rm -rf "$WORK"
