#!/usr/bin/env bash

# Script to retrieve and unpack resources to build Chromium macOS

set -eux

_root_dir="$(dirname "$(greadlink -f "$0")")"
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/helium-chromium"

# Choose a Python version compatible with depot_tools/gclient.
# Allow override via HELIUM_PYTHON when set.
if [[ -n "${HELIUM_PYTHON:-}" ]]; then
  PYTHON_BIN="$HELIUM_PYTHON"
else
  # gclient in the pinned depot_tools currently uses AST aliases
  # (e.g. ast.Str) that are removed in Python 3.12+, so prefer 3.11.
  # Fall back through older 3.x versions, then to whatever `python3` is.
  for _py in python3.11 python3.10 python3.9 python3; do
    if PY="$(command -v "${_py}" 2>/dev/null)" && [[ -n "$PY" ]]; then
      PYTHON_BIN="$PY"
      break
    fi
  done
  if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: No suitable python3 interpreter found." >&2
    exit 1
  fi
fi

# Clone to get the Chromium Source
clone=true
retrieve_generic=false
retrieve_arch_specific=false

while getopts 'dgp' OPTION; do
  case "$OPTION" in
    d)
        clone=false
        ;;
    g)
        retrieve_generic=true
        ;;
    p)
        retrieve_arch_specific=true
        ;;
    ?)
        echo "Usage: $0 [-d] [-g] [-p]"
        echo "  -d: Use download instead of git clone to get Chromium Source"
        echo "  -g: Retrieve and unpack Chromium Source and general resources"
        echo "  -p: Retrieve and unpack platform-specific resources"
        exit 1
        ;;
    esac
done

shift "$(($OPTIND -1))"

_target_cpu=${1:-arm64}

if $retrieve_generic; then
    if $clone; then
        if [[ $_target_cpu == "arm64" ]]; then
            # For arm64 (Apple Silicon)
            "$PYTHON_BIN" "$_main_repo/utils/clone.py" -p mac-arm -o "$_src_dir"
        else
            # For amd64 (Intel)
            "$PYTHON_BIN" "$_main_repo/utils/clone.py" -p mac -o "$_src_dir"
        fi
    else
        "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_main_repo/downloads.ini" -c "$_download_cache"
        "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_main_repo/downloads.ini" -c "$_download_cache" "$_src_dir"
    fi

    # Retrieve and unpack general resources
    "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads.ini" -c "$_download_cache"
    "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_main_repo/extras.ini" -c "$_download_cache"
    "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads.ini" -c "$_download_cache" "$_src_dir"
    "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_main_repo/extras.ini" -c "$_download_cache" "$_src_dir"
fi

if $retrieve_arch_specific; then
    rm -rf "$_src_dir/third_party/llvm-build/Release+Asserts/"
    rm -rf "$_src_dir/third_party/rust-toolchain/"
    rm -rf "$_src_dir/third_party/node/mac/"
    rm -rf "$_src_dir/third_party/node/mac_arm64/"
    mkdir -p "$_src_dir/third_party/llvm-build/Release+Asserts"

    # Retrieve and unpack platform-specific resources
    if [[ $(uname -m) == "arm64" ]]; then
        "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads-arm64.ini" -c "$_download_cache"
        mkdir -p "$_src_dir/third_party/node/mac_arm64/node-darwin-arm64/"
        "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads-arm64.ini" -c "$_download_cache" "$_src_dir"
        if [[ $_target_cpu == "x86_64" ]]; then
            "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads-x86-64-rustlib.ini" -c "$_download_cache"
            "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads-x86-64-rustlib.ini" -c "$_download_cache" "$_src_dir"
        fi
    else
        "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads-x86-64.ini" -c "$_download_cache"
        mkdir -p "$_src_dir/third_party/node/mac/node-darwin-x64/"
        "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads-x86-64.ini" -c "$_download_cache" "$_src_dir"
        if [[ $_target_cpu == "arm64" ]]; then
            "$PYTHON_BIN" "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads-arm64-rustlib.ini" -c "$_download_cache"
            "$PYTHON_BIN" "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads-arm64-rustlib.ini" -c "$_download_cache" "$_src_dir"
        fi
    fi

    ## Rust Resource
    _rust_name="x86_64-apple-darwin"
    if [[ $(uname -m) == "arm64" ]]; then
        _rust_name="aarch64-apple-darwin"
    fi

    _rust_dir="$_src_dir/third_party/rust-toolchain"
    _rust_bin_dir="$_rust_dir/bin"
    _rust_flag_file="$_rust_dir/INSTALLED_VERSION"

    _rust_lib_dir="$_rust_dir/rust-std-$_rust_name/lib/rustlib/$_rust_name/lib"
    _rustc_dir="$_rust_dir/rustc"
    _rustc_lib_dir="$_rust_dir/rustc/lib/rustlib/$_rust_name/lib"

    echo "rustc 1.89.0-nightly (be19eda0d 2025-06-22)" > "$_rust_flag_file"

    mkdir -p "$_rust_bin_dir"
    mkdir -p "$_rust_dir/lib"
    ln -s "$_rust_dir/rustc/bin/rustc" "$_rust_bin_dir/rustc"
    ln -s "$_rust_dir/cargo/bin/cargo" "$_rust_bin_dir/cargo"
    ln -s "$_rust_lib_dir" "$_rustc_lib_dir"

    _llvm_dir="$_src_dir/third_party/llvm-build/Release+Asserts"
    _llvm_bin_dir="$_llvm_dir/bin"

    ln -s "$_llvm_bin_dir/llvm-install-name-tool" "$_llvm_bin_dir/install_name_tool"
fi
