#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-/home/runner/kde-sources}"
mkdir -p "$DEST"

fetch_set() {
  local label="$1" manifest="$2" base_url="$3" output="$4"
  local hash file path tmp active=0 downloaded=0 reused=0 bytes=0
  mkdir -p "$output"
  while read -r hash file; do
    [[ -n "$hash" ]] || continue
    active=$((active + 1))
    path="$output/$file"
    if [[ -f "$path" ]] && (cd "$output" && printf '%s  %s\n' "$hash" "$file" | md5sum -c - >/dev/null 2>&1); then
      reused=$((reused + 1))
    else
      tmp="$path.part"
      rm -f "$tmp"
      curl -fL --retry 4 --retry-delay 3 --connect-timeout 30 --max-time 900 \
        -o "$tmp" "$base_url$file"
      (cd "$output" && printf '%s  %s\n' "$hash" "$file.part" | md5sum -c - >/dev/null)
      mv "$tmp" "$path"
      downloaded=$((downloaded + 1))
    fi
    (cd "$output" && sha256sum "$file")
  done < <(grep -vE '^ *$|^#' "$manifest") > "$DEST/$label.sha256"
  (cd "$output" && grep -vE '^ *$|^#' "$manifest" | md5sum -c - >/dev/null)
  while read -r _ file; do
    bytes=$((bytes + $(stat -c %s "$output/$file")))
  done < <(grep -vE '^ *$|^#' "$manifest")
  printf '%s_ACTIVE_FILES=%s\n' "$label" "$active"
  printf '%s_DOWNLOADED=%s\n' "$label" "$downloaded"
  printf '%s_REUSED=%s\n' "$label" "$reused"
  printf '%s_BYTES=%s\n' "$label" "$bytes"
}

fetch_set KF6 "$ROOT/manifests/frameworks-6.17.0.md5" \
  'https://download.kde.org/stable/frameworks/6.17/' "$DEST/frameworks"
fetch_set PLASMA "$ROOT/manifests/plasma-6.4.4.md5" \
  'https://download.kde.org/stable/plasma/6.4.4/' "$DEST/plasma"
printf 'KDE_SOURCE_RESULT=ok\n'
