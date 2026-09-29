# SNOWSKY / FiiO Echo Mini 8 GB Recovery on macOS

> **Status:** recovery procedure tested successfully on real hardware.
>
> This repository documents the investigation and successful recovery of a **SNOWSKY/FiiO Echo Mini 8 GB** based on **Rockchip/RKnano** which stopped booting after a forced firmware update, while still remaining accessible in RockUSB **Loader** mode.

## ⚠️ Important warning

This procedure performs **raw writes to internal flash**. A wrong image, hardware revision, offset, or interrupted write can make recovery harder.

The successful case documented here had:

- RockUSB VID `0x2207`
- PID `0x262d`
- Loader mode
- chip information containing `C262`
- Samsung internal flash
- reported capacity `7456 MB`
- `15269888` sectors
- sector size `512 B`
- official `HIFIEC39.IMG`
- firmware image SHA-256:

```text
59b6230df42607384345992532ba8ae8f7967c6dfb51dc2f9f100447ee8cd17e
```

Do **not** blindly apply this procedure to another Echo Mini revision/capacity.

This repository deliberately does **not** include proprietary firmware or dumps from the recovered player.

---

## 1. The original failure

The player became unbootable after a firmware update was deliberately/forcibly initiated from removable storage.

Symptoms:

- black screen;
- normal power-on did not boot the player;
- macOS did not mount it as normal USB storage;
- recovery through the normal update mechanism did not work;
- holding the device's four-button recovery combination still caused the SoC to enumerate through RockUSB;
- `rkdeveloptool` could see the device in `Loader` mode.

That last point made recovery possible.

The final evidence strongly indicates that the active firmware at the beginning of internal flash had become inconsistent/corrupt while the low-level Rockchip recovery path remained usable.

---

## 2. Hardware identification

Successful device:

```text
DevNo=1 Vid=0x2207,Pid=0x262d,LocationID=101 Loader
```

`rkdeveloptool rci` returned:

```text
Chip Info:
43 32 36 32 0 0 0 0 55 53 42 43 0 0 0 0
```

The ASCII portion corresponds to:

```text
C262....USBC....
```

`rkdeveloptool rfi` returned:

```text
Flash Info:
    Manufacturer: SAMSUNG, value=00
    Flash Size: 7456 MB
    Flash Size: 15269888 Sectors
    Block Size: 512 KB
    Page Size: 8 KB
    ECC Bits: 0
    Access Time: 50
    Flash CS: Flash<0>
```

This was the ~8 GB Echo Mini variant.

---

## 3. Firmware used for the successful recovery

The successful image was:

```text
HIFIEC39.IMG
```

Observed file size:

```text
33554436 bytes
```

That is:

```text
33554432 bytes + 4 bytes
32 MiB + 4 bytes
```

The raw payload written to flash was the **first 32 MiB**:

```text
65536 sectors × 512 bytes = 33554432 bytes
```

The final four bytes were not written as a sector.

SHA-256 of the exact image used:

```text
59b6230df42607384345992532ba8ae8f7967c6dfb51dc2f9f100447ee8cd17e
```

### HIFIEC vs MINIV

During the investigation both `HIFIEC...IMG` and `MINIV...IMG` firmware families appeared.

The recovered unit was the ~8 GB variant and the image that actually recovered it was **HIFIEC39.IMG**. Do not assume `MINIV390` is interchangeable.

---

## 4. Host environment

Recovery was performed from a MacBook Pro with Apple Silicon/macOS using `rkdeveloptool`.

Check installation:

```bash
command -v rkdeveloptool
rkdeveloptool -h
```

Relevant commands exposed by the version used included:

```text
ListDevice:      ld
DownloadBoot:    db <Loader>
UpgradeLoader:   ul <Loader>
ReadLBA:         rl <BeginSec> <SectorLen> <File>
WriteLBA:        wl <BeginSec> <File>
WriteLBA:        wlx <PartitionName> <File>
EraseFlash:      ef
ResetDevice:     rd [subcode]
ChangeStorage:   cs [...]
ReadFlashInfo:   rfi
ReadChipInfo:    rci
```

