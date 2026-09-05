---
id: 2026-09-05-oneplus-nord-n200-google-fi
date: 2026-09-05
phone:
  make: OnePlus
  model: Nord N200 5G (DE2117)
  os: "15" # ro.build.version.release over adb
carrier:
  name: Google Fi # gsm.sim.operator.alpha: Google Fi
  network: LTE # gsm.network.type read "LTE" before and after transfers
usb:
  vendor_id: "22d9"
  product_id: "908c" # NCM+ADB composite
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable: "USB-C to USB-C"
link:
  interface: enx0a36ed7a2e2e
  ipv4: 192.168.54.3/24
  gateway: 192.168.54.94
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
  single_stream_mbps: [50.590, 28.991, 50.524]
  parallel_4_aggregate_mbps: 43.624
  rtt_ms:
    min: 31.997
    avg: 41.065
    max: 55.198
    mdev: 9.483
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: usable
---

# OnePlus Nord N200 5G on Google Fi

## Setup

Measured 2026-09-05, 15:54:28–15:54:44 EDT. First record for a OnePlus handset
in this database. Connected via USB-C to USB-C in Type-C port `3-1`.

The phone enumerated as `22d9:908c` (OnePlus vendor ID `22d9`, composite NCM+ADB).
Crucially, **it binds `cdc_ncm` rather than `rndis_host`**, making it the first
non-Pixel Android phone in this log to default to NCM tethering.

Interface `enx0a36ed7a2e2e` acquired IPv4 `192.168.54.3/24` with default gateway
`192.168.54.94`, and an IPv6 prefix in `2607:fb90:62ca:a99::/64` (T-Mobile / Google Fi).
Wi-Fi remained down, and the tether interface was the sole default route.

ADB verified OnePlus model `DE2117` (Nord N200 5G), Android 15, and `LTE` on the
cellular connection both before and after transfers (`gsm.network.type: LTE`).

The bus negotiated at 480 Mbps (USB 2.0). The device's BOS descriptor includes a
SuperSpeed capability (`bcdUSB 2.10`, 5 Gbps), but without a SuperSpeed-trained
bus it operates at High-Speed. `cdc_ncm` reports a link speed of 425 Mbps with
standard NTB buffers (`rx_max`/`tx_max` 16384, `tx_timer_usecs=400`). Pre-test link
error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 50.590 / 28.991 / 50.524 Mbps (1.75x spread).
Parallel 4 streams: 12.898 / 10.966 / 10.350 / 9.410 Mbps (summed from unrounded
bytes/sec: 43.624 Mbps aggregate).

Idle RTT: 31.997 / 41.065 / 55.198 / 9.483 ms min/avg/max/mdev with 0% packet loss.

### Finding: Genuinely WAN-limited LTE connection on NCM
- Single-stream speeds hovered around ~50 Mbps (with a brief dip to 29 Mbps on run 2).
- The 4-stream parallel aggregate reached 43.624 Mbps (0.86x the best single stream).
  Per the diagnostic rubric, when single-stream and parallel aggregate are roughly
  equal, the bottleneck is genuinely the WAN cellular link, not the USB stack or
  tethering driver.
- Latency was stable at 41.1 ms average with 9.5 ms jitter.
- Zero errors and zero drops occurred across the entire pass.

## Issues

None. Clean enumeration and flawless transfer execution.

## Follow-ups

- Retest in a location with 5G Standalone (`NR_SA`) coverage to measure maximum
  `cdc_ncm` throughput on this OnePlus handset.
