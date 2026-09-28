#!/bin/bash
set -u
START="${1:-0}"
COUNT="${2:-233472}"
OUT="${3:-$HOME/Downloads/echo_dump_${START}_${COUNT}.bin}"
BLOCK=16
TMP=/tmp/echo_dump_part.bin
rm -f "$OUT" "$TMP"
sudo -v || exit 1
for ((OFF=0; OFF<COUNT; OFF+=BLOCK)); do
  N=$BLOCK
  (( OFF + N > COUNT )) && N=$((COUNT-OFF))
  rm -f "$TMP"
  sudo rkdeveloptool rl "$((START+OFF))" "$N" "$TMP" >/dev/null 2>&1 || {
    echo "Read failed at LBA $((START+OFF))"; exit 1;
  }
  cat "$TMP" >> "$OUT"
  if (( OFF % 4096 == 0 )); then printf "\r%3d%%" "$((OFF*100/COUNT))"; fi
done
echo
echo "$OUT"
stat -f 'Size: %z bytes' "$OUT"
shasum -a 256 "$OUT"
