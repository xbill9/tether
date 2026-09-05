---
id: 2026-09-05-iphone-17-pro-att-retest
date: 2026-09-05
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)
  os: iOS 27.0 # build 24A5430a over usbmuxd (ideviceinfo)
carrier:
  name: AT&T # corroborated by 2600:382::/32 delegation
  network: # TODO not obtainable - iOS exposes no equivalent of gsm.network.type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps: # TODO ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "USB-C to USB-C" # back to C-to-C on port 3-1
link:
  interface: enxb65575abcda3
  ipv4: 172.20.10.5/28
  gateway: 172.20.10.1
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [72.847, 88.078, 77.852]
  parallel_4_aggregate_mbps: 185.460
  rtt_ms:
    min: 51.993
    avg: 59.829
    max: 76.055
    mdev: 9.350
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# iPhone 17 Pro on AT&T — afternoon retest

## Setup

Measured 2026-09-05, 15:28:10–15:28:19 EDT. Sixth session for this handset today,
returning to a USB-C to USB-C cable in Type-C port `3-1` following the
[USB-A test](2026-09-05-iphone-17-pro-att-usba.md).

The device bound `ipheth` on `enxb65575abcda3` with IPv4 `172.20.10.5/28` and
gateway `172.20.10.1`. IPv6 was delegated within `2600:382::/32`, corroborating
AT&T service. Wi-Fi (`wlo1`) remained down, and the tether was the sole default
route throughout.

BOS descriptors continue to advertise SuperSpeed and SuperSpeedPlus capability
(10 Gbps), though the bus operates at 480 Mbps (USB 2.0). Pre-test link error
and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers
completed with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 72.847 / 88.078 / 77.852 Mbps (1.21x spread).
Parallel 4 streams: 49.062 / 48.974 / 46.815 / 40.610 Mbps (summed from unrounded
bytes/sec: 185.460 Mbps aggregate).

Idle RTT: 51.993 / 59.829 / 76.055 / 9.350 ms min/avg/max/mdev with 0% packet loss.

This result decisively validates the carrier recovery progression tracked in the
log. Across six passes on this handset today:
- 12:40 (cable 1, port `3-2`): 178 Mbps aggregate, 38.0 ms RTT
- 13:15 (cable 2, port `3-1`): 73 Mbps aggregate, 103.6 ms RTT (the afternoon dip)
- 13:19 (cable 2 settled): 85 Mbps aggregate, 54.2 ms RTT
- 13:26 (cable 3): 101 Mbps aggregate, 45.9 ms RTT
- 14:12 (USB-A port `3-3`): 130 Mbps aggregate, 52.1 ms RTT
- 15:28 (C-to-C port `3-1`): **185.460 Mbps aggregate**, 59.8 ms RTT

Throughput has fully recovered to—and slightly exceeded—the morning's 178 Mbps baseline,
demonstrating that earlier intermediate figures tracked the recovery curve of the AT&T
cell rather than intrinsic cable throughput differences.

Link counters recorded zero errors and zero drops across the pass.

## Issues

None.

## Follow-ups

- Re-run the AT&T Pixel 9a to compare cross-device performance against this
  fully recovered AT&T cell baseline.
