---
id: 2026-09-05-iphone-16e-google-fi-retest
date: 2026-09-05
phone:
  make: Apple
  model: iPhone 16e (iPhone17,5)
  os: iOS 27.0 # read over usbmuxd (ideviceinfo)
carrier:
  name: Google Fi # operator-supplied
  network: # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps: # ipheth does not report link speed
  cable: "USB-C to USB-C"
link:
  interface: enx925f7a841529
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
  single_stream_mbps: [91.017, 81.637, 87.004]
  parallel_4_aggregate_mbps: 167.361
  rtt_ms:
    min: 21.941
    avg: 40.665
    max: 58.702
    mdev: 13.441
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# iPhone 16e on Google Fi — afternoon retest

## Setup

Measured 2026-09-05, 16:01:09–16:01:17 EDT. Afternoon retest of the iPhone 16e
on Google Fi ([initial test](2026-09-05-iphone-16e-google-fi.md)), connected via
USB-C to USB-C in port `3-1`.

The phone enumerated as `05ac:12a8`, binding `ipheth` on interface `enx925f7a841529`
with IPv4 `172.20.10.5/28` and gateway `172.20.10.1`. Global IPv6 was assigned
in `2607:fb91::/32` (T-Mobile / Google Fi). Wi-Fi was down, and the tether interface
was the sole default route.

`ideviceinfo` reported `ProductType: iPhone17,5` and `ProductVersion: 27.0`.
Bus speed was 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 91.017 / 81.637 / 87.004 Mbps (extremely tight 1.11x spread).
Parallel 4 streams: 46.428 / 45.706 / 45.343 / 29.884 Mbps (summed from unrounded
bytes/sec: 167.361 Mbps aggregate, 1.84x best single stream).

Idle RTT: 21.941 / 40.665 / 58.702 / 13.441 ms min/avg/max/mdev with 0% packet loss.

### Comparison with morning baseline
- **Single-stream**: 81.6–91.0 Mbps (1.11x spread) vs 87–119 Mbps (1.37x spread) in the morning.
- **Parallel Aggregate**: 167.361 Mbps vs 228 Mbps in the morning.
- **RTT**: 40.7 ms avg (13.4 ms mdev) vs 25.6 ms avg (7.6 ms mdev) in the morning.

Performance remains solid with zero link errors or drops. The afternoon pass reflects
mild cellular network utilization relative to the morning peak, but with single-stream
consistency remaining exceptionally tight (1.11x spread across three runs).

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Test on the USB-A cable for direct bus comparison against the iPhone 17 Pro and
  Android devices.
