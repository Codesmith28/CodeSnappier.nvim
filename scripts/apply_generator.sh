#!/usr/bin/env bash

source ./scripts/check_os.sh

function apply_generator {
  if [ -f "lua/${os}generator.so" ]; then
    cp -rf "lua/${os}generator.so" lua/generator.so
  elif [ -f "lua/${os}_generator.so" ]; then
    cp -rf "lua/${os}_generator.so" lua/generator.so
  elif [ -f "lua/${os}generator.dylib" ]; then
    cp -rf "lua/${os}generator.dylib" lua/generator.so
  elif [ -f "lua/${os}_generator.dylib" ]; then
    cp -rf "lua/${os}_generator.dylib" lua/generator.so
  fi
}

apply_generator $os
