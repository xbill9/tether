---
id: 2026-09-05-iphone-16e-google-fi-usba
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
  cable: "USB-A to USB-C" # tested on USB-A port 3-3
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
  single_stream_mbps: [28.563, 29.443, 23.301]
  parallel_4_aggregate_mbps: 13.097
  rtt_ms:
    min: 19.888
    avg: 70.563
    max: 149.799
    mdev: 49.828
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: usable
---

# iPhone 16e on Google Fi — USB-A test

## Setup

Measured 2026-09-05, 16:06:03–16:06:35 EDT. Second session for the iPhone 16e
(`iPhone17,5`), moved from the USB-C port (`3-1`) to the USB-A port (`3-3`) via the
USB-A to USB-C cable for direct comparison against the
[C-to-C retest](2026-09-05-iphone-16e-google-fi-retest.md) conducted five minutes earlier.

The phone enumerated as `05ac:12a8`, binding `ipheth` on interface `enx925f7a841529`
with IPv4 `172.20.10.5/28`, gateway `172.20.10.1`, and an IPv6 prefix in
`2607:fb91::/32` (T-Mobile / Google Fi). Wi-Fi remained down, and the tether interface
was the sole default route.

`ideviceinfo` confirmed `ProductType: iPhone17,5` and `ProductVersion: 27.0`.
Bus speed was 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 28.563 / 29.443 / 23.301 Mbps (1.26x spread).
Parallel 4 streams: 3.419 / 3.365 / 3.168 / 3.145 Mbps (summed from unrounded
bytes/sec: 13.097 Mbps aggregate, 0.44x best single stream).

Idle RTT: 19.888 / 70.563 / 149.799 / 49.828 ms min/avg/max/mdev with 0% packet loss.

### Back-to-back cable comparison on iPhone 16e
Comparing this USB-A pass directly with the C-to-C pass run 5 minutes earlier:
- **Single-stream**: 23.3–29.4 Mbps on USB-A vs **81.6–91.0 Mbps on C-to-C** (~3.1× faster on C-to-C)
- **Parallel Aggregate**: 13.097 Mbps on USB-A vs **167.361 Mbps on C-to-C** (~12.8× faster on C-to-C)
- **RTT**: 70.6 ms avg (49.8 ms mdev) on USB-A vs **40.7 ms avg (13.4 ms mdev) on C-to-C**

On this handset and driver (`ipheth`), switching to the USB-A port caused a dramatic
throughput degradation, dropping parallel throughput by over 92% and elevating latency
jitter. This reinforces the finding that USB-C to USB-C direct connection yields vastly
superior throughput across handsets and drivers.

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Investigate whether the host's USB-A root hub/controller scheduling creates extra
  queuing latency or packet bundling overhead for `ipheth` isochronous/bulk URBs.
