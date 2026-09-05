---
id: 2026-09-05-iphone-17-pro-att-usba-retest
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
  cable: "USB-A to USB-C" # retested on USB-A port 3-3
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
  single_stream_mbps: [69.571, 73.760, 73.673]
  parallel_4_aggregate_mbps: 153.656
  rtt_ms:
    min: 32.431
    avg: 42.021
    max: 55.673
    mdev: 7.638
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# iPhone 17 Pro on AT&T — USB-A retest

## Setup

Measured 2026-09-05, 15:31:13–15:31:22 EDT. Seventh session for the iPhone 17 Pro
(`iPhone18,1`), retesting the USB-A port (`3-3`) via the USB-A to USB-C cable for
direct back-to-back comparison with the [C-to-C retest](2026-09-05-iphone-17-pro-att-retest.md)
completed three minutes earlier.

The device bound `ipheth` on `enxb65575abcda3` with IPv4 `172.20.10.5/28` and
gateway `172.20.10.1`. IPv6 was delegated within `2600:382::/32`. Wi-Fi (`wlo1`)
remained down, and the tether was the sole default route throughout.

BOS descriptors advertise SuperSpeed/SuperSpeedPlus capability, though the bus
operates at 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers
completed with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 69.571 / 73.760 / 73.673 Mbps (1.06x spread, near flat).
Parallel 4 streams: 41.422 / 41.287 / 35.795 / 35.152 Mbps (summed from unrounded
bytes/sec: 153.656 Mbps aggregate).

Idle RTT: 32.431 / 42.021 / 55.673 / 7.638 ms min/avg/max/mdev with 0% packet loss.

Direct comparison with the C-to-C retest run three minutes prior (15:28):
- **Single-stream**: 69.6–73.8 Mbps on USB-A vs 72.8–88.1 Mbps on C-to-C
- **Par-4 Aggregate**: 153.7 Mbps on USB-A vs **185.5 Mbps on C-to-C**
- **RTT**: **42.0 ms (7.6 ms mdev)** on USB-A vs 59.8 ms (9.4 ms mdev) on C-to-C

Across both handsets tested back-to-back today (Galaxy Z Flip5 and iPhone 17 Pro):
1. **Throughput**: C-to-C consistently delivered higher aggregate throughput (+21% on iPhone, +146% on Flip5).
2. **Latency**: USB-A consistently produced slightly lower idle RTT latency (~42 ms vs ~60 ms on iPhone, ~33 ms vs ~41 ms on Flip5).

Link counters remained completely clean with zero errors and zero drops.

## Issues

None.

## Follow-ups

- Re-run the AT&T Pixel 9a for cross-device comparison against this recovered AT&T baseline.
