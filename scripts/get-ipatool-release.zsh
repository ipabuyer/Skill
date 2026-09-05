#!/usr/bin/env zsh
# Download and install the ipatool executable for this system from official GitHub Releases.
# Part of the IPAbuyer agent skill. Keep this file ASCII-only and format it with shfmt.

set -euo pipefail

version=''
arch=''
output_dir=''
force=0

usage() {
    cat <<'EOF'
Usage: get-ipatool-release.zsh [options]

Download and install the ipatool executable for the current system from the
official ipatool GitHub releases, with SHA-256 verification.

Options:
  --version <x.y.z>     Pin a specific ipatool version (default: latest release)
  --arch <amd64|arm64>  Target CPU architecture (default: auto-detect)
  --output-dir <dir>    Installation directory (default: <repository root>/bin)
  --force               Replace an already installed executable
  -h, --help            Show this help
EOF
}

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

download() {
    local url=$1
    local dest=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 -o "$dest" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    else
        die "curl or wget is required to download files."
    fi
}

file_sha256() {
    local path=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$path" | awk '{print $NF}'
    else
        die "sha256sum, shasum, or openssl is required to verify checksums."
    fi
}

detect_os() {
    case "$(uname -s)" in
        Linux)
            printf 'linux\n'
            ;;
        Darwin)
            printf 'macos\n'
            ;;
        *)
            die "Unsupported system: $(uname -s). On Windows, use get-ipatool-release.ps1 instead."
            ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64)
            printf 'amd64\n'
            ;;
        arm64 | aarch64)
            printf 'arm64\n'
            ;;
        *)
            die "Unsupported CPU architecture: $(uname -m)"
            ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ $# -ge 2 ] || die "Missing value for $1."
            version=$2
            shift 2
            ;;
        --arch)
            [ $# -ge 2 ] || die "Missing value for $1."
            arch=$2
            shift 2
            ;;
        --output-dir)
            [ $# -ge 2 ] || die "Missing value for $1."
            output_dir=$2
            shift 2
            ;;
        --force)
            force=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (see --help)."
            ;;
    esac
done

if [ -n "$version" ]; then
    printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
        die "Invalid --version value: $version (expected format: x.y.z)."
fi

case "$arch" in
    '' | amd64 | arm64) ;;
    *) die "Invalid --arch value: $arch (supported: amd64, arm64)." ;;
esac

os=$(detect_os)

if [ -z "$arch" ]; then
    arch=$(detect_arch)
fi

if [ -z "$output_dir" ]; then
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    output_dir=$script_dir/../bin
fi

mkdir -p "$output_dir"
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/ipabuyer-ipatool-XXXXXX")
trap 'rm -rf -- "$tmp_root"' EXIT

release_api_url='https://api.github.com/repos/majd/ipatool/releases/latest'
if [ -z "$version" ]; then
    log "Resolving the latest ipatool release from $release_api_url"
    api_json="$tmp_root/latest-release.json"
    download "$release_api_url" "$api_json"
    tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$api_json" | head -n 1)
    printf '%s' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' ||
        die "Latest release tag has an unsupported format: ${tag:-<empty>}."
else
    tag="v$version"
fi
version=${tag#v}

release_base_url="https://github.com/majd/ipatool/releases/download/v$version"
archive_name="ipatool-$version-$os-$arch.tar.gz"
checksum_name="$archive_name.sha256sum"
executable_name="ipatool-$version-$os-$arch"
archive_url="$release_base_url/$archive_name"

log "Using ipatool v$version"
log "Target system/architecture: $os/$arch"
log "Downloading $archive_url"

archive_path="$tmp_root/$archive_name"
checksum_path="$tmp_root/$checksum_name"
download "$archive_url" "$archive_path"
download "$release_base_url/$checksum_name" "$checksum_path"

expected_hash=$(awk '{print $1}' "$checksum_path" | tr 'A-Z' 'a-z')
printf '%s' "$expected_hash" | grep -Eq '^[0-9a-f]{64}$' ||
    die "Invalid SHA-256 checksum format: $checksum_name."
actual_hash=$(file_sha256 "$archive_path")
if [ "$actual_hash" != "$expected_hash" ]; then
    die "SHA-256 mismatch for $archive_name. Expected $expected_hash, got $actual_hash."
fi
log "Verified archive SHA-256: $actual_hash"

extract_dir="$tmp_root/extract"
mkdir -p "$extract_dir"
if ! tar -xzf "$archive_path" -C "$extract_dir"; then
    die "Failed to extract $archive_name."
fi

expected_exec_path="$extract_dir/bin/$executable_name"
if [ ! -f "$expected_exec_path" ]; then
    die "Expected executable was not found in $archive_name: bin/$executable_name."
fi

magic=$(od -An -tx1 -N4 "$expected_exec_path" | tr -d ' \n')
case "$os" in
    linux)
        [ "$magic" = "7f454c46" ] || die "Extracted file is not a valid Linux executable: $expected_exec_path."
        ;;
    macos)
        # Mach-O magic bytes as stored on disk (little-endian MH_MAGIC_64/MH_MAGIC, fat binaries).
        case "$magic" in
            cffaedfe | cefaedfe | cafebabe | bebafeca) ;;
            *) die "Extracted file is not a valid macOS executable: $expected_exec_path." ;;
        esac
        ;;
esac

destination_path="$output_dir/$executable_name"
if [ -e "$destination_path" ] && [ "$force" -ne 1 ]; then
    die "Destination already exists: $destination_path. Re-run with --force to replace it."
fi

destination_tmp="$destination_path.$$.tmp"
cp -- "$expected_exec_path" "$destination_tmp"
chmod 755 "$destination_tmp"
mv -f "$destination_tmp" "$destination_path"

executable_hash=$(file_sha256 "$destination_path")
log "Installed $os/$arch: $destination_path"
log "Executable SHA-256: $executable_hash"
