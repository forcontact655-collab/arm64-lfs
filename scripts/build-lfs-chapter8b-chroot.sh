#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
export TESTSUITEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/ch8b-report.txt
PROGRESS=/root/ch8b-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/pkg-config ]]
[[ -d /sources ]]
: > "$PROGRESS"
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
  printf 'CH8B_BUILT=%s\n' "$PACKAGE_DIR" >> "$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}

printf 'BUILD_CH8B=ncurses\n'
extract ncurses-6.5-20250809.tgz
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig

make

make DESTDIR=$PWD/dest install
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v  dest/usr/lib/libncursesw.so.6.5
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp -av dest/* /

for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

ln -sfv libncursesw.so /usr/lib/libcurses.so

cp -v -R doc -T /usr/share/doc/ncurses-6.5-20250809
finish_package

printf 'BUILD_CH8B=sed\n'
extract sed-4.9.tar.xz
./configure --prefix=/usr

make
make html

make install
install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9
finish_package

printf 'BUILD_CH8B=psmisc\n'
extract psmisc-23.7.tar.xz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=gettext\n'
extract gettext-0.26.tar.xz
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.26

make

make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
finish_package

printf 'BUILD_CH8B=bison\n'
extract bison-3.8.2.tar.xz
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2

make

make install
finish_package

printf 'BUILD_CH8B=grep\n'
extract grep-3.12.tar.xz
sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=bash\n'
extract bash-5.3.tar.gz
./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3

make


make install

finish_package

printf 'BUILD_CH8B=libtool\n'
extract libtool-2.5.4.tar.xz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=gdbm\n'
extract gdbm-1.26.tar.gz
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make

make install
finish_package

printf 'BUILD_CH8B=gperf\n'
extract gperf-3.3.tar.gz
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3

make

make install
finish_package

printf 'BUILD_CH8B=expat\n'
extract expat-2.7.1.tar.xz
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.7.1

make

make install

install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.1
finish_package

printf 'BUILD_CH8B=inetutils\n'
extract inetutils-2.6.tar.xz
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c

./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers

make

make install

mv -v /usr/{,s}bin/ifconfig
finish_package

printf 'BUILD_CH8B=less\n'
extract less-679.tar.gz
./configure --prefix=/usr --sysconfdir=/etc

make

make install
finish_package

printf 'BUILD_CH8B=perl\n'
extract perl-5.42.0.tar.xz
export BUILD_ZLIB=False
export BUILD_BZIP2=0

sh Configure -des                                          \
             -D prefix=/usr                                \
             -D vendorprefix=/usr                          \
             -D privlib=/usr/lib/perl5/5.42/core_perl      \
             -D archlib=/usr/lib/perl5/5.42/core_perl      \
             -D sitelib=/usr/lib/perl5/5.42/site_perl      \
             -D sitearch=/usr/lib/perl5/5.42/site_perl     \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
             -D man1dir=/usr/share/man/man1                \
             -D man3dir=/usr/share/man/man3                \
             -D pager="/usr/bin/less -isR"                 \
             -D useshrplib                                 \
             -D usethreads

make

make install
unset BUILD_ZLIB BUILD_BZIP2
finish_package

printf 'BUILD_CH8B=xml-parser\n'
extract XML-Parser-2.47.tar.gz
perl Makefile.PL

make

make install
finish_package

printf 'BUILD_CH8B=intltool\n'
extract intltool-0.51.0.tar.gz
sed -i 's:\\\${:\\\$\\{:' intltool-update.in

./configure --prefix=/usr

make

make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
finish_package

printf 'BUILD_CH8B=autoconf\n'
extract autoconf-2.72.tar.xz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=automake\n'
extract automake-1.18.1.tar.xz
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1

make

make install
finish_package

printf 'BUILD_CH8B=openssl\n'
extract openssl-3.5.2.tar.gz
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic

make

sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.2

cp -vfr doc/* /usr/share/doc/openssl-3.5.2
finish_package

printf 'BUILD_CH8B=libelf\n'
extract elfutils-0.193.tar.bz2
./configure --prefix=/usr        \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy

make

make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
finish_package

printf 'BUILD_CH8B=libffi\n'
extract libffi-3.5.2.tar.gz
./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native

make

make install
finish_package

printf 'BUILD_CH8B=Python\n'
extract Python-3.13.7.tar.xz
./configure --prefix=/usr          \
            --enable-shared        \
            --with-system-expat    \
            --enable-optimizations \
            --without-static-libpython

make

make install

cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

install -v -dm755 /usr/share/doc/python-3.13.7/html

tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.13.7/html \
    -xvf ../python-3.13.7-docs-html.tar.bz2
finish_package

printf 'BUILD_CH8B=flit-core\n'
extract flit_core-3.12.0.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist flit_core
finish_package

printf 'BUILD_CH8B=packaging\n'
extract packaging-25.0.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist packaging
finish_package

printf 'BUILD_CH8B=wheel\n'
extract wheel-0.46.1.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist wheel
finish_package

printf 'BUILD_CH8B=setuptools\n'
extract setuptools-80.9.0.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist setuptools
finish_package

printf 'BUILD_CH8B=ninja\n'
extract ninja-1.13.1.tar.gz
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

python3 configure.py --bootstrap --verbose

install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
finish_package

printf 'BUILD_CH8B=meson\n'
extract meson-1.8.3.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
finish_package

printf 'BUILD_CH8B=kmod\n'
extract kmod-34.2.tar.xz
mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false

ninja

ninja install
finish_package

printf 'BUILD_CH8B=coreutils\n'
extract coreutils-9.7.tar.xz
patch -Np1 -i ../coreutils-9.7-upstream_fix-1.patch

patch -Np1 -i ../coreutils-9.7-i18n-1.patch

autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime

make



make install

mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
finish_package

printf 'BUILD_CH8B=diffutils\n'
extract diffutils-3.12.tar.xz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=gawk\n'
extract gawk-5.3.2.tar.xz
sed -i 's/extras//' Makefile.in

./configure --prefix=/usr

make

rm -f /usr/bin/gawk-5.3.2
make install

ln -sv gawk.1 /usr/share/man/man1/awk.1

install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2
finish_package

printf 'BUILD_CH8B=findutils\n'
extract findutils-4.10.0.tar.xz
./configure --prefix=/usr --localstatedir=/var/lib/locate

make

make install
finish_package

printf 'BUILD_CH8B=groff\n'
extract groff-1.23.0.tar.gz
PAGE=A4 ./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=gzip\n'
extract gzip-1.14.tar.xz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=iproute2\n'
extract iproute2-6.16.0.tar.xz
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8

make NETNS_RUN_DIR=/run/netns

make SBINDIR=/usr/sbin install

install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.16.0
finish_package

printf 'BUILD_CH8B=kbd\n'
extract kbd-2.8.0.tar.xz
patch -Np1 -i ../kbd-2.8.0-backspace-1.patch

sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

./configure --prefix=/usr --disable-vlock

make

make install

cp -R -v docs/doc -T /usr/share/doc/kbd-2.8.0
finish_package

printf 'BUILD_CH8B=libpipeline\n'
extract libpipeline-1.5.8.tar.gz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=make\n'
extract make-4.4.1.tar.gz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=patch\n'
extract patch-2.8.tar.xz
./configure --prefix=/usr

make

make install
finish_package

printf 'BUILD_CH8B=tar\n'
extract tar-1.35.tar.xz
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr

make

make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35
finish_package

printf 'BUILD_CH8B=texinfo\n'
extract texinfo-7.2.tar.xz
sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm

./configure --prefix=/usr

make

make install

make TEXMF=/usr/share/texmf install-tex

pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd
finish_package

printf 'BUILD_CH8B=vim\n'
extract vim-9.1.1629.tar.gz
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

./configure --prefix=/usr

make


make install

ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.1629
finish_package

printf 'BUILD_CH8B=markupsafe\n'
extract markupsafe-3.0.2.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist Markupsafe
finish_package

printf 'BUILD_CH8B=jinja2\n'
extract jinja2-3.1.6.tar.gz
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist Jinja2
finish_package

printf 'BUILD_CH8B=udev\n'
extract systemd-257.8.tar.gz
sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //'               \
    -i rules.d/50-udev-default.rules.in

sed -i '/systemd-sysctl/s/^/#/' rules.d/99-systemd.rules.in

sed -e '/NETWORK_DIRS/s/systemd/udev/' \
    -i src/libsystemd/sd-network/network-util.h

mkdir -p build
cd       build

meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D mode=release           \
      -D dev-kvm-mode=0660      \
      -D link-udev-shared=false \
      -D logind=false           \
      -D vconsole=false

export udev_helpers=$(grep "'name' :" ../src/udev/meson.build | \
                      awk '{print $3}' | tr -d ",'" | grep -v 'udevadm')

ninja udevadm systemd-hwdb                                           \
      $(ninja -n | grep -Eo '(src/(lib)?udev|rules.d|hwdb.d)/[^ ]*') \
      $(realpath libudev.so --relative-to .)                         \
      $udev_helpers

install -vm755 -d {/usr/lib,/etc}/udev/{hwdb.d,rules.d,network}
install -vm755 -d /usr/{lib,share}/pkgconfig
install -vm755 udevadm                             /usr/bin/
install -vm755 systemd-hwdb                        /usr/bin/udev-hwdb
ln      -svfn  ../bin/udevadm                      /usr/sbin/udevd
cp      -av    libudev.so{,*[0-9]}                 /usr/lib/
install -vm644 ../src/libudev/libudev.h            /usr/include/
install -vm644 src/libudev/*.pc                    /usr/lib/pkgconfig/
install -vm644 src/udev/*.pc                       /usr/share/pkgconfig/
install -vm644 ../src/udev/udev.conf               /etc/udev/
install -vm644 rules.d/* ../rules.d/README         /usr/lib/udev/rules.d/
install -vm644 $(find ../rules.d/*.rules \
                      -not -name '*power-switch*') /usr/lib/udev/rules.d/
install -vm644 hwdb.d/*  ../hwdb.d/{*.hwdb,README} /usr/lib/udev/hwdb.d/
install -vm755 $udev_helpers                       /usr/lib/udev
install -vm644 ../network/99-default.link          /usr/lib/udev/network

tar -xvf ../../udev-lfs-20230818.tar.xz
make -f udev-lfs-20230818/Makefile.lfs install

tar -xf ../../systemd-man-pages-257.8.tar.xz                            \
    --no-same-owner --strip-components=1                              \
    -C /usr/share/man --wildcards '*/udev*' '*/libudev*'              \
                                  '*/systemd.link.5'                  \
                                  '*/systemd-'{hwdb,udevd.service}.8

