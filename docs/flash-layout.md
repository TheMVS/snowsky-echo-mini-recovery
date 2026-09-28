# Observed flash layout

This is an **investigative map**, not an official partition table.

| Approx. LBA | Observation |
|---:|---|
| 0 | Active Rockchip/RKnano firmware structures; successful recovery target |
| ~671–701 | HIFIEC/ECHOMINI/SAVE/INFO/RKnanoFW/update-related strings |
| 83456 | Repeated RKnano-style header |
| 83968 | Region strongly matching HIFIEC; restoring it alone did not restore boot |
| 139264 | SAVE/runtime structure observed during investigation |
| 167424 | Another repeated header |
| 167936 onward | Essentially empty in the examined pre-repair dump |

The important empirical result is not the speculative naming of every region: **writing the verified first 32 MiB of HIFIEC39.IMG to LBA 0–65535 recovered the player.**

Do not infer a conventional A/B partition scheme solely from the repeated headers or `fw1`/`fw2` diagnostic strings.
