#!/bin/bash
set -u
OUT="${1:-$HOME/Downloads/echo_lba0_backup.bin}"
TMP=/tmp/echo_backup_part.bin
TOTAL=65536
BLOCK=16
rm -f "$OUT" "$TMP"
sudo -v || exit 1
for ((OFF=0; OFF<TOTAL; OFF+=BLOCK)); do
  rm -f "$TMP"
  sudo rkdeveloptool rl "$OFF" "$BLOCK" "$TMP" >/dev/null 2>&1 || {
    echo "Read failed at LBA $OFF"; exit 1;
  }
  cat "$TMP" >> "$OUT"
  if (( OFF % 4096 == 0 )); then printf "\r%3d%%" "$((OFF*100/TOTAL))"; fi
done
echo
stat -f 'Size: %z bytes' "$OUT"
shasum -a 256 "$OUT"
