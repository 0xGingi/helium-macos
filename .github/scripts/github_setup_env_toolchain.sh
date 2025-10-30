#!/bin/bash -eux

# Simple script for setting up all toolchain dependencies for building Helium on macOS

# 1) Ensure a depot_tools-compatible Python (3.11) is the default `python3`.
#    depot_tools/gclient (and its gclient_eval.py) still reference AST alias
#    nodes (e.g., ast.Str) that are removed in Python 3.12+.
#    Pin to 3.11 to avoid AttributeError during `gclient sync`.
if ! brew list --versions python@3.11 >/dev/null; then
  brew install python@3.11 --overwrite
fi

# Unlink newer python if linked, then link 3.11 and prepend to PATH deterministically.
brew unlink python@3.14 >/dev/null 2>&1 || true
brew unlink python@3.13 >/dev/null 2>&1 || true
brew unlink python@3.12 >/dev/null 2>&1 || true
brew link --overwrite python@3.11

PY311_PREFIX="$(brew --prefix python@3.11)"
export PATH="$PY311_PREFIX/bin:$PATH"
# Persist python 3.11 at the front of PATH for subsequent steps.
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$PY311_PREFIX/bin" >> "$GITHUB_PATH"
fi
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
