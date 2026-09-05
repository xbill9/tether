---
id: 2026-09-05-galaxy-z-flip4-google-fi
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy Z Flip4 (SM-F721U1)
  os: Android 16 # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.sim.operator.alpha: Google Fi
  network: LTE # gsm.network.type read "LTE,Unknown" before and after transfers
usb:
  vendor_id: "04e8"
  product_id: "6864" # composite RNDIS+ADB
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # rndis_host does not report link speed
  cable: "USB-C to USB-C"
link:
  interface: enx5e1a2d7d783e
  ipv4: 172.30.32.216/24
  gateway: 172.30.32.164
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [38.540, 33.193, 33.373]
  parallel_4_aggregate_mbps: 71.336
  rtt_ms:
    min: 18.196
    avg: 28.202
    max: 52.341
    mdev: 12.476
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Samsung Galaxy Z Flip4 on Google Fi

## Setup

Measured 2026-09-05, 16:50:30–16:50:45 EDT. First test of the Samsung Galaxy Z Flip4
(`SM-F721U1`, completing the Flip4, Flip5, and Flip6 generation lineup in this
database), connected via USB-C to USB-C in port `3-1`.

The phone enumerated as `04e8:6864` (Samsung composite RNDIS+ADB), binding `rndis_host`
on interface `enx5e1a2d7d783e` with IPv4 `172.30.32.216/24`, gateway `172.30.32.164`,
and a global IPv6 prefix in `2607:fb91:ec9:195::/64` (T-Mobile / Google Fi).
Wi-Fi remained down, and the tether interface was the sole default route.

ADB verified model `SM-F721U1` (Galaxy Z Flip4), Android 16, and active radio on LTE
(`gsm.network.type: LTE,Unknown`) both before and after transfers.

Bus speed was 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 38.540 / 33.193 / 33.373 Mbps (tight 1.16x spread).
Parallel 4 streams: 30.379 / 14.130 / 13.777 / 13.051 Mbps (summed from unrounded
bytes/sec: 71.336 Mbps aggregate, 1.85x best single stream).

Idle RTT: 18.196 / 28.202 / 52.341 / 12.476 ms min/avg/max/mdev with 0% packet loss.

### Finding: Galaxy Z Flip4 operates unthrottled on LTE
- Reached **71.336 Mbps multi-stream aggregate** and ~38.5 Mbps single stream on LTE.
- Idle RTT dropped as low as 18.2 ms with an average of 28.2 ms, demonstrating low
  cellular buffer latency on this path.
- This line has active unthrottled tethering quota, unlike the devices that hit
  the 5.0 Mbps carrier limit.
- Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Test with the USB-A cable for direct comparison against the Type-C results.
- Retest under 5G Standalone (`NR_SA`) coverage to compare directly with Flip5 and Flip6.
