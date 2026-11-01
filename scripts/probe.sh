#!/usr/bin/env bash
set -euo pipefail

ARCH="$(uname -m)"
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
  printf 'ERROR: expected native ARM64, got %s\n' "$ARCH" >&2
  exit 1
fi

mkdir -p artifacts
report=artifacts/probe.txt

{
  printf 'PROBE_RESULT=arm64-ok\n'
  printf 'ARCH=%s\n' "$ARCH"
  printf 'KERNEL=%s\n' "$(uname -sr)"
  printf 'CPUS=%s\n' "$(getconf _NPROCESSORS_ONLN)"
  printf 'MEMORY=%s\n' "$(awk '/MemTotal/ {print $2 " " $3}' /proc/meminfo)"
  printf 'OS=%s\n' "$(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
  printf '\nDISK\n'
  df -h . /tmp
  printf '\nTOOLS\n'
} >"$report"

required=(
  bash ld as bison bzip2 gawk gcc g++ grep gzip make m4
  patch perl python3 sed tar makeinfo xz
)
missing=()
for tool in "${required[@]}"; do
  if path="$(command -v "$tool")"; then
    printf 'FOUND %-10s %s\n' "$tool" "$path" >>"$report"
  else
    printf 'MISSING %-10s\n' "$tool" >>"$report"
    missing+=("$tool")
  fi
done

if ((${#missing[@]})); then
  printf '\nMISSING_TOOLS=%s\n' "${missing[*]}" >>"$report"
  printf 'Missing tools must be handled by a later preparation stage; no packages were installed.\n' >>"$report"
else
  printf '\nMISSING_TOOLS=none\n' >>"$report"
fi

cat "$report"
