---
id: 2026-09-05-galaxy-z-flip5-google-fi-retest
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
  single_stream_mbps: [89.729, 97.096, 90.771]
  parallel_4_aggregate_mbps: 139.815
  rtt_ms:
    min: 24.237
    avg: 33.842
    max: 45.263
    mdev: 8.768
  errors: 1 # RX+TX delta across transfers and subsequent ping; cumulative RX 56 -> 57, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: usable
---

# Samsung Galaxy Z Flip5 on Google Fi — afternoon retest

## Setup

Measured 2026-09-05, 15:06:35–15:06:44 EDT. This is a new session following
the [earlier Flip5 pass](2026-09-05-galaxy-z-flip5-google-fi.md), with a fresh
error-counter baseline. No configuration changes were made for this pass;
cable continuity with the earlier session is unverified.

ADB reported Samsung SM-F731U1, Android 16, and Google Fi from both operator
properties. The marketing name follows the earlier record's model mapping;
operator confirmation of the marketing name is pending. Metadata update on
2026-09-05 after the pass: the operator confirmed Google Fi and stated that
the cable is unknown. No measurements changed. The active
data subscription was 6, with the first slot connected on NR_SA and the second
out of service. `gsm.network.type` was `NR_SA,Unknown` immediately before and
after the transfers. These endpoint readings do not exclude a transient change
during a transfer.

USB debugging was already authorized. The measured configuration was
`rndis_adb`, 04e8:6864 on port 3-1, at 480 Mbps (USB 2.0). Complete privileged
USB descriptors advertised SuperSpeed at 5 Gbps. The lower negotiated speed
does not establish whether the cable, port, or another factor limited it.
RNDIS reported link speed -1, so that field is unknown; NCM fields do not apply.

The tether was the sole usable default route, Wi-Fi was down, and docker0 had
no carrier. The route and interface were checked after metadata collection;
curl and ping were explicitly bound to the tether interface. All transfers
used IPv6 to `2606:4700:7::da`, with a local IPv6 address on that interface.
The default route remained on the tether afterward.

## Observations

Three sequential downloads and four concurrent downloads used exactly
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven returned HTTP
200, curl exit status 0, and exactly 8,000,000 bytes. Speeds were converted
from bytes/second using multiplication by 8 / 1e6.

Single-stream results were 89.729 / 97.096 / 90.771 Mbps, a 1.08x spread.
Parallel streams delivered 33.895 / 27.152 / 39.693 / 39.075 Mbps, summed
from unrounded values to 139.815 Mbps, 1.44x the best single stream. There is
some aggregate headroom, but this modest difference does not establish carrier
shaping, a congestion-control problem, or a USB ceiling.

The five-packet ping ran after downloads, idle relative to this benchmark:
24.237 / 33.842 / 45.263 / 8.768 ms min/avg/max/mdev, with no packet loss.
No latency-under-load measurement was taken, so bufferbloat is undetermined.

Compared with the earlier record's 99 / 111 / 112 Mbps and 237 Mbps aggregate,
throughput was lower, while RTT average and mdev were also lower than its
42.0 and 12.1 ms. This uncontrolled session comparison does not isolate a cause.
The usable verdict reflects successful throughput with an unexplained RX error.

## Issues

Cumulative RX errors were 55 during metadata collection, 56 immediately before
the pass, and 57 after downloads and ping. TX errors and all drop counters were
zero before and after. The recorded error result is the measured delta of one,
not the cumulative total. Background traffic could contribute to this window;
the counter alone does not identify a cable, power, radio, or driver fault.
No download failed or was retried.

## Follow-ups

- Confirm the marketing name; cable identity remains unknown to the operator.
- Investigate continuing RX errors with driver diagnostics and controlled
  cable/port comparisons; this pass establishes a delta but not a cause.
- Use a verified SuperSpeed device or cable to investigate USB negotiation.
- Repeat at another time to assess the lower aggregate; measure latency under
  load separately if interactive performance is the concern.
