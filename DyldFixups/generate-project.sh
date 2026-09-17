#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
cd "$ROOT"
python3 generate_payloads.py
xcodegen generate > /dev/null