---

## 5. Entering Loader mode

On the investigated player, RockUSB Loader mode required the physical **four-button combination**.

Verify with:

```bash
rkdeveloptool ld
```

Expected:

```text
DevNo=1 Vid=0x2207,Pid=0x262d,LocationID=101 Loader
```

If no device is shown, do not run the recovery script.

---

## 6. Verify the internal flash before doing anything destructive

Run:

```bash
rkdeveloptool rci
rkdeveloptool rfi
```

The crucial result in the recovered unit was that `rfi` could still identify the Samsung flash and its capacity.

This established:

```text
Rockchip recovery path alive
        +
internal flash accessible
        =
raw recovery potentially possible
```

---

## 7. Read/write capability tests that were performed

### Raw reads worked

Example:

```bash
sudo rkdeveloptool rl 83968 1 /tmp/original.bin
```

Result:

```text
Read LBA to file (100%)
```

The output was 512 bytes.

### Raw writes worked

The same sector was written back unchanged:

```bash
sudo rkdeveloptool wl 83968 /tmp/original.bin
```

Result:

```text
Write LBA from file (100%)
```

### Transfer sizes

Successful tests included:

```text
1 sector   = 512 B
2 sectors  = 1 KiB
4 sectors  = 2 KiB
8 sectors  = 4 KiB
16 sectors = 8 KiB
```

The final recovery therefore used conservative **16-sector / 8192-byte** transactions.

### New firmware data was also verified

Sixteen sectors were extracted from HIFIEC, written, read back and compared byte-for-byte. This proved that the loader was not merely accepting rewrites of unchanged data.

---

## 8. Commands that failed but were NOT evidence of dead flash

`rkdeveloptool cs 1` returned:

```text
Change Storage failed!
```

Yet `rfi`, `rl`, and later `wl` all worked. Explicit storage switching was therefore unnecessary in this case.

`rkdeveloptool rcb` returned:

```text
Read capability Fail!
```

The device loader apparently implements only part of the generic command set. This did not prevent recovery.

---

## 9. Investigation and flash mapping

A larger dump was eventually made:

```text
LBA 0–233471
119537664 bytes
```

This allowed offline analysis instead of repeatedly probing the player.

Signatures found included:

```text
Rockchip
RKnano
RKnanoFW
HIFIEC
ECHOMINI
SAVE
INFO
```

Interesting regions/signatures included approximately:

```text
LBA 0       Rockchip / RKnano structures
LBA 671     HIFIEC-related strings
LBA 672     ECHOMINI-related strings
LBA 692     boot/reboot-related material
LBA 696     SAVE / INFO
LBA 700     RKnanoFW
LBA 701     HIFIEC / ECHOMINI
LBA 1017    boot-related material
LBA 1033    boot-related material
LBA 1038    RKnanoFW
LBA 83456   repeated RKnano-style header
LBA 83968   area strongly matching HIFIEC
LBA 139264  SAVE/runtime data observed
LBA 167424  another repeated header
LBA 167936  following area essentially empty in the examined dump
```

The firmware also contained diagnostic strings such as:

```text
fw1 Sign error!
fw1 compare error!
fw2 compare error!
No find fw2!
fw1 && fw2 error!
fw2 error!
fw1valid = %d fw2valid = %d
NanoCRebootFlag
```

These strings demonstrate firmware validation/update logic involving concepts named `fw1` and `fw2`, but they are **not sufficient evidence that every repeated header marks a complete interchangeable A/B firmware slot**.

That distinction mattered during the investigation.

---

## 10. A useful wrong turn: restoring HIFIEC at LBA 83968

A strong correspondence was found between HIFIEC and data beginning around:

```text
83456 + 512 = 83968
```

The HIFIEC payload was therefore restored to LBA 83968 in verified 16-sector chunks.

