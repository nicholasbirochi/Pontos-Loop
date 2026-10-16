#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Este script precisa ser executado no Mac."
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Instale XcodeGen conforme readme.md e execute novamente."
  exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
  echo "Instale e inicialize o Xcode antes de continuar."
  exit 1
fi
xcodegen generate --spec project.yml
open PontosLoop.xcodeproj
