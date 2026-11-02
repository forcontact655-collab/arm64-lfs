#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-core1-report.txt
PROGRESS=/root/blfs-core1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -d /sources ]]
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
  printf 'BLFS_CORE1_BUILT=%s\n' "$PACKAGE_DIR" >>"$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}

printf 'BUILD_BLFS_CORE1=which\n'
extract which-2.23.tar.gz
./configure --prefix=/usr
make
make install
finish_package

printf 'BUILD_BLFS_CORE1=pcre2\n'
extract pcre2-10.45.tar.bz2
./configure --prefix=/usr                       \
            --docdir=/usr/share/doc/pcre2-10.45 \
            --enable-unicode                    \
            --enable-jit                        \
            --enable-pcre2-16                   \
            --enable-pcre2-32                   \
            --enable-pcre2grep-libz             \
            --enable-pcre2grep-libbz2           \
            --enable-pcre2test-libreadline      \
            --disable-static
make
make install
finish_package

printf 'BUILD_BLFS_CORE1=libxml2\n'
extract libxml2-2.14.5.tar.xz
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-static  \
            --with-history    \
            --without-icu     \
            PYTHON=/usr/bin/python3 \
            --docdir=/usr/share/doc/libxml2-2.14.5
make
make install
rm -vf /usr/lib/libxml2.la
sed '/libs=/s/xml2.*/xml2"/' -i /usr/bin/xml2-config
finish_package

printf 'BUILD_BLFS_CORE1=libxslt\n'
extract libxslt-1.1.43.tar.xz
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/libxslt-1.1.43
make
make install
finish_package

printf 'BUILD_BLFS_CORE1=docutils\n'
extract docutils-0.21.2.tar.gz
for f in /usr/bin/rst*.py; do
  rm -fv "/usr/bin/$(basename "$f" .py)"
done
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$PWD"
pip3 install --no-index --find-links dist --no-user docutils
finish_package

printf 'BUILD_BLFS_CORE1=libtasn1\n'
extract libtasn1-4.20.0.tar.gz
./configure --prefix=/usr --disable-static
make
make install
make -C doc/reference install-data-local
finish_package

printf 'BUILD_BLFS_CORE1=p11-kit\n'
extract p11-kit-0.25.5.tar.xz
sed '20,$ d' -i trust/trust-extract-compat
cat >>trust/trust-extract-compat <<"EOF"
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Update trust stores
/usr/sbin/make-ca -r
EOF
mkdir p11-build
cd p11-build
meson setup ..            \
      --prefix=/usr       \
      --libdir=lib        \
      --buildtype=release \
      -D trust_paths=/etc/pki/anchors
ninja
ninja install
ln -sfv /usr/libexec/p11-kit/trust-extract-compat \
        /usr/bin/update-ca-certificates
finish_package

printf 'BUILD_BLFS_CORE1=make-ca\n'
extract make-ca-1.16.1.tar.gz
make install
install -vdm755 /etc/ssl/local
/usr/sbin/make-ca -C /sources/certdata.txt
[[ -s /etc/ssl/certs/ca-certificates.crt ]]
[[ "$(grep -c 'BEGIN CERTIFICATE' /etc/ssl/certs/ca-certificates.crt)" -ge 100 ]]
finish_package

printf 'BUILD_BLFS_CORE1=curl\n'
extract curl-8.15.0.tar.xz
./configure --prefix=/usr    \
            --disable-static \
            --with-openssl   \
            --with-ca-path=/etc/ssl/certs
make
make install
rm -rf docs/examples/.deps
find docs \( -name 'Makefile*' -o \
             -name '*.1'       -o \
             -name '*.3'       -o \
             -name CMakeLists.txt \) -delete
cp -v -R docs -T /usr/share/doc/curl-8.15.0
finish_package

printf 'BUILD_BLFS_CORE1=cmake\n'
extract cmake-4.1.0.tar.gz
sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
./bootstrap --prefix=/usr           \
            --system-libs           \
            --mandir=/share/man     \
            --no-system-jsoncpp     \
            --no-system-cppdap      \
            --no-system-librhash    \
            --no-system-libarchive  \
            --no-system-libuv       \
            --no-system-nghttp2     \
            --docdir=/share/doc/cmake-4.1.0
