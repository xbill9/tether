---
id: 2026-09-05-galaxy-z-flip5-google-fi-retest2
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy Z Flip5 (SM-F731U1) # model code read via adb; marketing name from earlier record
  os: Android 16 # read via adb
carrier:
  name: Google Fi # operator-confirmed 2026-09-05; also reported by SIM and network properties
  network: 5G (NR SA) # active slot NR_SA before and after; other slot Unknown
usb:
  vendor_id: "04e8"
  product_id: "6864"
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # TODO RNDIS reports -1, no negotiated link rate available
  cable: # TODO operator reports cable identity unknown (2026-09-05)
link:
  interface: enxde5b627dd64d
  ipv4: 10.187.171.59/24
  gateway: 10.187.171.225
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [90.159, 79.699, 81.291]
  parallel_4_aggregate_mbps: 221.204
  rtt_ms:
    min: 28.305
    avg: 40.975
    max: 54.696
    mdev: 10.895
  errors: 0 # RX+TX delta across transfers and ping; cumulative RX 72 -> 72, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: good
---

# Samsung Galaxy Z Flip5 on Google Fi — second afternoon retest

## Setup

Measured 2026-09-05, 15:12:37–15:12:46 EDT. This third session follows the
[initial Flip5 pass](2026-09-05-galaxy-z-flip5-google-fi.md) and [afternoon retest](2026-09-05-galaxy-z-flip5-google-fi-retest.md)
on the same handset and cable.

ADB reported Samsung SM-F731U1, Android 16, and Google Fi on both operator
properties. The active SIM slot reported `NR_SA` before and after the
transfers (`gsm.network.type: NR_SA,Unknown`).

USB configuration remained `rndis_adb`, 04e8:6864 on port 3-1 at 480 Mbps (USB 2.0).
Privileged USB descriptors advertised SuperSpeed capability (5 Gbps), though
the bus operates at 480 Mbps. Driver is `rndis_host`
(`/sys/class/net/enxde5b627dd64d/speed` reports -1; NTB block omitted).

Pre-test link stats showed cumulative RX errors at 72 (from prior sessions and
background traffic) and TX errors at 0, with 0 drops. Interface `enxde5b627dd64d`
held the sole default route; Wi-Fi remained down. All downloads and ping resolved
to Cloudflare via IPv6 (`2606:4700:7::da`).

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers
completed with HTTP 200, curl exit 0, and exactly 8,000,000 bytes transferred.

Single-stream speeds: 90.159 / 79.699 / 81.291 Mbps (spread: 1.13x, tightly clustered).
Parallel 4-stream individual speeds: 86.106 / 73.089 / 31.597 / 30.412 Mbps
(summed from unrounded bytes/sec: 221.204 Mbps).

The aggregate throughput of 221.204 Mbps is 2.45x the best single-stream run
(90.159 Mbps), with single-stream speeds staying tightly bounded around
80–90 Mbps. Per the diagnostic rubric, this flat spread paired with parallel
aggregate far exceeding single-stream throughput indicates a per-flow limit
(carrier shaping or BDP constraint per flow), rather than a congestion collapse
or WAN ceiling.

Post-transfer idle ping to `speed.cloudflare.com`:
28.305 / 40.975 / 54.696 / 10.895 ms min/avg/max/mdev with 0% packet loss.

Throughput rebounded significantly from the prior retest (139.815 Mbps aggregate),
returning close to the initial baseline (237 Mbps aggregate), with zero error delta.

## Issues

None during this pass. Pre-test RX errors were 72; post-test RX errors remained 72
(delta: 0). TX errors and all drop counters remained zero throughout. No retries or
dropped connections.

## Follow-ups

- Test single stream with an enlarged socket buffer to isolate whether the per-flow
  cap (~80–90 Mbps) is carrier-enforced shaping or host/radio BDP scaling.
- Confirm USB 3 operation with a known SuperSpeed cable or direct USB 3 flash drive
  to verify host port capability.
