# Index

One row per test, newest first. Single-stream column shows all three runs -
the spread is the finding.

| Date | Phone | Carrier | Driver | Bus | CC | Single (Mbps) | Par-4 | RTT avg | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-05 | [Motorola razr 2024](tests/2026-09-05-motorola-razr-2024-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 104 / 117 / 140 | 234 | 37.6 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-google-fi.md) | Google Fi | cdc_ncm | 2.0 | bbr | 114 / 116 / 63 | 246 | 37.4 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-bbr.md) | Google Fi | cdc_ncm | 2.0 | bbr | 125 / 153 / 106 | — | 29.7 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-cubic.md) | Google Fi | cdc_ncm | 2.0 | cubic | 15 / 44 / 116 | 211 | 29.6 ms | poor |

## To test

- [ ] iPhone - host side is ready (`ipheth` + `usbmuxd` 1.1.1 +
      `libimobiledevice-utils` 1.3.0 installed 2026-09-05), never tested against
      real hardware. iOS 17+ may bind `cdc_ncm` instead of `ipheth`; record which.
- [ ] Pixel 9a on a USB 3 cable - now known to be worth doing: the phone's BOS
      descriptor advertises SuperSpeed (`wSpeedsSupported 0x000f`) yet it
      enumerates at 480, so the ceiling is the cable or the port, not the phone.
      Contrast the razr 2024, which advertises no SuperSpeed at all.
- [x] Pixel 9a 4-stream parallel under BBR - done 2026-09-05, 246 Mbps
      ([record](tests/2026-09-05-pixel-9a-google-fi.md)).
- [x] Any RNDIS phone - done 2026-09-05, Motorola razr 2024
      ([record](tests/2026-09-05-motorola-razr-2024-google-fi.md)).
