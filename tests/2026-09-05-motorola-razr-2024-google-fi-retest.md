---
id: 2026-09-05-motorola-razr-2024-google-fi-retest
date: 2026-09-05
phone:
  make: Motorola
  model: razr 2024 (XT2453-3)   # SKU backfilled 2026-09-05, see body
  os: Android 16 # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.sim.operator.alpha: Google Fi
  network: 5G # gsm.network.type read "Unknown,NR_SA" before and after transfers
usb:
  vendor_id: "22b8"
  product_id: "2e25" # composite RNDIS+ADB
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # rndis_host does not report link speed
  cable: "USB-C to USB-C"
link:
  interface: enx9ad117016371
  ipv4: 10.142.52.87/24
  gateway: 10.142.52.254
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [104.088, 98.389, 116.914]
  parallel_4_aggregate_mbps: 233.831
  rtt_ms:
    min: 27.187
    avg: 35.710
    max: 52.756
    mdev: 8.868
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Motorola razr 2024 on Google Fi — afternoon retest

> `phone.model` SKU suffix `(XT2453-3)` backfilled 2026-09-05 from the
> [initial test](2026-09-05-motorola-razr-2024-google-fi.md), which is the same
> physical handset (`aito_g_sysu`, established below). adb reported the model
> string as `motorola razr 2024` during this pass; the SKU was not read at test
> time. No measurement was changed.

## Setup

Measured 2026-09-05, 16:33:45–16:33:53 EDT. Afternoon retest of the Motorola razr 2024
(non-plus model, `aito_g_sysu`, [initial test](2026-09-05-motorola-razr-2024-google-fi.md)),
connected via USB-C to USB-C in port `3-1`.

The phone enumerated as `22b8:2e25` (Motorola composite RNDIS+ADB), binding `rndis_host`
on interface `enx9ad117016371` with IPv4 `10.142.52.87/24`, gateway `10.142.52.254`,
and an IPv6 prefix in `2607:fb90:62d1:1ddd::/64` (T-Mobile / Google Fi). Wi-Fi was
down, and the tether interface was the sole default route.

ADB verified model `motorola razr 2024`, Android 16, and active radio on 5G
Standalone (`gsm.network.type: Unknown,NR_SA`) before and after transfers.

Bus speed was 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 104.088 / 98.389 / 116.914 Mbps (tight 1.19x spread).
Parallel 4 streams: 66.890 / 63.408 / 62.549 / 40.983 Mbps (summed from unrounded
bytes/sec: 233.831 Mbps aggregate, 2.00x best single stream).

Idle RTT: 27.187 / 35.710 / 52.756 / 8.868 ms min/avg/max/mdev with 0% packet loss.

### Comparison with morning baseline
- **Single-stream**: 98.4–116.9 Mbps vs 64–97 Mbps in the morning (+20% faster peak).
- **Par-4 Aggregate**: **233.831 Mbps** vs 172 Mbps in the morning (**+36% improvement**).
- **RTT**: 35.7 ms avg (8.9 ms mdev) vs 39.7 ms avg (7.2 ms mdev).
- **Carrier State**: This Google Fi account remains fully unthrottled with active
  high-speed tethering quota, matching the unthrottled performance of the Pixel 7
  and contrasting with the accounts that reached the 5.0 Mbps cap today.

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Test on the USB-A cable for direct comparison against the USB-C results.
