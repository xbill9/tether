---
id: 2026-09-05-pixel-8a-google-fi
date: 2026-09-05
phone:
  make: Google
  model: Pixel 8a
  os: "17" # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.sim.operator.alpha: Google Fi
  network: LTE # gsm.network.type read "LTE,Unknown" before and after transfers
usb:
  vendor_id: "18d1"
  product_id: "4eec" # NCM+ADB composite
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable: "USB-C to USB-C"
link:
  interface: enx8a32eb91b33b
  ipv4: 10.184.98.38/24
  gateway: 10.184.98.177
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
  single_stream_mbps: [58.372, 61.339, 67.936]
  parallel_4_aggregate_mbps: 167.951
  rtt_ms:
    min: 22.657
    avg: 28.278
    max: 38.664
    mdev: 5.769
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Google Pixel 8a on Google Fi

## Setup

Measured 2026-09-05, 16:44:52–16:45:02 EDT. First test of a Google Pixel 8a
(`akita_beta`) in this database. Connected via USB-C to USB-C in port `3-1`.

The phone enumerated as `18d1:4eec` (Google NCM+ADB composite), binding `cdc_ncm`
on interface `enx8a32eb91b33b` with IPv4 `10.184.98.38/24`, gateway `10.184.98.177`,
and a global IPv6 prefix in `2607:fb91:ec5:5c1::/64` (T-Mobile / Google Fi).
Wi-Fi remained down, and the tether interface was the sole default route.

ADB verified model `Pixel 8a`, Android 17, and active radio on LTE
(`gsm.network.type: LTE,Unknown`) both before and after transfers.

Bus speed was 480 Mbps (USB 2.0). Link speed was 425 Mbps with standard NTB
parameters (`rx_max`/`tx_max` 16384, `tx_timer_usecs=400`). Pre-test link error
and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 58.372 / 61.339 / 67.936 Mbps (tight 1.16x spread).
Parallel 4 streams: 48.916 / 47.761 / 39.790 / 31.484 Mbps (summed from unrounded
bytes/sec: 167.951 Mbps aggregate, 2.47x best single stream).

Idle RTT: 22.657 / 28.278 / 38.664 / 5.769 ms min/avg/max/mdev with 0% packet loss.

### Finding: Pixel 8a delivers strong unthrottled LTE performance
- Even connected on LTE rather than 5G Standalone, this Pixel 8a achieved
  **168 Mbps multi-stream aggregate** and ~68 Mbps single stream.
- Latency was low and consistent: 28.3 ms average with only 5.8 ms jitter.
- This Google Fi account is fully unthrottled with active high-speed mobile hotspot
  allowance.
- Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Test on the USB-A cable for direct comparison against the Type-C results.
- Retest under 5G Standalone (`NR_SA`) coverage.
