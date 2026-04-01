# Hailo-10H Support for Home Assistant OS (Buildroot)

## Summary

This fork replaces Hailo-8 support with Hailo-10H support in the HAOS buildroot
configuration. Hailo-8 and Hailo-10H drivers cannot coexist (they come from
different branches of the same upstream repo), so this is a breaking change that
drops Hailo-8 compatibility.

## What Changed

### Removed

- `buildroot-external/package/hailo-pci/` — Hailo-8 PCIe driver (v4.21.0,
  `hailo8` branch of hailort-drivers, kernel module `hailo_pci`)
- `buildroot-external/package/hailo8-firmware/` — Hailo-8 firmware (single
  `hailo8_fw.bin`)
- `buildroot-external/package/hailort/` — HailoRT userspace SDK (v4.21.0,
  hailo8-only)
- Patch `0001-Add-missing-lock-around-current-mm.patch` — already upstreamed in
  v5.x

### Added

- `buildroot-external/package/hailo10h-pci/` — Hailo-10H PCIe driver (v5.2.0,
  `master` branch of hailort-drivers, kernel module `hailo1x_pci`)
- `buildroot-external/package/hailo10h-firmware/` — Hailo-10H firmware (tar.gz
  archive with multi-stage boot files installed to
  `/lib/firmware/hailo/hailo10h/`)

### Modified

- `buildroot-external/Config.in` — sources hailo10h packages instead of hailo8
- `buildroot-external/board/raspberrypi/kernel.config` — updated comment
- 5 defconfigs updated (`rpi5_64`, `yellow`, `generic_aarch64`, `ova`,
  `generic_x86_64`): replaced `BR2_PACKAGE_HAILO8_FIRMWARE` /
  `BR2_PACKAGE_HAILO_PCI` with `BR2_PACKAGE_HAILO10H_FIRMWARE` /
  `BR2_PACKAGE_HAILO10H_PCI`

## Upstream References

- Driver repo: https://github.com/hailo-ai/hailort-drivers (tag `v5.2.0`,
  `master` branch)
- Firmware: https://hailo-hailort.s3.eu-west-2.amazonaws.com/Hailo10H/5.2.0/FW/hailo10h_fw.tar.gz
- The `master` branch supports Hailo-10H, Hailo-15L, and Hailo-12L (Mars)
- The `hailo8` branch (v4.x) supports Hailo-8/8R/8L — **not included in this
  fork**

## Licenses

- **Home Assistant OS** — Apache License 2.0 (see [LICENSE](LICENSE))
- **hailo10h-pci driver** (`hailort-drivers`) — GPL-2.0, per upstream
  [LICENSE](https://github.com/hailo-ai/hailort-drivers/blob/master/LICENSE)
- **hailo10h-firmware** — Proprietary, downloaded from Hailo's public S3 bucket.
  Subject to Hailo's [End User License Agreement](https://hailo.ai/terms-and-conditions/).
  Redistributed as a binary blob in the built image only.
- **Buildroot** — GPL-2.0 (see `buildroot/COPYING`)
