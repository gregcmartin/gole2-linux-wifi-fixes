# Source provenance

- Upstream: https://github.com/lwfinger/rtw88
- Exact snapshot: `a56bcd26e770257612a0803249cbd4095fc6feca`
- Upstream DKMS version: `0.6`
- Patched DKMS version: `0.6-gole1`
- Changes made by gregcmartin on 2026-10-21: add the opt-in host PCIe ASPM control in `pci.c`; change the DKMS version in `dkms.conf`.
- The complete changes to those files are in `patches/0001-disable-host-pcie-aspm.patch`.

`driver/` contains all upstream root-level C and header files, the unchanged Makefile, and the patched DKMS configuration. All other driver source is byte-for-byte unchanged. The upstream README is preserved as `docs/UPSTREAM-README.md` for reference; use this project's README for installation and compatibility, since the upstream instructions and broader kernel claims do not describe this experimental package.

Upstream Git history is not imported. This repository's commits represent the snapshot packaging and GOLE changes; they do not claim authorship of the underlying driver. Original per-file author, copyright, SPDX and module-license notices are retained.

Excluded upstream files include firmware binaries, certificates, private/test signing keys, the `sign-file` executable, Android-specific build files and unrelated installation/suspend helpers. None is required for the documented DKMS build. The unchanged upstream Makefile still includes optional firmware/signing targets; this package uses only its DKMS build/clean targets.

The full upstream driver family is compiled by its original Makefile/DKMS configuration. This project's workaround and validation cover only the RTL8821CE PCIe device on the GOLE 2 Pro, not the other chipsets. Do not use this installer on a system that depends on another rtw88 adapter without reviewing that interaction.

This distribution uses GPL-2.0. Files marked `GPL-2.0 OR BSD-3-Clause` keep both original options; GPL-only source remains GPL-only. Full GPL-2.0 and BSD-3-Clause license texts are included. Project installation scripts are GPL-2.0-only.
