# Troubleshooting

## `rkdeveloptool ld` shows no device

Re-enter the Echo Mini's physical Loader mode using the four-button combination and reconnect USB. Do not write anything until `ld` shows the expected Loader device.

## `cs 1` fails

It also failed on the successfully recovered unit. If `rfi`, `rl`, and `wl` operate on the expected Samsung flash, `cs 1` is not required.

## `rcb` fails

It failed on the recovered unit. The loader does not necessarily implement every generic `rkdeveloptool` command.

## `wl` fails

Stop immediately. Do not erase the flash. Re-enter Loader mode if necessary. Keep the backup and record the failing LBA.

## Immediate read-back does not match

Stop immediately and do not reset. A mismatch means the raw write cannot be trusted.

## Firmware hash does not match

Do not bypass the check merely to make the script run. Confirm the firmware/version/hardware revision first.

## Device is a different capacity/revision

Treat this repository as research material, not a ready-to-run recovery recipe. The successful offsets and image apply only to the documented hardware.
