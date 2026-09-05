---
id: 2026-09-05-motorola-razr-plus-2024-google-fi
date: 2026-09-05
phone:
  make: Motorola
  model: razr plus 2024
  os: "15" # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.operator.alpha and gsm.sim.operator.alpha both "Google Fi"
  network: LTE # gsm.network.type reported "LTE,Unknown" before and after
usb:
  vendor_id: "22b8"
  product_id: "2e25" # RNDIS+ADB composite
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # TODO rndis_host does not report one - /sys/class/net/<if>/speed returns -1
  cable: "USB-C to USB-C"
link:
  interface: enx2efcb154f488
  ipv4: 10.96.111.171/24
  gateway: 10.96.111.244
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [31.572, 35.289, 33.110]
  parallel_4_aggregate_mbps: 40.589
  rtt_ms:
    min: 33.715
    avg: 49.735
    max: 90.359
    mdev: 20.994
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: usable
---

# Motorola razr plus 2024 on Google Fi

## Setup

Measured 2026-09-05, 15:25:36–15:25:54 EDT. First record for this handset model
(`arcfox_gu`). Attached via USB-C to USB-C cable in Type-C port `3-1`.

The handset enumerated as `22b8:2e25` (RNDIS+ADB composite), bringing up
interface `enx2efcb154f488` on `10.96.111.171/24` with default gateway `10.96.111.244`
and IPv6 prefix `2607:fb91:ec5:1d8::/64`. Wi-Fi (`wlo1`) remained down, and the
tether was the sole active default route.

ADB verified `motorola razr plus 2024`, Android 15, and `LTE` on the active
slot before and after transfers (`gsm.network.type: LTE,Unknown`).

USB bus speed is 480 Mbps (USB 2.0). Descriptors read `bcdUSB 2.00` with no
SuperSpeed capability advertised (device ceiling is 480 Mbps). Driver is
`rndis_host` (`/sys/class/net/enx2efcb154f488/speed` returns -1; NTB block omitted).
Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 31.572 / 35.289 / 33.110 Mbps (1.12x spread).
Parallel 4 streams: 12.119 / 10.559 / 9.099 / 8.812 Mbps (summed from unrounded
bytes/sec: 40.589 Mbps aggregate).

The parallel aggregate (40.589 Mbps) is only 1.15x the best single stream
(35.289 Mbps). Per the diagnostic rubric, this matches case 2: single ≈ parallel
aggregate, indicating a genuinely WAN-limited link on this LTE connection. Unlike
the 5G Standalone runs on Google Fi which reached 220+ Mbps aggregate, this handset
connected over LTE, exhibiting typical LTE throughput and latency (49.735 ms avg,
20.994 ms mdev).

Link counters recorded zero errors and zero drops throughout the entire pass.

## Issues

None at the USB or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Retest when connected to 5G Standalone (`NR_SA`) to benchmark full cellular capacity
  against the razr 2024 and razr plus 2023.
