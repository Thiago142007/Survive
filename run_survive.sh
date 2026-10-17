#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT_BIN:-/tmp/Godot_v4.3-stable_linux.x86_64}"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot não encontrado em: $GODOT_BIN" >&2
  echo "Defina GODOT_BIN apontando para o executável do Godot 4.3." >&2
  exit 1
fi

exec "$GODOT_BIN" \
  --path "$PROJECT_DIR" \
  --rendering-method gl_compatibility \
  --windowed \
  --always-on-top
