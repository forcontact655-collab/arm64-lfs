#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$REPO/manifests"
LFS="${LFS:-$HOME/blfs-xfce-apps1-sources}"
SOURCES="$LFS/sources"
ARTIFACTS="$REPO/artifacts"
SHA256_MANIFEST="$MANIFESTS/blfs-xfce-apps1.sha256"
URL_MANIFEST="$MANIFESTS/wget-list-blfs-xfce-apps1"
mkdir -p "$SOURCES" "$ARTIFACTS"
mapfile -t SHA256_ROWS < "$SHA256_MANIFEST"
declare -A EXPECTED=()
for row in "${SHA256_ROWS[@]}"; do
  read -r checksum name <<<"$row"
  EXPECTED["$name"]="$checksum"
done
count=0
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="${url##*/}"
  [[ -n "${EXPECTED[$name]+x}" ]]
  if [[ -f "$SOURCES/$name" ]] && printf '%s  %s\n' "${EXPECTED[$name]}" "$name" | (cd "$SOURCES" && sha256sum -c -) >/dev/null 2>&1; then
    printf 'CACHED %s\n' "$name"
  else
    rm -f "$SOURCES/$name" "$SOURCES/$name.part"
    printf 'DOWNLOAD %s\n' "$url"
    curl -fL --retry 4 --retry-delay 5 --connect-timeout 30 --output "$SOURCES/$name.part" "$url"
    printf '%s  %s\n' "${EXPECTED[$name]}" "$name.part" | (cd "$SOURCES" && sha256sum -c -)
    mv "$SOURCES/$name.part" "$SOURCES/$name"
  fi
  count=$((count + 1))
done < "$URL_MANIFEST"
[[ "$count" -eq 3 ]]
(cd "$SOURCES" && sha256sum -c "$SHA256_MANIFEST")
while read -r _ name; do
  (cd "$SOURCES" && sha256sum "$name")
done <"$SHA256_MANIFEST" >"$ARTIFACTS/blfs-xfce-apps1-source-sha256sums.txt"
bytes="$(du -sb "$SOURCES" | awk '{print $1}')"
{
  printf 'SOURCE_RESULT=ok\n'
  printf 'STAGE=blfs-xfce-apps1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'VERIFIED_FILES=%s\n' "$count"
  printf 'SOURCE_BYTES=%s\n' "$bytes"
} >"$ARTIFACTS/blfs-xfce-apps1-source-report.txt"
cat "$ARTIFACTS/blfs-xfce-apps1-source-report.txt"
