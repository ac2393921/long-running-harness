#!/usr/bin/env bash
set -euo pipefail

AGENTS_DIR="${HOME}/.config/agents/agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$AGENTS_DIR"

for f in "$SCRIPT_DIR/agents/"*.md; do
  name="$(basename "$f")"
  cp "$f" "$AGENTS_DIR/$name"
  echo "installed: $AGENTS_DIR/$name"
done

echo "Done. ${AGENTS_DIR} に $(ls "$AGENTS_DIR" | wc -l) 件のエージェントが存在します。"
