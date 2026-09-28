#!/bin/bash
set -u
OUT="${1:-$HOME/Downloads/echo_diagnostic.txt}"
exec > >(tee "$OUT") 2>&1
echo "=== Echo Mini diagnostic (READ ONLY) ==="
date
echo
echo "--- rkdeveloptool ---"
command -v rkdeveloptool || exit 1
rkdeveloptool -v 2>&1 || true
echo
echo "--- Device ---"
rkdeveloptool ld 2>&1 || true
echo
echo "--- Chip ---"
rkdeveloptool rci 2>&1 || true
echo
echo "--- Flash ---"
rkdeveloptool rfi 2>&1 || true
echo
echo "This script performed no writes."
