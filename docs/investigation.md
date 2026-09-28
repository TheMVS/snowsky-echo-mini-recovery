# Investigation chronology

## Starting state

The Echo Mini stopped booting after a forced firmware update. Normal boot was black/dead, but the four-button recovery combination still exposed RockUSB Loader mode.

## What was established

1. `rkdeveloptool ld` saw VID 2207 / PID 262d in Loader.
2. `rci` returned a C262-related chip string.
3. `rfi` saw a Samsung flash of 7456 MB / 15269888 sectors.
4. Raw LBA reads worked.
5. Writing an unchanged 512-byte sector back worked.
6. 1, 2, 4, 8 and 16-sector transfers worked.
7. Newly sourced bytes from HIFIEC could be written and read back identically.
8. Larger dumps revealed Rockchip/RKnano firmware structures and update-related strings.
9. A strong HIFIEC match existed around LBA 83968. Restoring a 32 MiB HIFIEC payload there succeeded but did **not** restore boot.
10. Repeated headers and strings referring to `fw1` and `fw2` initially suggested multiple firmware copies. The region after the later header was essentially empty, so it was unsafe to treat it as a normal complete A/B slot.
11. Comparison of the official HIFIEC image with the active beginning of flash motivated restoration at LBA 0.
12. The original LBA 0–65535 region was backed up.
13. The first 32 MiB of the verified HIFIEC39 image were written to LBA 0–65535 in 16-sector blocks, with immediate read-back comparison.
14. A complete second read-back matched the 32 MiB source byte-for-byte.
15. After reset and normal power-on, the player booted successfully.

## Important discarded approaches

- `rkdeveloptool cs 1`: failed and was unnecessary.
- `rkdeveloptool rcb`: unsupported/failing but irrelevant.
- `upgrade_tool`: did not accept the image through the attempted standard RKFW/RKAF flows.
- Fabricating/using an arbitrary `MiniLoaderAll.bin`: rejected as unsafe.
- Erasing the entire flash: never needed.
- Filling the apparent later firmware region: not needed.
- Restoring HIFIEC only at LBA 83968: verified but did not fix boot.

The key methodological lesson is to preserve dumps, distinguish observed structure from inferred partition semantics, and verify every raw write.
