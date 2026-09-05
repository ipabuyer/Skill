#!/usr/bin/env zsh
# Build ipatool from source via a Go module proxy, without accessing GitHub.
# Part of the IPAbuyer agent skill. Keep this file ASCII-only; format with shfmt.

set -euo pipefail

version=''
proxy='https://goproxy.cn'
output_dir=''
force=0

usage() {
    cat <<'EOF'
Usage: build-ipatool.zsh [options]

Build ipatool from source fetched through a Go module proxy (default:
goproxy.cn, reachable from mainland China). Requires Go 1.25 or newer,
as declared in ipatool's go.mod.

Options:
  --version <x.y.z>     Pin a specific ipatool version (default: latest on the proxy)
  --proxy <url>         Go module proxy base URL (default: https://goproxy.cn)
  --output-dir <dir>    Installation directory (default: <repository root>/bin)
  --force               Replace an already built executable
  -h, --help            Show this help

Go module proxies verified to carry this module (choose with --proxy):
  https://goproxy.cn                     Qiniu, default
  https://goproxy.io
  https://mirrors.aliyun.com/goproxy/    Alibaba Cloud
  https://proxy.golang.org               official, often unreachable in mainland China
EOF
}

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_go() {
    if ! command -v go >/dev/null 2>&1; then
        die "Go is not installed or not on PATH. Install Go 1.25 or newer from https://go.dev/dl/ (China mirror: https://golang.google.cn/dl/)."
    fi

    local go_version_text
    go_version_text=$(go version | awk '{print $3}')
    local go_version=${go_version_text#go}
    local oldest
    oldest=$(printf '%s\n1.25.0\n' "$go_version" | sort -V | head -n 1)
    [ "$oldest" = "1.25.0" ] || die "Go 1.25.0 or newer is required (found $go_version)."
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
            die "Unsupported system: $(uname -s). On Windows, use build-ipatool.ps1 instead."
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

require_download_tool() {
    if command -v curl >/dev/null 2>&1; then
        printf 'curl\n'
    elif command -v wget >/dev/null 2>&1; then
        printf 'wget\n'
    else
        die "curl or wget is required to download files."
    fi
}

download() {
    local url=$1
    local dest=$2
    case "$(require_download_tool)" in
        curl) curl -fsSL --retry 3 -o "$dest" "$url" ;;
        wget) wget -qO "$dest" "$url" ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ $# -ge 2 ] || die "Missing value for $1."
            version=$2
            shift 2
            ;;
        --proxy)
            [ $# -ge 2 ] || die "Missing value for $1."
            proxy=$2
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

require_go
os=$(detect_os)
arch=$(detect_arch)
module_path='github.com/majd/ipatool/v2'

if [ -z "$version" ]; then
    log "Resolving the latest ipatool version from $proxy"
    version_list=$(download "$proxy/$module_path/@v/list" /dev/stdout)
    version=$(printf '%s\n' "$version_list" | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -rV | head -n 1)
    [ -n "$version" ] || die "Unable to resolve the latest version from the proxy."
fi

if [ -z "$output_dir" ]; then
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    output_dir=$script_dir/../bin
fi

mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/ipabuyer-ipatool-build-XXXXXX")
trap 'rm -rf -- "$tmp_root"' EXIT

zip_url="$proxy/$module_path/@v/v$version.zip"
log "Downloading module source from $zip_url"
download "$zip_url" "$tmp_root/ipatool.zip"

command -v unzip >/dev/null 2>&1 || die "unzip is required to extract the module source."
unzip -q "$tmp_root/ipatool.zip" -d "$tmp_root/extract"

module_dir="$tmp_root/extract/$module_path@v$version"
[ -f "$module_dir/main.go" ] || die "Module source was not found after extraction: $module_dir"

destination_path="$output_dir/ipatool-$version-$os-$arch"
if [ -e "$destination_path" ] && [ "$force" -ne 1 ]; then
    die "Destination already exists: $destination_path. Re-run with --force to replace it."
fi

log "Building ipatool v$version for $os/$arch with GOPROXY=$proxy,direct"
cd "$module_dir"
GOPROXY="$proxy,direct" go build -trimpath -ldflags "-s -w -X $module_path/cmd.version=$version" -o "$destination_path" .

log "Built $os/$arch: $destination_path"
