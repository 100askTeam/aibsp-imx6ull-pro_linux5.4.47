# Module Dependency Graph

## Directory Boundaries

- `linux_serial_agent/`
  - Owns serial discovery, serial sessions, Linux login verification and U-Boot serial control
- `flash_usb_shell/`
  - Owns only USB flashing commands, `uuu` invocation, USB enumeration and `.uuu` script execution
- `board_workflows/`
  - Owns orchestration and flashing strategy selection only

## Flashing Strategy Split

- `Fastboot`
  - For normal application development: package, rootfs overlay, userland service changes
  - Serial path: reboot from Linux or interrupt U-Boot, then enter `fastboot 0`
  - USB path: run local fastboot `.uuu` script
- `SDP`
  - For full system or low-level changes: U-Boot, kernel, DTB, driver, full image
  - Serial path: reboot from Linux or interrupt U-Boot, then run `bmode usb`
  - USB path: run `uuu -b emmc_all`

## Graph

```text
+------------------------+
| board_workflows        |
| - select_flash_mode.sh |
| - flash_fastboot...    |
| - flash_sdp_full.sh    |
+-----------+------------+
            | serial CLI                | usb shell
            v                           v
+------------------------+   +-------------------------+
| linux_serial_agent     |   | flash_usb_shell         |
| serial_agent_cli.py    |   | flash_fastboot_only.sh  |
| - enter-fastboot       |   | flash_sdp_only.sh       |
| - enter-usb-sdp        |   | usb_flash_cli.py        |
| - login-check          |   | *.uuu                   |
+------------------------+   +-------------------------+
```