sed 's|systemd/network|udev/network|'                                 \
    /usr/share/man/man5/systemd.link.5                                \
  > /usr/share/man/man5/udev.link.5

sed 's/systemd\(\\\?-\)/udev\1/' /usr/share/man/man8/systemd-hwdb.8   \
                               > /usr/share/man/man8/udev-hwdb.8

sed 's|lib.*udevd|sbin/udevd|'                                        \
    /usr/share/man/man8/systemd-udevd.service.8                       \
  > /usr/share/man/man8/udevd.8

rm /usr/share/man/man*/systemd*

unset udev_helpers
finish_package

printf 'BUILD_CH8B=man-db\n'
extract man-db-2.13.1.tar.xz
./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap             \
            --with-systemdtmpfilesdir=            \
            --with-systemdsystemunitdir=

make

make install
finish_package

printf 'BUILD_CH8B=procps-ng\n'
extract procps-ng-4.0.5.tar.xz
./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit

make

make install
finish_package

printf 'BUILD_CH8B=util-linux\n'
extract util-linux-2.41.1.tar.xz
./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            --without-systemd     \
            --without-systemdsystemunitdir        \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1

make

make install
finish_package

printf 'BUILD_CH8B=e2fsprogs\n'
extract e2fsprogs-1.47.3.tar.gz
mkdir -v build
cd       build

