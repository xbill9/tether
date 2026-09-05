---
id: 2026-09-05-pixel-9a-att-retest
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
  cable: "USB-C to USB-C"
link:
  interface: enx2e9319548995
  ipv4: 10.97.185.76/24
  gateway: 10.97.185.21
  ipv6: false # no global IPv6 assigned during this session
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
  single_stream_mbps: [27.570, 19.425, 8.231]
  parallel_4_aggregate_mbps: 5.048
  rtt_ms:
    min: 25.928
    avg: 70.811
    max: 121.017
    mdev: 32.939
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: poor
---

# Pixel 9a on AT&T — afternoon retest

## Setup

Measured 2026-09-05, 15:35:03–15:36:12 EDT. Retest of the AT&T Pixel 9a
([initial test](2026-09-05-pixel-9a-att.md)) to evaluate whether the AT&T cell
recovery confirmed on the iPhone 17 Pro extended to this unit. Connected via
USB-C to USB-C in port `3-1`.

The phone enumerated as `18d1:4eec` (NCM+ADB composite), binding `cdc_ncm`
on interface `enx2e9319548995` with IPv4 `10.97.185.76/24` and gateway
`10.97.185.21`. No global IPv6 address was provisioned during this session,
so transfers and ping resolved over IPv4 (`172.66.0.218`). Wi-Fi was down,
and the tether was the sole default route.

ADB verified `Pixel 9a`, Android 17, and active radio `LTE` before and after
transfers (`gsm.network.type: LTE,IWLAN`).

Bus speed was 480 Mbps (USB 2.0). Negotiated link speed read 425 Mbps.
NTB parameters were standard (`rx_max`/`tx_max` 16384, matching device descriptor limits,
`tx_timer_usecs=400`). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers
completed with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 27.570 / 19.425 / 8.231 Mbps (3.35x drop across runs).
Parallel 4 streams: 1.276 / 1.260 / 1.260 / 1.253 Mbps (summed from unrounded
bytes/sec: 5.048 Mbps aggregate).

Idle RTT: 25.928 / 70.811 / 121.017 / 32.939 ms min/avg/max/mdev with 0% packet loss.

Rather than mirroring the iPhone 17 Pro's 185.5 Mbps recovery on AT&T, this Pixel 9a
pass encountered an **unmistakable 5.0 Mbps hard throttle**:
- Single-stream speeds stepped down sharply from 27.6 to 19.4 to 8.2 Mbps.
- The four parallel streams divided a 5.0 Mbps ceiling almost perfectly equally
  (~157 KB/s or 1.26 Mbps per stream).
- The total parallel transfer duration took ~51 seconds against this 5 Mbps ceiling.

This exact throttle pattern (single stream stepping down into a ~5.0 Mbps aggregate split
four ways) mirrors the behavior observed earlier today on the Motorola razr plus 2023
on Google Fi.

**The operator confirmed immediately following the pass that the iPhone 17 Pro and
the Pixel 9a are on the exact same AT&T plan.**

Because the iPhone achieved 185.5 Mbps aggregate just minutes earlier on the same plan
and cell, this 5.0 Mbps clamp reveals a line- or OS-specific policy difference:
1. **Per-line quota exhaustion**: If the shared plan meters high-speed mobile hotspot
   per line (e.g., a 10–30 GB monthly allotment), the Pixel 9a line may have crossed
   its threshold during earlier testing passes today, entering AT&T's throttled hotspot
   state (which hard-caps at 5.0 Mbps), while the iPhone line still has high-speed quota.
2. **Tethering detection & TTL / APN inspection**: Android forwards packets as a standard
   IP gateway, decrementing IPv4 TTL (64 → 63), which carriers routinely inspect at the
   PGW/UPF to steer traffic into hotspot accounting buckets. iOS (`ipheth`) uses a
   carrier-bundle profile that may route or classify traffic differently.
3. **Radio Access Technology**: The Pixel was connected to LTE (`LTE,IWLAN`), while the
   iPhone operated with full bandwidth.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Check the line-level data usage and hotspot quota breakdown on AT&T's account portal
  for both the iPhone 17 Pro and Pixel 9a lines.
- Test setting host TTL (`sysctl -w net.ipv4.ip_default_ttl=65`) or inspecting packet
  headers to verify whether AT&T is applying TTL-based hotspot classification.