The write succeeded and was verified.

**The player still did not boot.**

This was an extremely useful result: it proved that restoring that update/copy area was not enough to repair the active boot firmware.

Do not repeat this operation as the primary recovery procedure.

---

## 11. The decisive finding

Offline comparison showed that the official HIFIEC image also corresponded structurally to the firmware region beginning at **LBA 0**, while the existing active region had significant differences.

The working hypothesis became:

```text
forced update
     ↓
active firmware at/near LBA 0 becomes inconsistent
     ↓
normal firmware cannot boot
     ↓
BootROM / RockUSB recovery remains available
```

Instead of erasing the device or filling the apparent second region, the first 32 MiB of the official HIFIEC image were written directly to:

```text
LBA 0–65535
```

That recovered the player.

---

# 12. SUCCESSFUL RECOVERY PROCEDURE

## Step 1 — Put the Echo Mini into Loader mode

Use the four-button recovery combination appropriate to the device and connect USB.

```bash
rkdeveloptool ld
```

Do not continue unless the expected Loader device is present.

## Step 2 — Confirm chip/flash

```bash
rkdeveloptool rci
rkdeveloptool rfi
```

For the tested case, confirm the Samsung ~7456 MB / 15269888-sector flash.

## Step 3 — Obtain the correct official firmware

Place `HIFIEC39.IMG` locally.

Verify:

```bash
shasum -a 256 HIFIEC39.IMG
```

Known image used in this recovery:

```text
59b6230df42607384345992532ba8ae8f7967c6dfb51dc2f9f100447ee8cd17e
```

## Step 4 — Back up LBA 0–65535

Before the first write, save the current first 32 MiB.

The supplied recovery script does this automatically.

## Step 5 — Write only the first 32 MiB of HIFIEC to LBA 0

Mapping:

```text
HIFIEC sector 0      -> LBA 0
HIFIEC sector 1      -> LBA 1
...
HIFIEC sector 65535  -> LBA 65535
```

The final four bytes of the 32 MiB + 4 byte image are not written as an additional sector.

## Step 6 — Verify every block

The successful strategy was:

```text
extract 16 sectors from HIFIEC
       ↓
write 16 sectors
       ↓
read those 16 sectors back
       ↓
compare byte-for-byte
       ↓
continue only if identical
```

## Step 7 — Perform a full 32 MiB verification

After all writes, read LBA 0–65535 again and compare against the first 32 MiB of HIFIEC.

Do not reset until the comparison is exact.

## Step 8 — Reset

```bash
sudo rkdeveloptool rd
```

Disconnect USB and boot normally **without** using the four-button Loader combination.

### Observed result

**The Echo Mini booted normally again.**

---

## 13. Why the recovery script is deliberately conservative

`scripts/recover-hifiec39.sh`:

1. checks `rkdeveloptool`;
2. checks that the firmware exists;
3. checks exact firmware size;
4. checks SHA-256;
5. checks Loader mode;
6. checks flash information;
7. backs up the original first 32 MiB;
8. checks backup size;
9. writes in 16-sector chunks;
10. reads every chunk back;
11. compares every chunk;
12. aborts on the first failure;
13. performs a second full verification;
14. does **not** erase the flash;
15. does **not** automatically reset the player.

The reset is intentionally a separate user action.

---

## 14. Things NOT to do

### Do not run `ef`

```bash
rkdeveloptool ef
```

This erases flash and was **not necessary** for the successful recovery.

### Do not blindly write the full `.IMG`

The tested image was 32 MiB + 4 bytes. The successful raw payload was exactly the first 32 MiB / 65536 sectors.

### Do not manufacture a loader from arbitrary offsets

During investigation, bytes were experimentally extracted from another image and temporarily named `MiniLoaderAll.bin`. That is **not a valid basis for declaring them an official Rockchip loader**.

Do not use such an artifact.

### Do not assume LBA 167936 needs a second copy of HIFIEC

