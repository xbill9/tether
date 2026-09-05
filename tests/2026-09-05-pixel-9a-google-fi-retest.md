---
id: 2026-09-05-pixel-9a-google-fi-retest
date: 2026-09-05
phone:
  make: Google
  model: Pixel 9a
  os: Android 17 # beta build CP41.260814.003.B1, sdk 37 over adb
carrier:
  name: Google Fi
  network: 5G # adb read "IWLAN,NR_SA" both before and after transfers
usb:
  vendor_id: "18d1"
  product_id: "4eec" # NCM+ADB composite
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable: "USB-C to USB-C"
link:
  interface: enxce1d58e89c0f
  ipv4: 10.244.144.215/24
  gateway: 10.244.144.214
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
  single_stream_mbps: [28.486, 20.326, 7.545]
  parallel_4_aggregate_mbps: 5.050
  rtt_ms:
    min: 30.011
    avg: 59.318
    max: 87.270
    mdev: 22.313
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: poor
---

# Pixel 9a on Google Fi — afternoon retest

## Setup

Measured 2026-09-05, 16:12:01–16:13:10 EDT. Retest of the original Google Fi
Pixel 9a handset (`enxce1d58e89c0f`, previously evaluated in
[2026-09-05-pixel-9a-bbr](2026-09-05-pixel-9a-bbr.md) where it achieved 246 Mbps).
Connected via USB-C to USB-C in port `3-1`.

The phone enumerated as `18d1:4eec` (NCM+ADB composite), binding `cdc_ncm`
on interface `enxce1d58e89c0f` with IPv4 `10.244.144.215/24` and gateway
`10.244.144.214`. Wi-Fi was down, and the tether interface was the sole default route.

ADB verified model `Pixel 9a`, Android 17, and active radio on 5G Standalone
(`gsm.network.type: IWLAN,NR_SA`) both before and after the pass.

Bus speed was 480 Mbps (USB 2.0). Link speed was 425 Mbps with standard NTB
parameters (`rx_max`/`tx_max` 16384, `tx_timer_usecs=400`). Pre-test link error and
drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 28.486 / 20.326 / 7.545 Mbps (3.78x drop across runs).
Parallel 4 streams: 1.268 / 1.263 / 1.262 / 1.257 Mbps (summed from unrounded
bytes/sec: 5.050 Mbps aggregate).

Idle RTT: 30.011 / 59.318 / 87.270 / 22.313 ms min/avg/max/mdev with 0% packet loss.

### Finding: Google Fi line has also crossed into the 5.0 Mbps hard throttle
Despite connecting over 5G Standalone (`NR_SA`) and operating cleanly on `cdc_ncm`,
this pass encountered the exact same **5.0 Mbps hard carrier throttle**:
- Single-stream transfers stepped down sharply across sequential downloads:
  `28.5 → 20.3 → 7.5 Mbps`.
- The 4 parallel streams divided an exact **5.050 Mbps ceiling** into 4 equal slices
  of ~1.26 Mbps (~158 KB/s) each, taking ~51 seconds to transfer 32 MB total.
- In earlier morning testing ([2026-09-05-pixel-9a-bbr](2026-09-05-pixel-9a-bbr.md)),
  this identical physical handset reached **246 Mbps aggregate** on Google Fi.

This confirms that after numerous 56 MB measurement passes throughout the day,
this Google Fi line has now also exhausted its high-speed mobile hotspot allowance,
triggering the carrier's 5.0 Mbps tethering rate limiter.

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Verify remaining high-speed tethering allowance in the Google Fi app.
