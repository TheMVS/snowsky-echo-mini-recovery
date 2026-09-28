#!/bin/bash
set -u
IMG="${1:-HIFIEC39.IMG}"
EXPECTED="59b6230df42607384345992532ba8ae8f7967c6dfb51dc2f9f100447ee8cd17e"
[ -f "$IMG" ] || { echo "Not found: $IMG"; exit 1; }
SIZE=$(stat -f '%z' "$IMG")
HASH=$(shasum -a 256 "$IMG" | awk '{print $1}')
echo "File: $IMG"
echo "Size: $SIZE"
echo "SHA256: $HASH"
[ "$SIZE" -eq 33554436 ] || { echo "Unexpected size"; exit 1; }
[ "$HASH" = "$EXPECTED" ] || { echo "Hash mismatch"; exit 1; }
echo "Known HIFIEC39.IMG verified."
