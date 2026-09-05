# Index

One row per test, newest first. Single-stream column shows all three runs -
the spread is the finding.

| Date | Phone | Carrier | Driver | Bus | CC | Single (Mbps) | Par-4 | RTT avg | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-05 | [Galaxy S25](tests/2026-09-05-galaxy-s25-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 70 / 112 / 61 | 238 | 31.4 ms | good |
| 2026-09-05 | [Galaxy Z Flip6](tests/2026-09-05-galaxy-z-flip6-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 102 / 121 / 113 | 232 | 23.0 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-att.md) | AT&T | cdc_ncm | 2.0 | bbr | 106 / 100 / 104 | 273 | 36.8 ms | good |
| 2026-09-05 | [Motorola razr 2024](tests/2026-09-05-motorola-razr-2024-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 104 / 117 / 140 | 234 | 37.6 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-google-fi.md) | Google Fi | cdc_ncm | 2.0 | bbr | 114 / 116 / 63 | 246 | 37.4 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-bbr.md) | Google Fi | cdc_ncm | 2.0 | bbr | 125 / 153 / 106 | — | 29.7 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-cubic.md) | Google Fi | cdc_ncm | 2.0 | cubic | 15 / 44 / 116 | 211 | 29.6 ms | poor |

## To test

- [ ] iPhone - host side is ready (`ipheth` + `usbmuxd` 1.1.1 +
      `libimobiledevice-utils` 1.3.0 installed 2026-09-05), never tested against
      real hardware. iOS 17+ may bind `cdc_ncm` instead of `ipheth`; record which.
- [ ] **USB 3 cable - the highest-value test in this repo.** Four
      SuperSpeed-capable phones across three vendors (2x Pixel 9a, Galaxy Z
      Flip6, Galaxy S25) all enumerate at 480, aggregate has reached 91% of
      the USB 2.0 ceiling, and no device on this host has ever trained
      SuperSpeed on any bus. The phone is ruled out; suspicion leans toward
      the host port over the cable, but one pass settles it.
- [x] Pixel 9a 4-stream parallel under BBR - done 2026-09-05, 246 Mbps
      ([record](tests/2026-09-05-pixel-9a-google-fi.md)).
- [x] Any RNDIS phone - done 2026-09-05, Motorola razr 2024
      ([record](tests/2026-09-05-motorola-razr-2024-google-fi.md)).
- [ ] Capture `gsm.network.type` during a pass on the four records that still
      have `carrier.network` blank - or accept that they cannot be filled
      retrospectively and leave them.