The region following the repeated header around LBA 167424 was essentially empty in the examined dump. Firmware strings referencing `fw1`/`fw2` do not by themselves prove that this is a conventional A/B slot that should be populated.

### Do not use `MINIV390` merely because the version number matches

The successful 8 GB recovery used `HIFIEC39.IMG`.

### Do not overwrite personal dumps in the repository

Flash dumps may contain device-specific/runtime information. Keep them private.

---

## 15. `upgrade_tool` investigation

Rockchip `upgrade_tool` was also explored but was not part of the final recovery.

Trying to use the Echo image directly produced errors including:

```text
Failed to parse Loader/Boot header
(use MiniLoaderAll.bin or download.bin)
```

Another unrelated image produced:

```text
RKFW does not contain embedded RKAF update.img
```

The important lesson is that the Echo image should not automatically be treated as a standard RKFW/RKAF package suitable for every Rockchip flashing workflow.

The successful path used raw `rkdeveloptool rl` / `wl`.

---

## 16. Recovery architecture

The successful recovery can be summarized as:

```text
           Echo does not boot
                  │
                  ▼
        four-button recovery
                  │
                  ▼
        RockUSB Loader works
                  │
                  ▼
      Samsung flash accessible
                  │
                  ▼
        backup LBA 0–65535
                  │
                  ▼
 official HIFIEC39 first 32 MiB
                  │
                  ▼
         write at LBA 0
                  │
                  ▼
       verify every 8 KiB
                  │
                  ▼
      verify complete 32 MiB
                  │
                  ▼
               reset
                  │
                  ▼
             BOOTS ✓
```

---

## 17. If a write fails

Stop.

Do **not** erase the flash.

Keep the player in/re-enter Loader mode and note the last successfully verified LBA.

The script stops immediately on:

- extraction failure;
- `wl` failure;
- `rl` failure;
- byte mismatch.

Because the backup is taken before writing, the previous first 32 MiB are preserved in a local file.

---

## 18. Files worth keeping after recovery

Keep privately:

```text
HIFIEC39.IMG
echo_lba0_before_repair.bin
echo_lba0_after_repair.bin
any larger pre-repair dump
```

Record SHA-256 hashes:

```bash
shasum -a 256 <file>
```

The repository should contain scripts/documentation, **not** those firmware/dump files.

---

## 19. Tested scope

Confirmed successful configuration:

```text
Device:       SNOWSKY / FiiO Echo Mini
Variant:      ~8 GB
USB VID:      0x2207
USB PID:      0x262d
Mode:         Loader
SoC string:   C262
Flash:        Samsung
Flash size:   7456 MB / 15269888 sectors
Firmware:     HIFIEC39.IMG
Version:      V3.9
Host:         macOS / Apple Silicon
Tool:         rkdeveloptool
```

Treat different hardware as **unverified**.

---

## 20. Quick reference

For the exact tested scenario:

```text
1. Enter Loader with the four-button combination.
2. rkdeveloptool ld
3. rkdeveloptool rci
4. rkdeveloptool rfi
5. Verify HIFIEC39.IMG SHA-256.
6. Back up LBA 0–65535.
7. Write HIFIEC sectors 0–65535 to flash LBA 0–65535.
8. Use 16-sector chunks.
9. Read and compare every chunk.
10. Perform full 32 MiB comparison.
11. rkdeveloptool rd
12. Disconnect USB.
13. Boot normally.
```

**This exact sequence recovered the investigated player.**

---

## 21. Repository contents

```text
snowsky-echo-mini-recovery/
├── README.md
├── LICENSE
├── docs/
│   ├── flash-layout.md
│   ├── investigation.md
│   └── troubleshooting.md
├── scripts/
│   ├── diagnose.sh
│   ├── dump-region.sh
│   ├── backup-lba0.sh
│   ├── verify-hifiec39.sh
│   └── recover-hifiec39.sh
└── examples/
    └── expected-device-info.txt
```

