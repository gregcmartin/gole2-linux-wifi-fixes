# Validation record

This is an experimental result on one physical device, not proof of long-term stability or a general RTL8821CE fix.

## Hardware and software

| Component | Tested configuration |
| --- | --- |
| Device | HIGOLE GOLE 2 Pro |
| CPU | Intel Celeron N5095 |
| Wi-Fi | Realtek RTL8821CE, PCI ID `10ec:c821` |
| BIOS | `GOLE2_JSL_D80R2_720P_U0T9G3L1`, 2024-05-08 |
| OS | Ubuntu 26.04.1 |
| Kernel | `6.8.0-147-generic` |
| Driver | rtw88 `0.6-gole1`, upstream `a56bcd26e770257612a0803249cbd4095fc6feca` |
| Firmware | rtw8821c, firmware version 24.11.0, H2C version 12 |
| Build compiler | GCC 13 |
| Connection | 5 GHz, WPA2/RSN |
| Power saving | Host PCIe ASPM off; driver ASPM off; deep LPS off; NetworkManager Wi-Fi power saving off |
| Other conditions | thermald running; CPU sustained and boost limits capped at 6 W; Ethernet connected; screen kept on |

Firmware SHA-256 (decompressed bytes): `2ef409bc418549fcf294061dd0cae1fc22fd9da79b60524950b25de18732f3f0`. The existing distro firmware matched upstream; it was not replaced.

## Observations, 2026-10-21

- The stock 6.8 driver with device ASPM and deep LPS disabled previously froze the machine after booting with Wi-Fi enabled.
- Unmodified downstream rtw88 0.6 produced repeated `pci bus timeout, check dma status` messages and PCIe DPC containment during scanning/connection attempts. Host and endpoint PCIe ASPM remained enabled despite `disable_aspm=Y`.
- The patched driver built and installed through DKMS and loaded successfully. The new host ASPM parameter read `Y`; endpoint and root-port PCIe ASPM and L1 substates were disabled.
- The patched driver scanned, associated and obtained an address. Twenty gateway pings bound to the Wi-Fi interface had **0% packet loss**, average **3.658 ms**.
- A transfer through SSH directly over the Wi-Fi interface completed with exactly **33,554,432 bytes (32 MiB)** received. This is a functional transfer test, not a throughput benchmark.
- Two corrected `BadDLLP` errors occurred during the initial scan. At the 17:48 CDT check, the corrected-error count remained **2**, fatal count was **0**, and no new DMA timeout or DPC event had appeared since the patch was loaded at 17:40:41 CDT.
- The long-running stability logger remains active. **The 24-hour test, repeated reboot tests, suspend/resume, WPA3, other kernels and Secure Boot are not validated.**

The fatal error seen before the patch and the corrected errors after it are separate observations. The two corrected errors are unresolved. This package does not use `pci=noaer` or mask AER reporting.

The driver currently runs through a manual load on the test device, with automatic loading blocked for recovery while the long test runs. The public installer configures loading on a subsequent user-initiated reboot; that installer path must not be confused with a completed reboot validation on the test device.

## Distribution checks, 2026-10-21

- The driver extracted from the release archive compiled successfully with GCC 13 against the GOLE's actual `6.8.0-147-generic` headers. It was built in a temporary directory without installing or reloading modules.
- Shell syntax checks and ShellCheck passed for installation, removal, diagnostics and recovery helpers.
- Recovery tests passed for restoring original profile settings, preserving later user edits, skipping deleted profiles, and retaining recovery data on NetworkManager failures or invalid saved data. Run `bash scripts/test-profile-restore.sh` to reproduce these isolated tests.
- Installer preflight correctly refused to overwrite the test device's existing DKMS source. The full installer has **not** been run end-to-end on a clean system; the active stability test was left running.
- The source was compared with the pinned upstream commit: only `pci.c` and `dkms.conf` differ. The tarball was regenerated deterministically and each extracted file checked against the source tree.
- The public source/archive inventory was checked for supplied credentials, private network addresses, personal logs and signing keys; none was included.

## Reproducing a useful stability report

Record `sudo ./scripts/status.sh` at the start and end of a 24-hour test. Exercise normal browsing/transfers and idle periods. Use an Ethernet connection to recover and inspect logs if Wi-Fi fails. After the long test succeeds, test several cold boots and reconnects separately before calling the configuration stable.

Check kernel logs locally for `rtw`, `AER`, `DPC`, `BadDLLP`, `timeout`, `BUG` and `Oops`. Record counter deltas and the precise driver/kernel versions, and report whether the entire machine froze or just Wi-Fi disconnected. Before sharing log excerpts, remove personal network names, addresses and other identifying information. Do not upload NetworkManager profile files.

## References

- [Downstream driver and installation background](https://github.com/lwfinger/rtw88)
- [PCIe ASPM implementation in the tested kernel family](https://github.com/torvalds/linux/blob/v6.8/drivers/pci/pcie/aspm.c)
- [Kernel AER documentation](https://www.kernel.org/doc/html/next/PCI/pcieaer-howto.html)
- [Maintainer discussion of host ASPM remaining enabled](https://lists.openwall.net/linux-kernel/2026/08/14/130)
- [Community GOLE Linux configuration guide](https://github.com/GuardianLiarus/HIGOLE_Linux)
