#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${GODOT_BIN:-}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    GODOT_BIN="/tmp/Godot_v4.3-stable_linux.x86_64"
  fi
fi

if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
  echo "Projeto Godot não encontrado em: $PROJECT_DIR" >&2
  exit 1
fi

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot não encontrado em: $GODOT_BIN" >&2
  echo "Defina GODOT_BIN apontando para o executável do Godot 4.3." >&2
  exit 1
fi

exec "$GODOT_BIN" \
  --path "$PROJECT_DIR" \
  --rendering-method gl_compatibility \
  --windowed \
  --always-on-top \
  "$@"