See `docs/investigation.md` for the longer forensic chronology and why several initially plausible approaches were discarded.

---


## Repository files: what each file is for

- `README.md` — Main manual: brick symptoms, hardware, investigation, successful recovery and safety notes.
- `scripts/recover-hifiec39.sh` — **MAIN RECOVERY SCRIPT. This is the script that automates the procedure that successfully recovered the tested Echo Mini.** It verifies the known HIFIEC39 image, checks Loader/flash, backs up LBA 0–65535, writes the first 32 MiB to LBA 0–65535 in 16-sector blocks, verifies every block and performs a full final verification. It does not reset automatically.
- `scripts/verify-hifiec39.sh` — Non-destructive HIFIEC39 size/SHA-256 checker.
- `scripts/diagnose.sh` — Read-only Loader/chip/flash diagnostic (`ld`, `rci`, `rfi`).
- `scripts/backup-lba0.sh` — Standalone read-only backup of the first 32 MiB (LBA 0–65535). The recovery script already makes this backup.
- `scripts/dump-region.sh` — Generic read-only raw flash dumper for forensic investigation.
- `docs/flash-layout.md` — Approximate observed flash map; not an official partition table.
- `docs/investigation.md` — Full chronology explaining how the solution was discovered, including failed approaches.
- `docs/troubleshooting.md` — Loader, command, write/read, verification, firmware and hardware-revision troubleshooting.
- `examples/expected-device-info.txt` — Reference VID/PID, C262 bytes, Samsung flash data, firmware hash, target LBAs and block size from the recovered unit.
- `.gitignore` — Prevents firmware and raw dumps (`*.IMG`, `*.img`, `*.bin`, `*.dump`) from being committed accidentally.
- `LICENSE` — MIT license for the scripts/documentation; it does not cover FiiO/SNOWSKY firmware.

### Which file do I need?

```text
Understand everything:             README.md
Check Loader/chip/flash:           scripts/diagnose.sh
Verify HIFIEC39.IMG:               scripts/verify-hifiec39.sh
Make a standalone backup:          scripts/backup-lba0.sh
Dump arbitrary flash:              scripts/dump-region.sh
PERFORM THE PROVEN RECOVERY:       scripts/recover-hifiec39.sh
Understand how it was discovered:  docs/investigation.md
See the observed flash map:        docs/flash-layout.md
Troubleshoot:                       docs/troubleshooting.md
```

For the proven recovery, the important script is therefore **`scripts/recover-hifiec39.sh`**.

## 22. Disclaimer and scope

This README documents **a solution to one specific type of SNOWSKY/FiiO Echo Mini failure**: the tested 8 GB unit no longer booted after a forced firmware update, but it could still enter RockUSB **Loader** mode and `rkdeveloptool` could access its Samsung internal flash. The procedure described here successfully recovered that device by restoring the verified HIFIEC39 firmware payload to LBA 0–65535.

It is **not a universal solution for every Echo Mini brick**. A device with different symptoms, storage capacity, hardware revision, firmware, USB identification, flash layout, damaged hardware, inaccessible Loader mode, or another cause of failure may require a different procedure. Do not assume that the offsets, image, or commands documented here are correct for another unit unless its relevant characteristics have been verified.

This is an independent community recovery record and is **not an official FiiO/SNOWSKY or Rockchip flashing procedure**. It is provided for informational and experimental purposes. Raw flash access and firmware modification can cause data loss, make a device unbootable, complicate later recovery, or potentially cause other damage if the procedure is applied incorrectly or to incompatible hardware.

**Use this information entirely at your own risk. The author/contributor of this guide accepts no responsibility or liability for damage, data loss, device failure, loss of warranty, or any other consequence resulting from following, adapting, or executing the procedures, commands, or scripts described here.**

Always make a backup first, verify the exact hardware and firmware, read the complete procedure before writing anything, and stop immediately if observed device information or verification results differ from the documented tested case.
