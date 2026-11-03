#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export PKG_CONFIG_PATH=/opt/kf6/lib/pkgconfig:/opt/qt6/lib/pkgconfig
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-kf6-base5-report.txt
PROGRESS=/root/blfs-kf6-base5-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/g++ && -x /usr/bin/cmake && -x /usr/bin/ninja ]]
[[ -x /usr/bin/python3 && -x /usr/bin/perl && -x /usr/bin/xmllint && -x /usr/bin/xsltproc ]]
pkg-config --exists polkit-gobject-1 libxml-2.0 libxslt
[[ -x /opt/qt6/bin/qmake6 && "$(/opt/qt6/bin/qmake6 -query QT_VERSION)" == 6.9.2 ]]
for path in KF6Solid KF6Sonnet KF6ThreadWeaver; do
  [[ -f "/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]
done
for path in KF6Auth KF6Completion KF6Crash KF6DocTools KF6Pty KF6UnitConversion; do
  [[ ! -e "/opt/kf6/lib/cmake/$path" ]]
done
[[ ! -e /usr/lib/cmake/PolkitQt6-1 ]]
[[ ! -e /usr/share/xml/docbook/xml-dtd-4.5 ]]
[[ ! -e /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 ]]
[[ -x /usr/bin/xfce4-terminal ]]
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
extract_package polkit-qt-1-0.200.0.tar.xz polkit-qt-1-0.200.0
mkdir build; cd build
printf 'BUILD_BLFS_KF6_BASE5_DEPENDENCY=polkit-qt\n'
cmake -G Ninja -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_PREFIX_PATH=/opt/qt6 \
  -D CMAKE_BUILD_TYPE=Release -D QT_MAJOR_VERSION=6 -W no-dev ..
ninja
ninja install
cd /sources; rm -rf polkit-qt-1-0.200.0
[[ -e /usr/lib/libpolkit-qt6-core-1.so ]]
printf 'BLFS_KF6_BASE5_DEPENDENCY_BUILT=polkit-qt-1-0.200.0\n' >>"$PROGRESS"
/sbin/ldconfig
printf 'BUILD_BLFS_KF6_BASE5_DEPENDENCY=docbook-xml\n'
rm -rf /sources/docbook-xml-4.5
mkdir /sources/docbook-xml-4.5
python3 -m zipfile -e "$SOURCES/docbook-xml-4.5.zip" /sources/docbook-xml-4.5
cd /sources/docbook-xml-4.5
install -v -d -m755 /usr/share/xml/docbook/xml-dtd-4.5 /etc/xml
cp -v -af --no-preserve=ownership docbook.cat *.dtd ent/ *.mod /usr/share/xml/docbook/xml-dtd-4.5
if [[ ! -e /etc/xml/docbook ]]; then xmlcatalog --noout --create /etc/xml/docbook; fi
xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML V4.5//EN" \
  "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//DTD XML Exchange Table Model 19990315//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/soextblx.dtd" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ELEMENTS DocBook XML Information Pool V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/dbpoolx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ELEMENTS DocBook XML Document Hierarchy V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/dbhierx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ELEMENTS DocBook XML HTML Tables V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/htmltblx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ENTITIES DocBook XML Notations V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/dbnotnx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ENTITIES DocBook XML Character Entities V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/dbcentx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ENTITIES DocBook XML Additional General Entities V4.5//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5/dbgenent.mod" /etc/xml/docbook
xmlcatalog --noout --add "rewriteSystem" "http://www.oasis-open.org/docbook/xml/4.5" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
xmlcatalog --noout --add "rewriteURI" "http://www.oasis-open.org/docbook/xml/4.5" \
  "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
if [[ ! -e /etc/xml/catalog ]]; then xmlcatalog --noout --create /etc/xml/catalog; fi
xmlcatalog --noout --add "delegatePublic" "-//OASIS//ENTITIES DocBook XML" \
  "file:///etc/xml/docbook" /etc/xml/catalog
xmlcatalog --noout --add "delegatePublic" "-//OASIS//DTD DocBook XML" \
  "file:///etc/xml/docbook" /etc/xml/catalog
xmlcatalog --noout --add "delegateSystem" "http://www.oasis-open.org/docbook/" \
  "file:///etc/xml/docbook" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://www.oasis-open.org/docbook/" \
  "file:///etc/xml/docbook" /etc/xml/catalog
for DTDVERSION in 4.1.2 4.2 4.3 4.4; do
  xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML V$DTDVERSION//EN" \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/docbookx.dtd" /etc/xml/docbook
  xmlcatalog --noout --add "rewriteSystem" "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
  xmlcatalog --noout --add "rewriteURI" "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
  xmlcatalog --noout --add "delegateSystem" "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
    "file:///etc/xml/docbook" /etc/xml/catalog
  xmlcatalog --noout --add "delegateURI" "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
    "file:///etc/xml/docbook" /etc/xml/catalog
done
cd /sources; rm -rf docbook-xml-4.5
printf 'BLFS_KF6_BASE5_DEPENDENCY_BUILT=docbook-xml-4.5\n' >>"$PROGRESS"
extract_package docbook-xsl-nons-1.79.2.tar.bz2 docbook-xsl-nons-1.79.2
printf 'BUILD_BLFS_KF6_BASE5_DEPENDENCY=docbook-xsl-nons\n'
patch -Np1 -i "$SOURCES/docbook-xsl-nons-1.79.2-stack_fix-1.patch"
install -v -m755 -d /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
cp -v -R VERSION assembly common eclipse epub epub3 extensions fo highlighting html htmlhelp \
  images javahelp lib manpages params profiling roundtrip slides template tests tools webhelp website \
  xhtml xhtml-1_1 xhtml5 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl
install -v -m644 -D README /usr/share/doc/docbook-xsl-nons-1.79.2/README.txt
install -v -m644 RELEASE-NOTES* NEWS* /usr/share/doc/docbook-xsl-nons-1.79.2
xmlcatalog --noout --add "rewriteSystem" "http://cdn.docbook.org/release/xsl-nons/1.79.2" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteSystem" "https://cdn.docbook.org/release/xsl-nons/1.79.2" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "http://cdn.docbook.org/release/xsl-nons/1.79.2" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "https://cdn.docbook.org/release/xsl-nons/1.79.2" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteSystem" "http://cdn.docbook.org/release/xsl-nons/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteSystem" "https://cdn.docbook.org/release/xsl-nons/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "http://cdn.docbook.org/release/xsl-nons/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "https://cdn.docbook.org/release/xsl-nons/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteSystem" "http://docbook.sourceforge.net/release/xsl/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "http://docbook.sourceforge.net/release/xsl/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
cd /sources; rm -rf docbook-xsl-nons-1.79.2
printf 'BLFS_KF6_BASE5_DEPENDENCY_BUILT=docbook-xsl-nons-1.79.2\n' >>"$PROGRESS"
extract_package MIME-Base32-1.303.tar.gz MIME-Base32-1.303
printf 'BUILD_BLFS_KF6_BASE5_DEPENDENCY=mime-base32\n'
perl Makefile.PL
make
make test
make install
cd /sources; rm -rf MIME-Base32-1.303
printf 'BLFS_KF6_BASE5_DEPENDENCY_BUILT=mime-base32-1.303\n' >>"$PROGRESS"
extract_package URI-5.32.tar.gz URI-5.32
printf 'BUILD_BLFS_KF6_BASE5_DEPENDENCY=uri\n'
perl Makefile.PL
make
make install
cd /sources; rm -rf URI-5.32
printf 'BLFS_KF6_BASE5_DEPENDENCY_BUILT=uri-5.32\n' >>"$PROGRESS"
perl -MURI -MMIME::Base32 -e 'my $u=URI->new("https://example.com/a"); die unless $u->scheme eq "https"; die unless MIME::Base32::encode_base32("hello") eq "NBSWY3DP"; die unless MIME::Base32::decode_base32("NBSWY3DP") eq "hello"; print "PERL_URI_MIME_SMOKE=ok\n"'
packages=(kauth kcompletion kcrash kdoctools kpty kunitconversion)
for name in "${packages[@]}"; do
  extract_package "$name-6.17.0.tar.xz" "$name-6.17.0"
  mkdir build; cd build
  printf 'BUILD_BLFS_KF6_BASE5=%s\n' "$name"
  cmake_args=(
    -D CMAKE_INSTALL_PREFIX=/opt/kf6
    -D CMAKE_INSTALL_LIBEXECDIR=libexec
    -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
    -D CMAKE_SKIP_INSTALL_RPATH=ON
    -D CMAKE_BUILD_TYPE=Release
    -D BUILD_TESTING=OFF
    -D BUILD_PYTHON_BINDINGS=OFF
  )
  if [[ "$name" == kauth ]]; then cmake_args+=(-D KAUTH_BACKEND_NAME=POLKITQT6-1); fi
  if [[ "$name" == kcrash ]]; then cmake_args+=(-D WITH_X11=ON); fi
  if [[ "$name" == kdoctools ]]; then
    cmake_args+=(
      -D MEINPROC_NO_KARCHIVE=OFF
      -D DocBookXML4_DTD_DIR=/usr/share/xml/docbook/xml-dtd-4.5
      -D DocBookXSL_DIR=/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
    )
  fi
  cmake -G Ninja "${cmake_args[@]}" -W no-dev ..
  ninja
  ninja install
  cd /sources; rm -rf "$name-6.17.0"
  printf 'BLFS_KF6_BASE5_BUILT=%s-6.17.0\n' "$name" >>"$PROGRESS"
done
rm -rf /opt/kf6/lib/systemd
/sbin/ldconfig
[[ "$(grep -c '^BLFS_KF6_BASE5_BUILT=' "$PROGRESS")" -eq 6 ]]
[[ "$(grep -c '^BLFS_KF6_BASE5_DEPENDENCY_BUILT=' "$PROGRESS")" -eq 5 ]]
for path in \
  /opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake \
  /opt/kf6/lib/cmake/KF6Completion/KF6CompletionConfig.cmake \
  /opt/kf6/lib/cmake/KF6Crash/KF6CrashConfig.cmake \
  /opt/kf6/lib/cmake/KF6DocTools/KF6DocToolsConfig.cmake \
  /opt/kf6/lib/cmake/KF6Pty/KF6PtyConfig.cmake \
  /opt/kf6/lib/cmake/KF6UnitConversion/KF6UnitConversionConfig.cmake \
  /opt/kf6/lib/libKF6AuthCore.so \
  /opt/kf6/lib/libKF6Completion.so \
  /opt/kf6/lib/libKF6Crash.so \
  /opt/kf6/lib/libKF6DocTools.so \
  /opt/kf6/lib/libKF6Pty.so \
  /opt/kf6/lib/libKF6UnitConversion.so; do [[ -e "$path" ]]; done
[[ -x /opt/kf6/bin/meinproc6 && -x /opt/kf6/bin/checkXML6 ]]
find /opt/kf6/lib/plugins -type f -name '*kauth_backend_plugin.so' -print -quit | grep -q .
rm -rf /tmp/blfs-kf6-base5-smoke /tmp/blfs-kf6-base5-smoke-build
mkdir -p /tmp/blfs-kf6-base5-smoke
cat >/tmp/blfs-kf6-base5-smoke/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(blfs_kf6_base5_smoke LANGUAGES CXX)
find_package(Qt6 6.9.2 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6Auth 6.17.0 REQUIRED CONFIG)
find_package(KF6Completion 6.17.0 REQUIRED CONFIG)
find_package(KF6Crash 6.17.0 REQUIRED CONFIG)
find_package(KF6DocTools 6.17.0 REQUIRED CONFIG)
find_package(KF6Pty 6.17.0 REQUIRED CONFIG)
find_package(KF6UnitConversion 6.17.0 REQUIRED CONFIG)
add_executable(blfs-kf6-base5-smoke main.cpp)
target_link_libraries(blfs-kf6-base5-smoke PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets
  KF6::AuthCore KF6::Completion KF6::Crash KF6::DocTools KF6::Pty KF6::UnitConversion)
EOF
cat >/tmp/blfs-kf6-base5-smoke/main.cpp <<'EOF'
#include <KAuth/Action>
#include <KCompletion>
#include <KPty>
#include <KUnitConversion/Value>
#include <QCoreApplication>
#include <QString>
#include <QtGlobal>
#include <cstdio>
int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  const QString actionName = QStringLiteral("org.kde.kf6.smoke");
  KAuth::Action action(actionName);
  if (action.name() != actionName) return 1;
  KCompletion completion;
  completion.addItem(QStringLiteral("hello"));
  const QString completed = completion.makeCompletion(QStringLiteral("hel"));
  if (completed != QStringLiteral("hello")) return 2;
  KPty pty;
  if (!pty.open()) return 3;
  pty.close();
  const KUnitConversion::Value meters = KUnitConversion::Value(1.0, KUnitConversion::Kilometer).convertTo(KUnitConversion::Meter);
  if (qAbs(meters.number() - 1000.0) > 0.000001) return 4;
  std::printf("BLFS_KF6_BASE5_EXEC_OK=%s=%s=%d\n", qVersion(), completed.toUtf8().constData(),
              static_cast<int>(meters.number()));
  return 0;
}
EOF
cmake -S /tmp/blfs-kf6-base5-smoke -B /tmp/blfs-kf6-base5-smoke-build \
  -G Ninja -D CMAKE_BUILD_TYPE=Release -D "CMAKE_PREFIX_PATH=/opt/kf6;/opt/qt6"
ninja -C /tmp/blfs-kf6-base5-smoke-build
OUTPUT="$(LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib /tmp/blfs-kf6-base5-smoke-build/blfs-kf6-base5-smoke)"
[[ "$OUTPUT" == BLFS_KF6_BASE5_EXEC_OK=6.9.2=hello=1000 ]]
readelf -h /tmp/blfs-kf6-base5-smoke-build/blfs-kf6-base5-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-kf6-base5-smoke-build/blfs-kf6-base5-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
cat >/tmp/blfs-kf6-base5-smoke.docbook <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE article PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">
<article id="blfs-kf6-base5"><title>BLFS KF6</title><para>meinproc-ok</para></article>
EOF
XML_CATALOG_FILES=/etc/xml/catalog LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /opt/kf6/bin/meinproc6 --check /tmp/blfs-kf6-base5-smoke.docbook
XML_CATALOG_FILES=/etc/xml/catalog LD_LIBRARY_PATH=/opt/kf6/lib:/opt/qt6/lib \
  /opt/kf6/bin/meinproc6 --stdout /tmp/blfs-kf6-base5-smoke.docbook >/tmp/blfs-kf6-base5-smoke.html
grep -qi '<html' /tmp/blfs-kf6-base5-smoke.html
grep -q 'meinproc-ok' /tmp/blfs-kf6-base5-smoke.html
{
  printf 'BLFS_KF6_BASE5_RESULT=ok\nPACKAGE_COUNT=6\nDEPENDENCY_COUNT=5\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_KF6_BASE5_EXEC_OK\nDYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'QT=6.9.2\nECM=6.17.0\nKF6_VERSION=6.17.0\n'
  printf 'PACKAGES=kauth+kcompletion+kcrash+kdoctools+kpty+kunitconversion\n'
  printf 'DEPENDENCIES=polkit-qt+docbook-xml+docbook-xsl-nons+mime-base32+uri\n'
  printf 'KAUTH_BACKEND=polkitqt6-built-runtime-not-tested\nKCRASH=linked-not-triggered\n'
  printf 'KPTY=native-open-close-ok\nKUNITCONVERSION=1km-to-1000m-ok\n'
  printf 'KDOCTOOLS=meinproc-check-and-html-ok\nPERL_URI_MIME_SMOKE=ok\n'
  printf 'MIME_BASE32_TEST_SUITE=make-test-passed\nURI_TEST_SUITE=not-run-test-only-deps-unavailable\n'
  printf 'POLKIT_QT_TEST_SUITE=not-provided-upstream\nDOCBOOK_TEST_SUITE=not-run-upstream-requirements-unavailable\n'
  printf 'TEST_SUITES=not-run-BUILD_TESTING_OFF\n'
  printf 'NETWORKMANAGER_QT=deferred-networkmanager-backend\n'
  printf 'KDNSSD=deferred-avahi-backend\nKIMAGEFORMATS=deferred-plugin-validation\n'
  printf 'BASE4=preserved-pipeline-96\nXFCE_BASE=preserved\nPLASMA=absent\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-kf6-base5-smoke /tmp/blfs-kf6-base5-smoke-build \
  /tmp/blfs-kf6-base5-smoke.docbook /tmp/blfs-kf6-base5-smoke.html