make
make install
finish_package

printf 'BUILD_BLFS_CORE1=dbus\n'
extract dbus-1.16.2.tar.xz
mkdir build
cd build
meson setup --prefix=/usr          \
            --libdir=lib           \
            --buildtype=release    \
            --wrap-mode=nofallback \
            -D systemd=disabled    \
            ..
ninja
ninja install
chown -v root:messagebus /usr/libexec/dbus-daemon-launch-helper
chmod -v 4750 /usr/libexec/dbus-daemon-launch-helper
dbus-uuidgen --ensure
ln -sfv /var/lib/dbus/machine-id /etc
if [ -e /usr/share/doc/dbus ]; then
  rm -rf /usr/share/doc/dbus-1.16.2
  mv -v /usr/share/doc/dbus{,-1.16.2}
fi
finish_package

printf 'BUILD_BLFS_CORE1=glib-and-gobject-introspection\n'
extract glib-2.84.4.tar.xz
if [ -e /usr/include/glib-2.0 ]; then
  rm -rf /usr/include/glib-2.0.old
  mv -vf /usr/include/glib-2.0{,.old}
fi
mkdir build
cd build
meson setup ..                  \
      --prefix=/usr             \
      --libdir=lib              \
      --buildtype=release       \
      -D introspection=disabled \
      -D glib_debug=disabled    \
      -D man-pages=enabled      \
      -D sysprof=disabled
ninja
ninja install
tar xf ../../gobject-introspection-1.84.0.tar.xz
meson setup gobject-introspection-1.84.0 gi-build \
            --prefix=/usr --libdir=lib --buildtype=release
ninja -C gi-build
ninja -C gi-build install
meson configure -D introspection=enabled
ninja
ninja install
finish_package

printf 'BUILD_BLFS_CORE1=shared-mime-info\n'
extract shared-mime-info-2.4.tar.gz
mkdir build
cd build
meson setup --prefix=/usr --libdir=lib --buildtype=release -D update-mimedb=true ..
ninja
ninja install
finish_package

printf 'BUILD_BLFS_CORE1=desktop-file-utils\n'
extract desktop-file-utils-0.28.tar.xz
rm -fv /usr/bin/desktop-file-edit
mkdir build
cd build
meson setup --prefix=/usr --libdir=lib --buildtype=release ..
ninja
ninja install
finish_package

printf 'BUILD_BLFS_CORE1=wget\n'
extract wget-1.25.0.tar.gz
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl
make
make install
finish_package

[[ "$(grep -c '^BLFS_CORE1_BUILT=' "$PROGRESS")" -eq 15 ]]
pkg-config --exists glib-2.0 libxml-2.0 dbus-1
cat >/tmp/blfs-core1-smoke.c <<'EOF'
#include <glib.h>
#include <libxml/parser.h>
int main(void) {
  xmlInitParser();
  g_print("BLFS_CORE1_EXEC_OK\n");
  xmlCleanupParser();
  return 0;
}
EOF
gcc /tmp/blfs-core1-smoke.c -o /tmp/blfs-core1-smoke \
  $(pkg-config --cflags --libs glib-2.0 libxml-2.0)
OUTPUT="$(/tmp/blfs-core1-smoke)"
[[ "$OUTPUT" == BLFS_CORE1_EXEC_OK ]]
readelf -h /tmp/blfs-core1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-core1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
[[ -s /etc/ssl/certs/ca-certificates.crt ]]
{
  printf 'BLFS_CORE1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=15\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'CMAKE=%s\n' "$(cmake --version | sed -n '1p')"
  printf 'CURL=%s\n' "$(curl --version | sed -n '1p')"
  printf 'DBUS=%s\n' "$(pkg-config --modversion dbus-1)"
  printf 'GLIB=%s\n' "$(pkg-config --modversion glib-2.0)"
  printf 'DOCUTILS=%s\n' "$(python3 -c 'import docutils; print(docutils.__version__)')"
  printf 'CA_BUNDLE_BYTES=%s\n' "$(stat -c %s /etc/ssl/certs/ca-certificates.crt)"
  printf 'QT=absent\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-core1-smoke /tmp/blfs-core1-smoke.c
