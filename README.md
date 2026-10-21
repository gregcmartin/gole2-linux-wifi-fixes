# GOLE 2 Pro Linux Wi-Fi fixes

An experimental RTL8821CE Wi-Fi driver workaround for the **HIGOLE GOLE 2 Pro**. It disables PCIe link power saving at the host level, in addition to the existing Realtek driver power-saving workarounds.

**Status: initial connection and transfer tests passed; the 24-hour stability test is pending. Two corrected PCIe BadDLLP errors remain unresolved. This is not yet a confirmed freeze fix.**

## Download and install

Use Ethernet for installation and recovery. The installer supports **Ubuntu, x86-64, kernel 6.8.x, an RTL8821CE (`10ec:c821`), and Secure Boot disabled**. The tested system uses Ubuntu 26.04.1 with `6.8.0-147-generic`; other combinations are unverified. The installer does not change your kernel or add package repositories.

1. [Download the experimental package](https://github.com/gregcmartin/gole2-linux-wifi-fixes/releases/tag/v0.1.0-experimental) and extract `gole2-linux-wifi-fixes-0.1.0-experimental.tar.gz`. SHA-256 checksums are provided on the same page. Alternatively, clone this repository.
2. Open a terminal in the extracted folder and run:

   ```bash
   sudo ./install.sh
   ```

3. Save your work and reboot when ready:

   ```bash
   sudo reboot
   ```

The installer downloads Ubuntu build dependencies and matching headers, builds the included source using DKMS, configures the workaround, and disables NetworkManager Wi-Fi power saving. It does **not** unload the current driver or reboot automatically. It stops if another `rtw88`/`rtl8821ce` DKMS installation exists; resolve that installation first instead of stacking drivers.

Keep this folder for uninstalling. If your system has custom module blacklists or `module_blacklist=` boot arguments from earlier troubleshooting, resolve them first; the installer leaves those settings alone. The GOLE test machine currently uses a manually loaded driver and a boot blacklist while testing continues.

## Check the result

```bash
sudo ./scripts/status.sh
```

Expect `rtw_8821ce`, DKMS version `0.6-gole1`, and `Y` for `disable_host_aspm`, `disable_aspm`, and `disable_lps_deep`. Both ends of the Wi-Fi PCIe link should show `ASPM Disabled`. The status script prints hardware state and PCIe error counters without printing Wi-Fi names or passwords.

Connect normally through the desktop Wi-Fi menu. If a connection profile explicitly re-enables power saving later, turn it off again:

```bash
nmcli connection modify "YOUR WI-FI PROFILE" 802-11-wireless.powersave 2
```

## Recovery and removal

If booting with Wi-Fi freezes the machine, edit the Linux command line in GRUB for one boot and append:

```text
module_blacklist=rtw_8821ce,rtw88_8821ce
```

Boot using Ethernet, then run:

```bash
sudo ./uninstall.sh
sudo reboot
```

Removal restores saved NetworkManager power-save values when they have not subsequently been changed, removes this package's configuration and DKMS source, and refreshes the current kernel's initramfs. It does not unload a running driver. See [installation and recovery details](docs/INSTALLATION.md).

## What changes in the driver?

The existing `disable_aspm` option controls Realtek device-specific power saving. On the test GOLE, the standard PCIe link remained in L0s/L1 with that option enabled. The patch adds an opt-in `rtw_pci.disable_host_aspm` parameter that calls the Linux PCI core's `pci_disable_link_state()` before device DMA setup, disabling L0s, L1 and clock power management. The PCI core also disables L1 substates on this tested kernel.

The option defaults to off in the source. The installer enables it along with `disable_aspm` and `disable_lps_deep`. Disabling link power saving may increase power consumption. This package leaves thermal protection, CPU power limits, graphics, audio and display settings alone.

- [Test results and remaining work](docs/TESTING.md)
- [Small, reviewable source patch](patches/0001-disable-host-pcie-aspm.patch)
- [Upstream source provenance and licensing](UPSTREAM.md)

## Credits and license

The driver is a snapshot of [lwfinger/rtw88](https://github.com/lwfinger/rtw88) at [`a56bcd26e770257612a0803249cbd4095fc6feca`](https://github.com/lwfinger/rtw88/commit/a56bcd26e770257612a0803249cbd4095fc6feca), with the GOLE patch applied. Credit belongs to the original Realtek, Linux wireless and downstream driver contributors; their copyright and license notices remain in the source.

The distribution is GPL-2.0; individual upstream files retain their original license choices, including GPL-2.0 OR BSD-3-Clause. See [LICENSE](LICENSE), [licenses](licenses) and [UPSTREAM.md](UPSTREAM.md). No firmware binaries or signing keys are bundled. Firmware comes from Ubuntu's `linux-firmware` package.
