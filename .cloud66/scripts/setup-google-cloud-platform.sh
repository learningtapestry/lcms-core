#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "$STACK_BASE/shared/google" ]; then
  mkdir -p "$STACK_BASE/shared/google"
  chown cloud66-user:cloud66-user "$STACK_BASE/shared/google"
fi

if [ ! -L "$STACK_PATH/config/google" ]; then
  ln -snf "$STACK_BASE/shared/google" "$STACK_PATH/config/google"
fi
