# Index

One row per test, newest first. Single-stream column shows all three runs -
the spread is the finding.

| Date | Phone | Carrier | Driver | Bus | CC | Single (Mbps) | Par-4 | RTT avg | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-05 | [Galaxy S24](tests/2026-09-05-galaxy-s24-google-fi-lte.md) | Google Fi | rndis_host | 2.0 | bbr | 115 / 113 / 143 | 263 | 22.0 ms | good |
| 2026-09-05 | [iPhone 17 Pro](tests/2026-09-05-iphone-17-pro-att.md) | AT&T | ipheth | 2.0 | bbr | 96 / 103 / 103 | 178 | 38.0 ms | good |
| 2026-09-05 | [iPhone 16e](tests/2026-09-05-iphone-16e-google-fi.md) | Google Fi | ipheth | 2.0 | bbr | 87 / 119 / 101 | 228 | 25.6 ms | good |
| 2026-09-05 | [Motorola razr 2024](tests/2026-09-05-motorola-razr-2024-google-fi-cubic.md) | Google Fi | rndis_host | 2.0 | cubic | 135 / 121 / 163 | 238 | 37.7 ms | usable |
| 2026-09-05 | [Galaxy S24](tests/2026-09-05-galaxy-s24-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 98 / 112 / 113 | 230 | 36.4 ms | good |
| 2026-09-05 | [Galaxy S25](tests/2026-09-05-galaxy-s25-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 70 / 112 / 61 | 238 | 31.4 ms | good |
| 2026-09-05 | [Galaxy Z Flip6](tests/2026-09-05-galaxy-z-flip6-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 102 / 121 / 113 | 232 | 23.0 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-att.md) | AT&T | cdc_ncm | 2.0 | bbr | 106 / 100 / 104 | 273 | 36.8 ms | good |
| 2026-09-05 | [Motorola razr 2024](tests/2026-09-05-motorola-razr-2024-google-fi.md) | Google Fi | rndis_host | 2.0 | bbr | 104 / 117 / 140 | 234 | 37.6 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-google-fi.md) | Google Fi | cdc_ncm | 2.0 | bbr | 114 / 116 / 63 | 246 | 37.4 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-bbr.md) | Google Fi | cdc_ncm | 2.0 | bbr | 125 / 153 / 106 | — | 29.7 ms | good |
| 2026-09-05 | [Pixel 9a](tests/2026-09-05-pixel-9a-cubic.md) | Google Fi | cdc_ncm | 2.0 | cubic | 15 / 44 / 116 | 211 | 29.6 ms | poor |

## To test

- [x] iPhone - done 2026-09-05, iPhone 16e on iOS 27.0
      ([record](tests/2026-09-05-iphone-16e-google-fi.md)). **It binds `ipheth`**,
      not `cdc_ncm`. Also: `/28` subnet rather than `/24`, and `carrier.network`
      is unobtainable on iOS - there is no adb equivalent.
- [ ] **Try a different cable - the port has been ruled out.** The iPhone 17 Pro
      advertises SuperSpeedPlus at 10 Gb/s and enumerated at 480 in **two
      different physical USB-C ports** (`3-2` then `3-1`), same cable both times,
      on a host whose `usb2` (20 Gb/s) and `usb4` (10 Gb/s) root hubs are working
      and idle. Two ports failing the same way is far less likely than one bad
      cable, so the cable is now the prime suspect. A known-good USB 3 cable
      settles it.
      (The razr 2024 and iPhone 16e advertise no SuperSpeed, so 480 is genuinely
      their ceiling and they cannot help answer this.)
- [ ] **Find the Thunderbolt 4 port.** Controller `00:0d.0` with its 20 Gb/s
      root hub has never had a single device attached, across every phone and
      peripheral tested. Neither USB-C port tried so far reaches it, so there is
      a port on this machine - likely marked with a lightning bolt - that has
      never been used. Worth locating: TB4 is guaranteed SuperSpeed-wired, so a
      480 reading there would convict the cable beyond doubt.
- [x] Pixel 9a 4-stream parallel under BBR - done 2026-09-05, 246 Mbps
      ([record](tests/2026-09-05-pixel-9a-google-fi.md)).
- [x] Any RNDIS phone - done 2026-09-05, Motorola razr 2024
      ([record](tests/2026-09-05-motorola-razr-2024-google-fi.md)).
- [ ] Capture `gsm.network.type` during a pass on the four records that still
      have `carrier.network` blank - or accept that they cannot be filled
      retrospectively and leave them.
- [ ] **Re-run the two Galaxy S24 units back to back.** They differ only in
      radio (NR_SA vs LTE) and the LTE unit won on every measure, including
      14.4 ms of RTT. Running them at the same moment removes the
      time-of-day confound; forcing one unit between LTE and 5G removes
      the last one.
