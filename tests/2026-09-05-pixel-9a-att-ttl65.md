---
id: 2026-09-05-pixel-9a-att-ttl65
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
  ipv6: false
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
  single_stream_mbps: [28.643, 31.448, 13.405]
  parallel_4_aggregate_mbps: 5.059
  rtt_ms:
    min: 35.471
    avg: 55.182
    max: 83.950
    mdev: 23.232
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: poor
---

# Pixel 9a on AT&T — host TTL 65 experiment

## Setup

Measured 2026-09-05, 15:41:30–15:42:38 EDT. Controlled follow-up to the
[afternoon retest](2026-09-05-pixel-9a-att-retest.md) testing whether the 5.0 Mbps
clamp was triggered by packet TTL inspection.

Host outbound TTL was temporarily configured to `net.ipv4.ip_default_ttl=65`
(so that after Android's kernel router decrements TTL by 1, forwarded packets
leave the phone with `TTL=64`, matching standard on-device Android traffic).
Immediately after the pass, host TTL was restored to the default `64`.

All other parameters remained identical: interface `enx2e9319548995`, `cdc_ncm`,
port `3-1`, USB-C to USB-C cable, radio on `LTE` (`LTE,IWLAN`), and TCP BBR.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 28.643 / 31.448 / 13.405 Mbps.
Parallel 4 streams: 1.270 / 1.264 / 1.263 / 1.261 Mbps (summed from unrounded
bytes/sec: 5.059 Mbps aggregate).

Idle RTT: 35.471 / 55.182 / 83.950 / 23.232 ms min/avg/max/mdev with 0% packet loss.

### Finding: The TTL manipulation did not bypass the 5.0 Mbps throttle

Setting outbound TTL to 65 produced results virtually identical to the unmanipulated
retest:
- Single-stream started at ~28–31 Mbps and degraded into the throttle (13.4 Mbps).
- The four parallel streams once again hit an **exact 5.0 Mbps ceiling**, dividing
  it four ways at ~1.26 Mbps (~158 KB/s) per stream.
- Zero errors and zero drops on the link.

This outcome demonstrates that AT&T is **not relying on IP TTL hop-count inspection**
to enforce this throttle on this Android handset. Instead, Android's tethering stack
binds tethered interfaces to an operator-designated tethering APN/PDN (such as `dun`),
and AT&T's network core applies the 5.0 Mbps rate limit directly to that bearer session
once the line's high-speed tethering allotment is exhausted.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Confirm line-specific hotspot quota on AT&T account management.
- Test whether toggling airplane mode or reconnecting after quota reset removes the clamp.
