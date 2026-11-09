#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/check_os.sh"

function apply_generator {
  local target_os="$1"
  for name in \
    "${target_os}generator.so" \
    "${target_os}_generator.so" \
    "${target_os}generator.dylib" \
    "${target_os}_generator.dylib" \
    "${target_os}generator.dll" \
    "${target_os}_generator.dll"; do
    if [ -f "$REPO_ROOT/lua/$name" ]; then
      cp -rf "$REPO_ROOT/lua/$name" "$REPO_ROOT/lua/generator.so" 2>/dev/null || true
      echo "Applied precompiled native generator: $name"
      return 0
    elif [ -f "$REPO_ROOT/lua/libs/$name" ]; then
      cp -rf "$REPO_ROOT/lua/libs/$name" "$REPO_ROOT/lua/generator.so" 2>/dev/null || true
      echo "Applied cached precompiled native generator: $name"
      return 0
    fi
  done

  # Attempt to pre-fetch latest release binary via curl if network is available
  local dl_url="https://github.com/Codesmith28/CodeSnappier.nvim/releases/latest/download/${target_os}_generator.so"
  mkdir -p "$REPO_ROOT/lua/libs"
  if curl -f -L -s -o "$REPO_ROOT/lua/libs/${target_os}_generator.so" "$dl_url" 2>/dev/null && [ -s "$REPO_ROOT/lua/libs/${target_os}_generator.so" ]; then
    cp -rf "$REPO_ROOT/lua/libs/${target_os}_generator.so" "$REPO_ROOT/lua/generator.so"
    echo "Downloaded and applied precompiled binary for $target_os."
    return 0
  fi

  echo "CodeSnappier: Precompiled native binary will be auto-downloaded on first run in Neovim."
  return 0
}

apply_generator "$os"
