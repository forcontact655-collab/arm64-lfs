#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$REPO/manifests"
LFS="${LFS:-$HOME/lfs}"
SOURCES="$LFS/sources"
ARTIFACTS="$REPO/artifacts"
mkdir -p "$SOURCES" "$ARTIFACTS"

mapfile -t MD5_ROWS < "$MANIFESTS/md5sums"
declare -A EXPECTED=()
for row in "${MD5_ROWS[@]}"; do
  read -r checksum name <<<"$row"
  EXPECTED["$name"]="$checksum"
done

: >"$ARTIFACTS/source-skipped.txt"
count=0
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="${url##*/}"
  if [[ -z "${EXPECTED[$name]+x}" ]]; then
    printf '%s\n' "$name" >>"$ARTIFACTS/source-skipped.txt"
    printf 'SKIP_NO_OFFICIAL_MD5=%s\n' "$name"
    continue
  fi

  if [[ -f "$SOURCES/$name" ]] && printf '%s  %s\n' "${EXPECTED[$name]}" "$name" | (cd "$SOURCES" && md5sum -c -) >/dev/null 2>&1; then
    printf 'CACHED %s\n' "$name"
  else
    rm -f "$SOURCES/$name" "$SOURCES/$name.part"
    printf 'DOWNLOAD %s\n' "$url"
    curl -fL --retry 4 --retry-delay 5 --connect-timeout 30 \
      --output "$SOURCES/$name.part" "$url"
    printf '%s  %s\n' "${EXPECTED[$name]}" "$name.part" | (cd "$SOURCES" && md5sum -c -)
    mv "$SOURCES/$name.part" "$SOURCES/$name"
  fi
  count=$((count + 1))
done <"$MANIFESTS/wget-list-sysv"

(cd "$SOURCES" && md5sum -c "$MANIFESTS/md5sums")
: >"$ARTIFACTS/source-sha256sums.txt"
while read -r _ name; do
  (cd "$SOURCES" && sha256sum "$name") >>"$ARTIFACTS/source-sha256sums.txt"
done <"$MANIFESTS/md5sums"

bytes="$(du -sb "$SOURCES" | awk '{print $1}')"
{
  printf 'SOURCE_RESULT=ok\n'
  printf 'LFS_VERSION=12.4\n'
  printf 'INIT=sysv\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'VERIFIED_FILES=%s\n' "$count"
  printf 'SOURCE_BYTES=%s\n' "$bytes"
  printf 'SKIPPED_WITHOUT_OFFICIAL_MD5=%s\n' "$(wc -l <"$ARTIFACTS/source-skipped.txt")"
} >"$ARTIFACTS/source-report.txt"
cat "$ARTIFACTS/source-report.txt"
