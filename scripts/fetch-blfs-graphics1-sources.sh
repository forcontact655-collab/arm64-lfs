#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$REPO/manifests"
LFS="${LFS:-$HOME/blfs-graphics1-sources}"
SOURCES="$LFS/sources"
ARTIFACTS="$REPO/artifacts"
MD5_MANIFEST="$MANIFESTS/blfs-graphics1.md5"
URL_MANIFEST="$MANIFESTS/wget-list-blfs-graphics1"
mkdir -p "$SOURCES" "$ARTIFACTS"

mapfile -t MD5_ROWS < "$MD5_MANIFEST"
declare -A EXPECTED=()
for row in "${MD5_ROWS[@]}"; do
  read -r checksum name <<<"$row"
  EXPECTED["$name"]="$checksum"
done

count=0
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="${url##*/}"
  [[ -n "${EXPECTED[$name]+x}" ]]
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
done < "$URL_MANIFEST"

[[ "$count" -eq 9 ]]
(cd "$SOURCES" && md5sum -c "$MD5_MANIFEST")
: >"$ARTIFACTS/blfs-graphics1-source-sha256sums.txt"
while read -r _ name; do
  (cd "$SOURCES" && sha256sum "$name") >>"$ARTIFACTS/blfs-graphics1-source-sha256sums.txt"
done <"$MD5_MANIFEST"
bytes="$(du -sb "$SOURCES" | awk '{print $1}')"
{
  printf 'SOURCE_RESULT=ok\n'
  printf 'STAGE=blfs-graphics1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'VERIFIED_FILES=%s\n' "$count"
  printf 'SOURCE_BYTES=%s\n' "$bytes"
} >"$ARTIFACTS/blfs-graphics1-source-report.txt"
cat "$ARTIFACTS/blfs-graphics1-source-report.txt"
