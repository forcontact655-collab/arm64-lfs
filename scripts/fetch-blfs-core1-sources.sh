#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$REPO/manifests"
LFS="${LFS:-$HOME/blfs-sources}"
SOURCES="$LFS/sources"
ARTIFACTS="$REPO/artifacts"
MD5_MANIFEST="$MANIFESTS/blfs-core1.md5"
URL_MANIFEST="$MANIFESTS/wget-list-blfs-core1"
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

certdata_ok() {
  local path="$1"
  [[ -f "$path" ]] && \
    [[ "$(grep -c '^# Certificate' "$path" || true)" -ge 100 ]] && \
    [[ "$(grep -c '^CKA_TRUST_STEP_UP_APPROVED' "$path" || true)" -ge 100 ]]
}
CERTDATA_URL="https://hg-edge.mozilla.org/projects/nss/raw-file/tip/lib/ckfw/builtins/certdata.txt"
if certdata_ok "$SOURCES/certdata.txt"; then
  printf 'CACHED certdata.txt\n'
else
  rm -f "$SOURCES/certdata.txt" "$SOURCES/certdata.txt.part"
  curl -fL --retry 4 --retry-delay 5 --connect-timeout 30 \
    --output "$SOURCES/certdata.txt.part" "$CERTDATA_URL"
  certdata_ok "$SOURCES/certdata.txt.part"
  mv "$SOURCES/certdata.txt.part" "$SOURCES/certdata.txt"
fi

[[ "$count" -eq 19 ]]
(cd "$SOURCES" && md5sum -c "$MD5_MANIFEST")
: >"$ARTIFACTS/blfs-core1-source-sha256sums.txt"
while read -r _ name; do
  (cd "$SOURCES" && sha256sum "$name") >>"$ARTIFACTS/blfs-core1-source-sha256sums.txt"
done <"$MD5_MANIFEST"
(cd "$SOURCES" && sha256sum certdata.txt) >>"$ARTIFACTS/blfs-core1-source-sha256sums.txt"
bytes="$(du -sb "$SOURCES" | awk '{print $1}')"
{
  printf 'SOURCE_RESULT=ok\n'
  printf 'STAGE=blfs-core1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'VERIFIED_FILES=%s\n' "$count"
  printf 'CERTDATA_CERTIFICATES=%s\n' "$(grep -c '^# Certificate' "$SOURCES/certdata.txt")"
  printf 'SOURCE_BYTES=%s\n' "$bytes"
} >"$ARTIFACTS/blfs-core1-source-report.txt"
cat "$ARTIFACTS/blfs-core1-source-report.txt"
