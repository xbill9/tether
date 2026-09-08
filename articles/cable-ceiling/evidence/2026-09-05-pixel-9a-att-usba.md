---
id: 2026-09-05-pixel-9a-att-usba
date: 2026-09-05
phone:
  make: Google
  model: Pixel 9a
  os: Android 17 # beta build CP41.260814.003.B1, sdk 37 over adb
carrier:
  name: AT&T
  network: LTE # adb read "LTE,IWLAN" both before and after transfers
usb:
  vendor_id: "18d1"
  product_id: "4eec" # NCM+ADB composite
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable: "USB-A to USB-C" # tested on USB-A port 3-3
link:
  interface: enx2e9319548995
  ipv4: 10.97.185.76/24
  gateway: 10.97.185.21
  ipv6: false # no global IPv6 assigned in this session
  mtu: 1500
  mtu_max: 1500
ntb:
  rx_max: 16384
  tx_max: 16384
  device_max_in: 16384
  device_max_out: 16384
  tx_timer_usecs: 400
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [30.418, 20.302, 6.908]
  parallel_4_aggregate_mbps: 5.054
  rtt_ms:
    min: 34.193
    avg: 49.761
    max: 85.807
    mdev: 18.435
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: poor
---

# Pixel 9a on AT&T — USB-A test

## Setup

Measured 2026-09-05, 15:46:08–15:47:17 EDT. Fourth session for the AT&T Pixel 9a,
switched to the USB-A port (`3-3`) via the USB-A to USB-C cable.

The handset enumerated as `18d1:4eec` (NCM+ADB composite), binding `cdc_ncm`
on interface `enx2e9319548995` with IPv4 `10.97.185.76/24` and gateway
`10.97.185.21`. Wi-Fi remained down, and the tether was the sole default route.

ADB verified `Pixel 9a`, Android 17, and active radio `LTE` before and after
transfers (`gsm.network.type: LTE,IWLAN`).

Bus speed was 480 Mbps (USB 2.0). Link speed was 425 Mbps. NTB parameters were
standard (`rx_max`/`tx_max` 16384, matching device descriptor limits,
`tx_timer_usecs=400`). Host TTL was confirmed at the default 64. Pre-test link
error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 30.418 / 20.302 / 6.908 Mbps (4.40x drop).
Parallel 4 streams: 1.266 / 1.264 / 1.263 / 1.261 Mbps (summed from unrounded
bytes/sec: 5.054 Mbps aggregate).

Idle RTT: 34.193 / 49.761 / 85.807 / 18.435 ms min/avg/max/mdev with 0% packet loss.

### Throttle persists across cable and port switch

Switching from USB-C (port `3-1`) to USB-A (port `3-3`) did not affect the
underlying carrier throttle:
- Single-stream transfers followed the identical step-down pattern (starting at
  ~30 Mbps and collapsing to ~6.9 Mbps).
- The four parallel streams once again hit the exact **5.0 Mbps hard cap**,
  distributing ~1.26 Mbps per flow over ~51 seconds.
- Consistent with previous USB-A passes on the iPhone 17 Pro and Galaxy Z Flip5,
  the USB-A port configuration yielded somewhat lower idle RTT latency (49.8 ms avg
  here vs 70.8 ms on C-to-C retest).

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Check AT&T account management to confirm the exact monthly hotspot quota and reset date
  for this line.
