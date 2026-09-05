---
id: 2026-09-05-pixel-7-google-fi-usba
date: 2026-09-05
phone:
  make: Google
  model: Pixel 7
  os: # TODO not read - USB debugging not enabled; tether-only enumeration (18d1:4eeb)
carrier:
  name: Google Fi # identified from IPv6 prefix 2607:fb90:: (T-Mobile / Google Fi)
  network: # TODO not obtainable - adb unavailable in tether-only USB mode
usb:
  vendor_id: "18d1"
  product_id: "4eeb"
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable: "USB-A to USB-C" # tested on USB-A port 3-3
link:
  interface: enx9a5ef5a97bd5
  ipv4: 10.233.0.230/24
  gateway: 10.233.0.13
  ipv6: true
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
  single_stream_mbps: [52.565, 50.592, 47.243]
  parallel_4_aggregate_mbps: 65.495
  rtt_ms:
    min: 33.744
    avg: 78.501
    max: 129.148
    mdev: 32.500
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Google Pixel 7 on Google Fi — USB-A test

## Setup

Measured 2026-09-05, 16:26:52–16:27:05 EDT. Second session for the Google Pixel 7,
switched from the USB-C port (`3-1`) to the USB-A port (`3-3`) via the USB-A to
USB-C cable for direct comparison against the
[C-to-C test](2026-09-05-pixel-7-google-fi.md) run five minutes earlier.

The phone enumerated as `18d1:4eeb` (Google tether-only NCM mode without ADB).
Device manufacturer and model (`Google / Pixel 7`) were read from USB sysfs.
Interface `enx9a5ef5a97bd5` bound `cdc_ncm`, acquiring IPv4 `10.233.0.230/24` with
gateway `10.233.0.13`, and a global IPv6 prefix in `2607:fb90:62d3:9e0a::/64`
(T-Mobile / Google Fi). Wi-Fi was down, and the tether interface was the sole
default route.

Bus speed was 480 Mbps (USB 2.0), link speed was 425 Mbps with standard NTB
parameters (`rx_max`/`tx_max` 16384, `tx_timer_usecs=400`). Pre-test link error
and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 52.565 / 50.592 / 47.243 Mbps (tight 1.11x spread).
Parallel 4 streams: 20.523 / 17.029 / 14.563 / 13.380 Mbps (summed from unrounded
bytes/sec: 65.495 Mbps aggregate, 1.25x best single stream).

Idle RTT: 33.744 / 78.501 / 129.148 / 32.500 ms min/avg/max/mdev with 0% packet loss.

### Back-to-back cable comparison on Pixel 7
Comparing this USB-A pass directly with the C-to-C pass run 5 minutes earlier:
- **Single-stream**: 47.2–52.6 Mbps on USB-A vs **67.2–77.0 Mbps on C-to-C**
- **Par-4 Aggregate**: 65.495 Mbps on USB-A vs **112.040 Mbps on C-to-C** (+71% faster on C-to-C)
- **RTT**: 78.5 ms avg (32.5 ms mdev) on USB-A vs 122.2 ms avg (59.6 ms mdev) on C-to-C

As seen consistently across all handsets tested today (Flip5, iPhone 17 Pro,
Nord N200, iPhone 16e, and now Pixel 7), the direct Type-C to Type-C connection
yields markedly higher multi-stream aggregate throughput than the Type-A to Type-C
connection on the same bus speed (480 Mbps).

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Test with USB debugging enabled to verify OS version and cellular radio type.