../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-elf-shlibs \
             --disable-libblkid  \
             --disable-libuuid   \
             --disable-uuidd     \
             --disable-fsck

make

make install

rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
finish_package

printf 'BUILD_CH8B=sysklogd\n'
extract sysklogd-2.7.2.tar.gz
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --runstatedir=/run \
            --without-logger   \
            --disable-static   \
            --docdir=/usr/share/doc/sysklogd-2.7.2

make

make install
finish_package

printf 'BUILD_CH8B=sysvinit\n'
extract sysvinit-3.14.tar.xz
patch -Np1 -i ../sysvinit-3.14-consolidated-1.patch

make

make install
finish_package


for cmd in autoconf automake openssl ninja meson udevadm pip3; do
  [[ -x "/usr/bin/$cmd" ]]
done
python3 -c 'import setuptools,wheel,jinja2,markupsafe,mesonbuild'
cat > /tmp/ch8b-smoke.c <<'EOF'
#include <stdio.h>
#include <openssl/sha.h>
int main(void) { puts("LFS_CH8B_EXEC_OK"); return SHA256_DIGEST_LENGTH == 32 ? 0 : 1; }
EOF
gcc /tmp/ch8b-smoke.c -lcrypto -o /tmp/ch8b-smoke
OUTPUT="$(/tmp/ch8b-smoke)"
[[ "$OUTPUT" == LFS_CH8B_EXEC_OK ]]
readelf -h /tmp/ch8b-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/ch8b-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'CH8B_RESULT=ok\n'
  printf 'PACKAGE_COUNT=52\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'AUTOCONF=%s\n' "$(autoconf --version | head -n1)"
  printf 'AUTOMAKE=%s\n' "$(automake --version | head -n1)"
  printf 'OPENSSL=%s\n' "$(openssl version)"
  printf 'PYTHON=%s\n' "$(python3 --version)"
  printf 'NINJA=%s\n' "$(ninja --version)"
  printf 'MESON=%s\n' "$(meson --version)"
  printf 'GRUB=skipped-nonbootable\n'
  printf 'BOOTABLE=no\n'
  printf 'KDE=absent\n'
} > "$REPORT"
cat "$REPORT"
rm -f /tmp/ch8b-smoke /tmp/ch8b-smoke.c
