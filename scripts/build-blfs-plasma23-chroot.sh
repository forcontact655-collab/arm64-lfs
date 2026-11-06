#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin
export CMAKE_PREFIX_PATH=/opt/kf6:/opt/qt6:/usr
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-plasma23-report.txt
PROGRESS=/root/blfs-plasma23-progress.txt
[[ "$(id -u)" -eq 0 && "$(uname -m)" == aarch64 ]]
[[ ! -e /tools && -x /usr/bin/cmake && -x /usr/bin/ninja && -x /opt/kf6/bin/plasma-welcome ]]
for path in /opt/kf6/share/sounds/oxygen /opt/kf6/share/sounds/ocean /opt/kf6/share/sounds/Oxygen-Sys-Log-In-Short.ogg; do
  [[ ! -e "$path" && ! -L "$path" ]]
done
: >"$PROGRESS"
build_data_package() {
  local archive="$1" package="$2" extra="$3" first top
  printf 'BUILD_BLFS_PLASMA23=%s\n' "$package"
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  top="${first%%/*}"; top="${top#./}"
  [[ "$top" == "$package" ]]
  rm -rf "$SOURCES/$package"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package"
  mkdir build
  cd build
  cmake -G Ninja \
    -D CMAKE_INSTALL_PREFIX=/opt/kf6 \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    $extra \
    -W no-dev ..
  ninja
  ninja install
  cd /sources
  rm -rf "$package"
  printf 'BLFS_PLASMA23_BUILT=%s\n' "$package" >>"$PROGRESS"
}
build_data_package oxygen-sounds-6.4.4.tar.xz oxygen-sounds-6.4.4 '-D KF5_SUPPORT=ON'
build_data_package ocean-sound-theme-6.4.4.tar.xz ocean-sound-theme-6.4.4 ''
[[ "$(grep -c '^BLFS_PLASMA23_BUILT=' "$PROGRESS")" -eq 2 ]]
SOUNDS=/opt/kf6/share/sounds
[[ -f "$SOUNDS/oxygen/index.theme" && -f "$SOUNDS/ocean/index.theme" ]]
mapfile -t OXYGEN_LEGACY < <(find "$SOUNDS" -maxdepth 1 -type f -name 'Oxygen-*.ogg' -print)
mapfile -t OXYGEN_THEME < <(find "$SOUNDS/oxygen" -type f -name '*.ogg' -print)
mapfile -t OXYGEN_WAV < <(find "$SOUNDS/oxygen" -type f -name '*.wav' -print)
mapfile -t OCEAN < <(find "$SOUNDS/ocean" -type f -name '*.oga' -print)
[[ "${#OXYGEN_LEGACY[@]}" -eq 50 && "${#OXYGEN_THEME[@]}" -eq 63 && "${#OXYGEN_WAV[@]}" -eq 1 && "${#OCEAN[@]}" -eq 44 ]]
for sound in "${OXYGEN_LEGACY[@]}" "${OXYGEN_THEME[@]}" "${OCEAN[@]}"; do
  [[ "$(head -c4 "$sound")" == OggS ]]
done
[[ "$(head -c4 "${OXYGEN_WAV[0]}")" == RIFF ]]
[[ "$(dd if="${OXYGEN_WAV[0]}" bs=1 skip=8 count=4 status=none)" == WAVE ]]
printf 'PLASMA23_POSTCHECK=158-sound-files-static-magic-verified-not-played\n'
{
  printf 'BLFS_PLASMA23_RESULT=ok\nPACKAGE_COUNT=2\nSOURCE_COUNT=2\nARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=not-run-data-only-stage\nNEW_EXECUTABLES=none\nNEW_ELF_FILES=0\nELF_ARCH=not-applicable-data-only\nDYNAMIC_LINKER=not-applicable-data-only\n'
  printf 'PLASMA_VERSION=6.4.4\nPACKAGES=oxygen-sounds+ocean-sound-theme\nOXYGEN_SOUNDS=6.4.4\nOCEAN_SOUND_THEME=6.4.4\n'
  printf 'OXYGEN_OGG_COUNT=113\nOXYGEN_WAV_COUNT=1\nOCEAN_OGA_COUNT=44\nSOUND_FILE_COUNT=158\nKF5_LEGACY_SOUNDS=installed-not-used\n'
  printf 'SOUND_FILES_MAGIC=verified-static-not-played\nSOUND_FILES=installed-not-played\nSOUND_THEME=not-applied\nAUDIO_PLAYBACK=not-run\nCONVERTERS=not-run\nAUDIO=not-started\n'
  printf 'TEST_SUITES=not-run\nNETWORK=not-used-by-built-programs\nPLASMA22=preserved-pipeline-211\nKDEPLASMA_ADDONS=preserved-pipeline-211-not-loaded\nPLASMA_WELCOME=preserved-pipeline-211-not-opened\n'
  printf 'PLASMA21=preserved-pipeline-210\nBLUEDEVIL=preserved-pipeline-210-not-started\nPLASMA20=preserved-pipeline-209\n'
  printf 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends\nSDDM=preserved-not-started\nPLASMA_DESKTOP=preserved-pipeline-183-not-running\n'
  printf 'PLASMASHELL=not-started\nSTARTPLASMA=not-run\nCOMPOSITOR=not-started\nDBUS_SESSION=not-started\nDBUS_SYSTEM=not-started-by-this-stage\nKDED=not-started\nKWIN=preserved-not-rebuilt-not-running\n'
  printf 'REAL_DISPLAY=not-tested\nHARDWARE_GRAPHICS=not-tested\nCAMERA=not-accessed\nBOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
