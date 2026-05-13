#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from flash_usb_shell.usb_flash.core import (
    flash_emmc_all,
    list_usb_devices,
    run_uuu_script,
    wait_for_device,
    write_fastboot_script,
)


def _default_uuu_bin() -> str:
    return str(REPO_ROOT / 'uuucli/build/uuu/uuu')


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='USB flash abstract interface')
    parser.add_argument('--uuu-bin', default=_default_uuu_bin())
    sub = parser.add_subparsers(dest='subcmd', required=True)

    sub.add_parser('lsusb', help='List USB flash devices')

    wait_cmd = sub.add_parser('wait-device', help='Wait for USB device mode')
    wait_cmd.add_argument('--mode', choices=['sdp', 'fb', 'any'], default='any')
    wait_cmd.add_argument('--wait-sec', type=int, default=0)

    emmc = sub.add_parser('emmc-all', help='Run uuu -b emmc_all')
    emmc.add_argument('--flash-bin', required=True)
    emmc.add_argument('--emmc-img', required=True)

    script = sub.add_parser('run-script', help='Run a .uuu script')
    script.add_argument('--script', required=True)
    script.add_argument('--cwd', default='')
    script.add_argument('--allow-reset-disconnect', action='store_true')

    gen = sub.add_parser('write-fastboot-script', help='Generate a local fastboot .uuu script')
    gen.add_argument('--output', required=True)
    gen.add_argument('--image-name', default='sdcard.img')
    gen.add_argument('--no-reset', action='store_true')
    gen.add_argument('--no-prepare', action='store_true')
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.subcmd == 'lsusb':
        print(list_usb_devices(args.uuu_bin))
        return 0
    if args.subcmd == 'wait-device':
        try:
            mode = wait_for_device(args.uuu_bin, args.mode, args.wait_sec)
        except TimeoutError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        print(mode)
        return 0
    if args.subcmd == 'emmc-all':
        return flash_emmc_all(args.uuu_bin, args.flash_bin, args.emmc_img)
    if args.subcmd == 'run-script':
        cwd = args.cwd or None
        return run_uuu_script(args.uuu_bin, args.script, cwd=cwd, allow_reset_disconnect=args.allow_reset_disconnect)
    if args.subcmd == 'write-fastboot-script':
        print(
            write_fastboot_script(
                args.output,
                image_name=args.image_name,
                reset=not args.no_reset,
                prepare_device=not args.no_prepare,
            )
        )
        return 0
    parser.error('unsupported command')
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
