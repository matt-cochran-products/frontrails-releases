#!/usr/bin/env bash
set -euo pipefail

repo='matt-cochran-products/frontrails-releases'
binaries=(intent intentos-mcp intentos-lsp export-param-schemas fr frontrails-health-mcp frontrails-mcp structureos structureos-mcp securityos-mcp uxos-mcp)
version="${FRONTRAILS_VERSION:-}"
prefix="${FRONTRAILS_INSTALL_DIR:-${CARGO_HOME:-$HOME/.cargo}/bin}"
work=''
stage=''
cleanup() {
  if [[ -n "$stage" && -d "$stage" ]]; then rm -rf -- "$stage"; fi
  if [[ -n "$work" && -d "$work" ]]; then rm -rf -- "$work"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { printf 'FrontRails: %s\n' "$*" >&2; exit 1; }
for command in curl tar mktemp; do
  command -v "$command" >/dev/null || fail "Required command missing: $command"
done
case "$(uname -s):$(uname -m)" in
  Linux:x86_64) target='x86_64-unknown-linux-gnu' ;;
  Linux:aarch64|Linux:arm64) target='aarch64-unknown-linux-gnu' ;;
  Darwin:arm64|Darwin:aarch64) target='aarch64-apple-darwin' ;;
  Darwin:x86_64) target='x86_64-apple-darwin' ;;
  *) fail 'Supported platforms: Linux x86_64/ARM64, macOS Intel/Apple Silicon. Use install.ps1 for Windows.' ;;
esac
if [[ -z "$version" ]]; then
  version=$(curl -fsSL "https://raw.githubusercontent.com/$repo/main/releases/latest")
fi
version="${version%$'\r'}"
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Version must be vX.Y.Z.'
archive="frontrails-$version-$target.tar.gz"
base="https://github.com/$repo/releases/download/$version"
work=$(mktemp -d "${TMPDIR:-/tmp}/frontrails-download.XXXXXXXX")
curl -fsSL --output "$work/$archive" "$base/$archive"
curl -fsSL --output "$work/$archive.sha256" "$base/$archive.sha256"
read -r expected checksum_file < "$work/$archive.sha256" || [[ -n "${expected:-}" ]]
[[ "${expected:-}" =~ ^[[:xdigit:]]{64}$ ]] || fail 'Missing or invalid SHA256 checksum.'
[[ "${checksum_file%$'\r'}" == "$archive" ]] || fail 'Checksum filename does not match archive.'
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$work/$archive")
elif command -v shasum >/dev/null; then
  actual=$(shasum -a 256 "$work/$archive")
else
  fail 'Install sha256sum or shasum before continuing.'
fi
actual="${actual%% *}"
[[ "$actual" == "$expected" ]] || fail 'SHA256 mismatch; nothing installed.'

# Accept only the expected flat archive layout, before extracting anything.
entry_count=0
while IFS= read -r entry; do
  known=0
  for binary in "${binaries[@]}"; do
    if [[ "$entry" == "$binary" ]]; then known=1; break; fi
  done
  [[ "$known" == 1 ]] || fail "Unexpected archive entry: $entry"
  entry_count=$((entry_count + 1))
done < <(tar -tzf "$work/$archive")
[[ "$entry_count" == "${#binaries[@]}" ]] || fail 'Archive must contain all 11 executables.'
mkdir "$work/unpacked"
tar -xzf "$work/$archive" -C "$work/unpacked"
for binary in "${binaries[@]}"; do
  [[ -f "$work/unpacked/$binary" && ! -L "$work/unpacked/$binary" ]] || fail "Missing executable: $binary"
done
mkdir -p "$prefix"
# Staging on the destination filesystem makes each final rename atomic,
# including replacing a currently running Unix executable.
stage=$(mktemp -d "$prefix/.frontrails-install.XXXXXXXX")
for binary in "${binaries[@]}"; do
  cp "$work/unpacked/$binary" "$stage/$binary"
  chmod 755 "$stage/$binary"
done
for binary in "${binaries[@]}"; do
  mv -f "$stage/$binary" "$prefix/$binary"
done
printf 'Installed FrontRails %s (11 executables) in %s\n' "$version" "$prefix"
case ":$PATH:" in
  *":$prefix:"*) ;;
  *) printf 'Add this directory to PATH, then run: fr --version\n  %s\n' "$prefix" ;;
esac
