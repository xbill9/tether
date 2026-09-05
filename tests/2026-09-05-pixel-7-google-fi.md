---
id: 2026-09-05-pixel-7-google-fi
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
  cable: "USB-C to USB-C"
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
  single_stream_mbps: [69.700, 67.228, 76.984]
  parallel_4_aggregate_mbps: 112.040
  rtt_ms:
    min: 33.652
    avg: 122.243
    max: 202.732
    mdev: 59.648
  errors: 0 # RX+TX delta across pass; cumulative RX remained at 3 (from initial enum), TX 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Google Pixel 7 on Google Fi

## Setup

Measured 2026-09-05, 16:21:01–16:21:11 EDT. First test of a Google Pixel 7 in this
database. Connected via USB-C to USB-C in Type-C port `3-1`.

The phone enumerated as `18d1:4eeb` (Google tether-only NCM mode without ADB).
Device manufacturer and product name (`Google / Pixel 7`) were confirmed directly
from USB sysfs descriptors. Interface `enx9a5ef5a97bd5` bound `cdc_ncm`, acquiring
IPv4 `10.233.0.230/24` with default gateway `10.233.0.13`, and a global IPv6 prefix
in `2607:fb90:62c0:9e19::/64` (T-Mobile / Google Fi). Wi-Fi was down, and the tether
interface was the sole default route.

Bus speed was 480 Mbps (USB 2.0). The device's BOS descriptor confirms SuperSpeed
capability (`bcdUSB 2.10`, 5 Gbps). `cdc_ncm` reported a link speed of 425 Mbps with
standard NTB buffers (`rx_max`/`tx_max` 16384, `tx_timer_usecs=400`). Link counters
showed 3 cumulative RX errors from pre-test USB enumeration and DHCP initialization;
TX errors and drops were 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 69.700 / 67.228 / 76.984 Mbps (tight 1.15x spread).
Parallel 4 streams: 31.137 / 28.717 / 26.585 / 25.601 Mbps (summed from unrounded
bytes/sec: 112.040 Mbps aggregate, 1.46x best single stream).

Idle RTT: 33.652 / 122.243 / 202.732 / 59.648 ms min/avg/max/mdev with 0% packet loss.

### Finding: Pixel 7 is fully unthrottled on Google Fi
Unlike the earlier afternoon tests on the Pixel 9a, Galaxy S25, and razr plus 2023,
which all encountered a hard 5.0 Mbps carrier hotspot throttle:
- This Pixel 7 operated completely unconstrained by carrier throttling.
- Sequential single-stream transfers delivered steady 67–77 Mbps.
- The 4-stream parallel aggregate reached **112.040 Mbps**, with each flow exceeding
  25 Mbps.
- This confirms this specific Google Fi line/account has active high-speed tethering quota.
- Cumulative RX error count remained flat at 3 throughout all 7 transfers (0 error delta,
  0 drop delta).

## Issues

None. Clean execution with robust throughput.

## Follow-ups

- Enable USB debugging on the handset to query exact Android OS build and cellular
  radio access technology (`NR_SA` vs `LTE`).
