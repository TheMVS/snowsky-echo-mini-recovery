#!/bin/bash
set -u

EXPECTED_HASH="59b6230df42607384345992532ba8ae8f7967c6dfb51dc2f9f100447ee8cd17e"
IMG="${1:-$HOME/Downloads/ECHO MINI V3.9-2.0/HIFIEC39.IMG}"
OUTDIR="${2:-$HOME/Downloads}"
BACKUP="$OUTDIR/echo_lba0_before_repair.bin"
FINAL="$OUTDIR/echo_lba0_after_repair.bin"
TMP="/tmp/echo_write.bin"
VERIFY="/tmp/echo_verify.bin"
BASE=0
TOTAL=65536
BLOCK=16

die(){ echo "ERROR: $*" >&2; exit 1; }

command -v rkdeveloptool >/dev/null || die "rkdeveloptool not found"
command -v shasum >/dev/null || die "shasum not found"
[ -f "$IMG" ] || die "Firmware not found: $IMG"

SIZE=$(stat -f '%z' "$IMG")
[ "$SIZE" -eq 33554436 ] || die "Unexpected firmware size: $SIZE"

HASH=$(shasum -a 256 "$IMG" | awk '{print $1}')
[ "$HASH" = "$EXPECTED_HASH" ] || die "SHA-256 mismatch: $HASH"

echo "Firmware verified: $HASH"
rkdeveloptool ld | grep -q Loader || die "Echo Mini is not visible in Loader mode"
echo "Flash information:"
rkdeveloptool rfi || die "Cannot read flash information"

mkdir -p "$OUTDIR"
sudo -v || die "sudo failed"

echo "Backing up LBA 0-65535..."
rm -f "$BACKUP"
for ((OFF=0; OFF<TOTAL; OFF+=BLOCK)); do
  rm -f "$TMP"
  sudo rkdeveloptool rl "$OFF" "$BLOCK" "$TMP" >/dev/null 2>&1 ||
    die "Backup read failed at LBA $OFF. Nothing has been written."
  cat "$TMP" >> "$BACKUP"
  if (( OFF % 4096 == 0 )); then printf "\rBackup: %3d%%" "$((OFF*100/TOTAL))"; fi
done
echo
BSIZE=$(stat -f '%z' "$BACKUP")
[ "$BSIZE" -eq 33554432 ] || die "Backup size is wrong: $BSIZE"
echo "Backup SHA-256:"
shasum -a 256 "$BACKUP"

echo
echo "WARNING: the next stage WRITES raw internal flash."
echo "Target: LBA 0-65535"
echo "Source: first 32 MiB of $IMG"
read -r -p "Type RECOVER to continue: " ANSWER
[ "$ANSWER" = "RECOVER" ] || die "Cancelled"

for ((OFF=0; OFF<TOTAL; OFF+=BLOCK)); do
  rm -f "$TMP" "$VERIFY"
  dd if="$IMG" of="$TMP" bs=512 skip="$OFF" count="$BLOCK" 2>/dev/null ||
    die "Cannot extract firmware block at sector $OFF"

  sudo rkdeveloptool wl "$((BASE+OFF))" "$TMP" >/tmp/rkwrite.log 2>&1 || {
    cat /tmp/rkwrite.log
    die "Write failed at LBA $((BASE+OFF))"
  }

  sudo rkdeveloptool rl "$((BASE+OFF))" "$BLOCK" "$VERIFY" >/tmp/rkread.log 2>&1 || {
    cat /tmp/rkread.log
    die "Read-back failed at LBA $((BASE+OFF))"
  }

  cmp -s "$TMP" "$VERIFY" || die "Verification mismatch at LBA $((BASE+OFF))"
  if (( OFF % 1024 == 0 )); then
    printf "\rWrite + immediate verification: %3d%%" "$((OFF*100/TOTAL))"
  fi
done
echo

echo "Performing full read-back verification..."
rm -f "$FINAL"
for ((OFF=0; OFF<TOTAL; OFF+=BLOCK)); do
  rm -f "$TMP"
  sudo rkdeveloptool rl "$OFF" "$BLOCK" "$TMP" >/dev/null 2>&1 ||
    die "Global verification read failed at LBA $OFF"
  cat "$TMP" >> "$FINAL"
  if (( OFF % 4096 == 0 )); then printf "\rGlobal verification: %3d%%" "$((OFF*100/TOTAL))"; fi
done
echo

dd if="$IMG" of=/tmp/HIFIEC_payload.bin bs=1048576 count=32 2>/dev/null ||
  die "Cannot create comparison payload"

cmp -s /tmp/HIFIEC_payload.bin "$FINAL" ||
  die "GLOBAL VERIFICATION FAILED. Do not reset yet."

echo
echo "VERIFICATION PERFECT."
echo "LBA 0-65535 matches the first 32 MiB of HIFIEC39.IMG byte-for-byte."
echo "Backup: $BACKUP"
echo "Read-back: $FINAL"
echo
echo "No reset was sent automatically."
echo "If this is the tested hardware/configuration, the next manual command is:"
echo "  sudo rkdeveloptool rd"
