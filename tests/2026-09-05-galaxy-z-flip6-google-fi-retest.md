---
id: 2026-09-05-galaxy-z-flip6-google-fi-retest
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy Z Flip6 (SM-F741U1)
  os: Android 16 # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.sim.operator.alpha: Google Fi
  network: 5G # gsm.network.type read "Unknown,NR_SA" before and after transfers
usb:
  vendor_id: "04e8"
  product_id: "6864" # composite RNDIS+ADB
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # rndis_host does not report link speed
  cable: "USB-C to USB-C"
link:
  interface: enx322695216453
  ipv4: 10.219.200.197/24
  gateway: 10.219.200.148
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [97.583, 109.760, 105.418]
  parallel_4_aggregate_mbps: 217.599
  rtt_ms:
    min: 25.741
    avg: 39.783
    max: 56.889
    mdev: 10.782
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Samsung Galaxy Z Flip6 on Google Fi — afternoon retest

## Setup

Measured 2026-09-05, 16:38:39–16:38:47 EDT. Afternoon retest of the Samsung Galaxy Z Flip6
(`SM-F741U1`, [morning baseline](2026-09-05-galaxy-z-flip6-google-fi.md)), connected
via USB-C to USB-C in port `3-1`.

The phone enumerated as `04e8:6864` (Samsung composite RNDIS+ADB), binding `rndis_host`
on interface `enx322695216453` with IPv4 `10.219.200.197/24`, gateway `10.219.200.148`,
and a global IPv6 prefix in `2607:fb90:62d0:4979::/64` (T-Mobile / Google Fi).
Wi-Fi remained down, and the tether interface was the sole default route.

ADB verified model `SM-F741U1` (Galaxy Z Flip6), Android 16, and active radio on 5G
Standalone (`gsm.network.type: Unknown,NR_SA`) before and after transfers.

Bus speed was 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 97.583 / 109.760 / 105.418 Mbps (very tight 1.12x spread).
Parallel 4 streams: 62.917 / 61.684 / 61.519 / 31.479 Mbps (summed from unrounded
bytes/sec: 217.599 Mbps aggregate, 1.98x best single stream).

Idle RTT: 25.741 / 39.783 / 56.889 / 10.782 ms min/avg/max/mdev with 0% packet loss.

### Comparison with morning baseline
- **Single-stream**: 97.6–109.8 Mbps (1.12x spread) vs 102–121 Mbps (1.19x spread).
- **Par-4 Aggregate**: **217.599 Mbps** vs 232 Mbps in the morning.
- **RTT**: 39.8 ms avg (10.8 ms mdev) vs 23.0 ms avg (1.8 ms mdev).
- **Carrier State**: This Google Fi line remains completely unthrottled with active
  high-speed mobile hotspot allowance, running at full 5G SA speeds.

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Test with the USB-A cable for direct comparison against the Type-C results.
