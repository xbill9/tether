---
id: 2026-09-05-pixel-9a-cubic
date: 2026-09-05
phone:
  make: Google
  model: Pixel 9a
  os:                 # TODO not recorded at test time
carrier:
  name:               # TODO not recorded at test time
  network:            # TODO not recorded at test time
usb:
  vendor_id: "18d1"
  product_id: "4eeb"
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable:              # TODO unverified - enumerated at USB 2.0
link:
  interface: enxce1d58e89c0f
  ipv4: 10.244.144.215/24
  gateway: 10.244.144.214
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
  congestion_control: cubic
  slow_start_after_idle: 1
  mtu_probing: 0
results:
  single_stream_mbps: [15, 44, 116]
  parallel_4_aggregate_mbps: 211
  rtt_ms:
    min: 24.3
    avg: 29.6
    max: 36.0
    mdev: 4.1
  errors: 0
  drops: 0
verdict: poor
---

# Pixel 9a - baseline (CUBIC, as shipped)

Baseline before any tuning. Superseded by
[2026-09-05-pixel-9a-bbr](2026-09-05-pixel-9a-bbr.md); kept because the
congestion control differs, per rule 3 in the README.

## Setup

Already connected and working on arrival - NetworkManager had DHCPed it via the
generic `Wired connection 1` profile, which is bound to neither a MAC nor an
interface name and so adopts any wired device. Bound to `cdc_ncm`, not RNDIS.

## Observations

Three identical 8 MB transfers returned 15, 44 and 116 Mbps - a 7.8x spread -
while RTT stayed flat at 24-36 ms with 4.1 ms mdev. A stable path with
collapsing single-flow throughput is CUBIC reading random radio loss as
congestion and halving the window.

Four concurrent streams reached 211 Mbps aggregate. That is the measurement that
mattered: it proved the WAN had headroom and the bottleneck was local, not the
carrier. An earlier one-off 10 MB transfer hit 133 Mbps, which is consistent with
the wide spread rather than contradicting it.

Zero errors and zero drops across 9377 RX / 4111 TX packets, so the cable and
power delivery were not implicated.

## Issues

The NTB aggregation buffers are already at the device-advertised ceiling
(`rx_max`/`tx_max` 16384 = `dwNtbInMaxSize`/`dwNtbOutMaxSize`), so the widely
repeated advice to raise them to 32768 is a no-op on this phone. `mtu_max` is
1500, so no jumbo frames either.

## Follow-ups

Phone enumerated on a USB 2.0 bus (480 Mbps) despite the host having a 3.0 root
hub on bus 004 - almost certainly a USB 2.0 or charge-only cable. Untested.
