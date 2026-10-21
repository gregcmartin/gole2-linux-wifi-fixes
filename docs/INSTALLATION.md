# Installation details

## Scope

Run `sudo ./install.sh --check` for a read-only platform/conflict check. A normal installation uses the Ubuntu repositories already configured on the machine to install DKMS, build tools, GCC 13, headers matching `uname -r`, firmware, PCI utilities, `iw` and `mokutil`. It does not install a different kernel or configure repositories. If matching headers are unavailable, stop and resolve that through your distribution.

This first package deliberately accepts only Ubuntu on x86-64 with a 6.8.x kernel and an RTL8821CE. Only the exact configuration in [TESTING.md](TESTING.md) has been exercised. Secure Boot is not supported by this experimental installer; it stops when Secure Boot is enabled instead of silently leaving a module that cannot load. Secure Boot signing/enrollment needs separate validation.

DKMS is used so future kernel installations can attempt a rebuild. That is not a promise of compatibility with a different kernel series. Keep a working recovery route when changing kernels.

## Files and behavior

- `/usr/src/rtw88-0.6-gole1/`: packaged driver source.
- `/etc/modprobe.d/90-gole2-wifi-fixes.conf`: blacklists stock RTL8821CE modules and sets the three power-saving parameters for the replacement.
- `/etc/NetworkManager/conf.d/90-gole2-wifi-fixes.conf`: disables the default Wi-Fi power-saving setting.
- `/var/lib/gole2-linux-wifi-fixes/`: installation marker and saved numeric per-profile power-saving values, identified by UUID. No credentials are copied.

Existing Wi-Fi profiles are set to power saving `2` (disabled). The old numeric values are saved for uninstall. Changes take effect after reconnect/reboot; the installer leaves the current connection running. This setting also affects other saved Wi-Fi profiles on the machine.

Build/install happens before network configuration is changed. A failure removes this new DKMS registration and owned files and attempts to restore saved profile values. Existing installations, package-managed driver source, and occupied configuration paths cause a stop before changes to those items. Dependencies successfully installed by apt are retained, even after failure or uninstall.

The installer refreshes only the running kernel's initramfs. For other previously installed kernels, regenerate their initramfs separately before booting them. No bootloader arguments are changed.

Custom blacklists, explicit `install MODULE /bin/false` rules, or `module_blacklist=` arguments from previous experiments can prevent loading. Inspect those yourself before rebooting. Do not delete unrelated recovery settings just to force the driver to load.

## Recovery

At GRUB, press `e` on your Ubuntu entry and append `module_blacklist=rtw_8821ce,rtw88_8821ce` to the line beginning with `linux`. If the line already has `module_blacklist=`, add the module names to its comma-separated value. Boot with Ctrl-X or F10. This is a temporary one-boot setting.

Use Ethernet to log in. Run `sudo ./uninstall.sh` from the downloaded folder, then reboot. The uninstall script leaves a loaded module running until reboot. It restores saved profile power-saving values only if the current value is still `2`; profiles changed by you after installation are preserved. Profiles deleted since installation are skipped.

This restores the distribution driver on a normal boot, which may reproduce the original freeze. For an Ethernet-only recovery, keep both drivers blocked in a local modprobe configuration until ready to test again. Removing this package does not fix the stock driver.

## Building a distribution archive

Run `./scripts/package.py` with Python 3. It creates a versioned source tarball and `SHA256SUMS` in `dist/`. The archive contains the exact source and local build scripts, so users need no additional Git checkout. No precompiled kernel module is distributed: DKMS builds for the installed kernel.
