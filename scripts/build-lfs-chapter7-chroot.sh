#!/usr/bin/env bash
set -euo pipefail

# Runs only inside the isolated LFS chroot, as root, after Chapter 6.
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
export TESTSUITEFLAGS="-j$(nproc)"
umask 022
set +h

SOURCES=/sources
WORK=/build/chapter7
REPORT=/root/minimal-rootfs-report.txt
DUMMY_LOG=/root/minimal-rootfs-dummy.log
START_TS="$(date +%s)"

[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ -x /usr/bin/gcc ]]
[[ -x /bin/bash ]]
[[ -d /tools ]]
mkdir -p "$WORK"

mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

ln -sv /proc/self/mounts /etc/mtab
cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp

extract() {
  local archive="$1" directory="$2"
  rm -rf "$WORK/$directory"
  tar -xf "$SOURCES/$archive" -C "$WORK"
  cd "$WORK/$directory"
}

printf 'BUILD chapter7 gettext-0.26\n'
extract gettext-0.26.tar.xz gettext-0.26
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

printf 'BUILD chapter7 bison-3.8.2\n'
extract bison-3.8.2.tar.xz bison-3.8.2
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make
make install

printf 'BUILD chapter7 perl-5.42.0\n'
extract perl-5.42.0.tar.xz perl-5.42.0
sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D useshrplib \
             -D privlib=/usr/lib/perl5/5.42/core_perl \
             -D archlib=/usr/lib/perl5/5.42/core_perl \
             -D sitelib=/usr/lib/perl5/5.42/site_perl \
             -D sitearch=/usr/lib/perl5/5.42/site_perl \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl
make
make install

printf 'BUILD chapter7 Python-3.13.7\n'
extract Python-3.13.7.tar.xz Python-3.13.7
./configure --prefix=/usr --enable-shared --without-ensurepip \
            --without-static-libpython
make
make install

printf 'BUILD chapter7 texinfo-7.2\n'
extract texinfo-7.2.tar.xz texinfo-7.2
./configure --prefix=/usr
make
make install

printf 'BUILD chapter7 util-linux-2.41.1\n'
extract util-linux-2.41.1.tar.xz util-linux-2.41.1
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib --runstatedir=/run \
            --disable-chfn-chsh --disable-login --disable-nologin \
            --disable-su --disable-setpriv --disable-runuser \
            --disable-pylibmount --disable-static --disable-liblastlog2 \
            --without-python ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1
make
make install

printf 'CLEAN chapter7 temporary system\n'
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools
rm -rf /build

printf 'VERIFY native ARM64 chroot execution\n'
cat > /tmp/lfs-minimal-dummy.c <<'EOF'
#include <stdio.h>
int main(void) { puts("LFS_MINIMAL_EXEC_OK"); return 0; }
EOF
gcc -v -Wl,--verbose /tmp/lfs-minimal-dummy.c -o /tmp/lfs-minimal-dummy &>"$DUMMY_LOG"
OUTPUT="$(/tmp/lfs-minimal-dummy)"
[[ "$OUTPUT" == LFS_MINIMAL_EXEC_OK ]]
readelf -h /tmp/lfs-minimal-dummy | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/lfs-minimal-dummy | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
[[ -e "$INTERPRETER" ]]
[[ ! -e /usr/lib64 ]]
[[ ! -e /lib64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/python3 ]]
[[ -x /usr/bin/perl ]]
[[ -x /usr/bin/mount ]]

{
  printf 'MINIMAL_ROOTFS_RESULT=ok\n'
  printf 'LFS_VERSION=12.4\n'
  printf 'INIT=sysv\n'
  printf 'CHAPTERS=6-7\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'CHROOT_EXEC=ok\n'
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'ELF_MACHINE=AArch64\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'BASH=%s\n' "$BASH_VERSION"
  printf 'GCC=%s\n' "$(gcc --version | head -n1)"
  printf 'COREUTILS=%s\n' "$(ls --version | head -n1)"
  printf 'PYTHON=%s\n' "$(python3 --version)"
  printf 'PERL=%s\n' "$(perl -e 'print $^V')"
  printf 'TOOLS_REMOVED=yes\n'
  printf 'LIB64=absent\n'
  printf 'BOOTABLE=no\n'
  printf 'KDE=absent\n'
  printf 'CHROOT_ELAPSED_SECONDS=%s\n' "$(( $(date +%s) - START_TS ))"
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/lfs-minimal-dummy /tmp/lfs-minimal-dummy.c
