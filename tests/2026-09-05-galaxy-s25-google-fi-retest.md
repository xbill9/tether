---
id: 2026-09-05-galaxy-s25-google-fi-retest
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy S25 (SM-S931U1)
  os: Android 16 # read over adb
carrier:
  name: Google Fi
  network: 5G # adb read "Unknown,NR_SA" both before and after transfers
usb:
  vendor_id: "04e8"
  product_id: "6864"
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # rndis_host does not report link speed (/sys speed returns -1)
  cable: "USB-C to USB-C"
link:
  interface: enx9e10cb00f345
  ipv4: 10.223.144.177/24
  gateway: 10.223.144.14
  ipv6: false # no global IPv6 assigned in this session
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [30.409, 20.381, 5.787]
  parallel_4_aggregate_mbps: 5.050
  rtt_ms:
    min: 31.853
    avg: 44.712
    max: 53.912
    mdev: 7.364
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: poor
---

# Samsung Galaxy S25 on Google Fi — afternoon retest

## Setup

Measured 2026-09-05, 16:16:05–16:17:16 EDT. Retest of the Samsung Galaxy S25
([initial test](2026-09-05-galaxy-s25-google-fi.md), where it achieved 224 Mbps),
connected via USB-C to USB-C in port `3-1`.

The phone enumerated as `04e8:6864` (Samsung composite RNDIS+ADB), binding `rndis_host`
on interface `enx9e10cb00f345` with IPv4 `10.223.144.177/24` and gateway
`10.223.144.14`. Wi-Fi remained down, and the tether interface was the sole default route.

ADB verified model `SM-S931U1` (Galaxy S25), Android 16, and active radio on 5G
Standalone (`gsm.network.type: Unknown,NR_SA`) before and after transfers.

Bus speed was 480 Mbps (USB 2.0). Pre-test link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 30.409 / 20.381 / 5.787 Mbps (5.25x drop across runs).
Parallel 4 streams: 1.268 / 1.263 / 1.260 / 1.258 Mbps (summed from unrounded
bytes/sec: 5.050 Mbps aggregate).

Idle RTT: 31.853 / 44.712 / 53.912 / 7.364 ms min/avg/max/mdev with 0% packet loss.

### Finding: S25 encounters the same 5.0 Mbps hard carrier throttle
In the morning baseline, this Galaxy S25 achieved **224 Mbps aggregate** on Google Fi.
In this afternoon pass:
- Sequential single-stream transfers dropped from 30.4 to 20.4 to 5.8 Mbps.
- The 4 concurrent transfers divided a rigid **5.050 Mbps ceiling** into equal slices
  of ~1.26 Mbps (~158 KB/s) each, taking ~51 seconds to transfer 32 MB total.
- Latency remained exceptionally flat and clean (44.7 ms avg with only 7.4 ms jitter).
- Link error and drop counters showed zero increment.

This demonstrates that this Google Fi handset has entered the carrier's
5.0 Mbps tethering throttle state, matching the behavior observed on the Pixel 9a
and Motorola razr plus 2023.

**The operator confirmed immediately following the pass that these devices are on
separate accounts**, ruling out a shared group plan pool or aggregated quota exhaustion.
This leaves two primary diagnostic hypotheses:
1. **Independent quota exhaustion**: Multiple separate lines independently reached
   their individual high-speed hotspot limits during today's extensive testing passes
   (each 7-stream benchmark consumes ~56 MB of metered cellular data).
2. **Account-tier or handset policy differences**: Other devices on Google Fi tested
   during the same timeframe did not exhibit this clamp: the OnePlus Nord N200 5G
   reached 43.6 Mbps (on `cdc_ncm`), and the iPhone 16e reached 167.4 Mbps (on `ipheth`).
   The 5.0 Mbps ceiling appears tied to specific line provisioning or per-line hotspot limits.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Check the Google Fi app for this specific account to verify line-level hotspot data
  usage and the exact policy threshold triggering the 5.0 Mbps rate limit.
