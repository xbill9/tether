---
id: 2026-09-05-motorola-razr-plus-2023-google-fi-retest
date: 2026-09-05
phone:
  make: Motorola
  model: razr plus 2023
  os: "15" # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.operator.alpha and gsm.sim.operator.alpha both "Google Fi"
  network: NR_SA # 5G standalone - read before and after the pass, both agree
usb:
  vendor_id: "22b8"
  product_id: "2e25" # RNDIS+ADB composite - adb enabled throughout
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps: # TODO rndis_host does not report one - /sys/class/net/<if>/speed returns -1
  cable: "USB-C to USB-C" # back to C-to-C cable on port 3-1
link:
  interface: enx1e60a938c4ab
  ipv4: 172.23.152.206/24
  gateway: 172.23.152.59
  ipv6: false # no global IPv6 assigned on this interface session
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [24.737, 20.279, 5.336]
  parallel_4_aggregate_mbps: 4.985
  rtt_ms:
    min: 27.331
    avg: 32.893
    max: 45.483
    mdev: 6.519
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: poor
---

# Motorola razr plus 2023 on Google Fi — afternoon retest

## Setup

Measured 2026-09-05, 15:20:43–15:21:57 EDT. Second test for this handset today,
returning to a USB-C to USB-C cable in Type-C port `3-1` following the
[initial session](2026-09-05-motorola-razr-plus-2023-google-fi.md).

Handset enumerated as `22b8:2e25` (RNDIS+ADB composite), bringing up interface
`enx1e60a938c4ab` on `172.23.152.206/24` with default route via `172.23.152.59`.
Unlike the earlier session which carried IPv6, this DHCP lease acquired only
an IPv4 address and link-local IPv6, so transfers and ping resolved over IPv4
to Cloudflare (`162.159.140.220`).

Wi-Fi (`wlo1`) remained down. ADB verified `motorola razr plus 2023`, Android 15,
and active radio `NR_SA` both before and immediately after transfers
(`gsm.network.type: NR_SA,Unknown`).

Bus speed is 480 Mbps (USB 2.0). Descriptors read `bcdUSB 2.01` with no SuperSpeed
capability advertised (device ceiling is 480 Mbps). Driver is `rndis_host`
(`/sys/class/net/enx1e60a938c4ab/speed` returns -1; NTB block omitted). Pre-test
error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 24.737 / 20.279 / 5.336 Mbps (4.64x degradation over the three runs).
Parallel 4 streams: 1.250 / 1.244 / 1.247 / 1.245 Mbps (summed from unrounded
bytes/sec: 4.985 Mbps aggregate).

The four concurrent streams divided a 5.0 Mbps ceiling almost perfectly equally
(~156 KB/s each), and single-stream run 3 stepped down to 5.336 Mbps. Meanwhile,
idle RTT latency remained excellent (27.331 / 32.893 / 45.483 / 6.519 ms min/avg/max/mdev)
with 0% packet loss, and link counters recorded zero errors and zero drops.

This shape—collapsing to an exact 5 Mbps envelope while latency and packet loss
remain pristine—points to a carrier-enforced throttle (e.g. hotspot limit or
tier cap on Google Fi) kicking in during the test, rather than a physical USB or
congestion-control failure. Compared to the 221 Mbps aggregate observed earlier
today, throughput was curtailed by ~97%.

## Issues

None at the USB or link layer: RX errors 0 → 0, TX errors 0 → 0, and 0 drops.
The 4 concurrent transfers took ~51 seconds to complete against the 5 Mbps cap.

## Follow-ups

- Check data quota or hotspot allocation for this SIM on Google Fi.
- Re-test once quota/throttle resets to confirm return to baseline throughput.
