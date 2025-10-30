#!/bin/bash -eux

# Simple script for setting up all toolchain dependencies for building Helium on macOS

# 1) Ensure a depot_tools-compatible Python (3.12) is the default `python3`.
#    depot_tools/gclient currently imports deprecated AST nodes removed in 3.13+.
#    Using 3.13/3.14 causes AttributeError: ast has no attribute Str.
if ! brew list --versions python@3.12 >/dev/null; then
  brew install python@3.12 --overwrite
fi

# Unlink newer python if linked, then link 3.12 and prepend to PATH deterministically.
brew unlink python@3.14 >/dev/null 2>&1 || true
brew unlink python@3.13 >/dev/null 2>&1 || true
brew link --overwrite python@3.12

PY312_PREFIX="$(brew --prefix python@3.12)"
export PATH="$PY312_PREFIX/bin:$PATH"
python3 --version
which python3

# 2) Core build tooling
brew install ninja coreutils --overwrite

if ! command -v sccache 2>&1 >/dev/null; then
  brew install sccache --overwrite
fi

# 3) Python and packaging deps
pip3 install httplib2==0.22.0 requests pillow --break-system-packages

# 4) DMG packager
npm i -g appdmg@0.6.6
