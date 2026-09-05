---
id: 2026-09-05-oneplus-nord-n200-google-fi-usba
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
  cable: "USB-A to USB-C" # tested on USB-A port 3-3
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
  single_stream_mbps: [20.084, 17.822, 17.861]
  parallel_4_aggregate_mbps: 24.331
  rtt_ms:
    min: 46.504
    avg: 69.908
    max: 134.814
    mdev: 33.077
  errors: 0 # RX+TX delta across pass; cumulative RX 0 -> 0, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: usable
---

# OnePlus Nord N200 5G on Google Fi — USB-A test

## Setup

Measured 2026-09-05, 15:58:09–15:58:34 EDT. Second session for the OnePlus Nord N200 5G
(`DE2117`), switched from the USB-C port (`3-1`) to the USB-A port (`3-3`) via the
USB-A to USB-C cable for direct back-to-back comparison with the
[C-to-C test](2026-09-05-oneplus-nord-n200-google-fi.md) run four minutes earlier.

The phone bound `cdc_ncm` on interface `enx0a36ed7a2e2e` with IPv4 `192.168.54.3/24`,
gateway `192.168.54.94`, and an IPv6 prefix in `2607:fb90:62ca:a99::/64`. Wi-Fi
remained down, and the tether was the sole default route.

ADB verified model `DE2117`, Android 15, and active radio `LTE` before and after
transfers (`gsm.network.type: LTE`).

Bus speed was 480 Mbps (USB 2.0). Link speed was 425 Mbps with standard NTB
parameters (`rx_max`/`tx_max` 16384, `tx_timer_usecs=400`). Pre-test link error and
drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All seven transfers completed
with HTTP 200, exit code 0, and exactly 8,000,000 bytes.

Single-stream speeds: 20.084 / 17.822 / 17.861 Mbps (1.13x spread).
Parallel 4 streams: 6.392 / 6.343 / 5.839 / 5.757 Mbps (summed from unrounded
bytes/sec: 24.331 Mbps aggregate).

Idle RTT: 46.504 / 69.908 / 134.814 / 33.077 ms min/avg/max/mdev with 0% packet loss.

### Back-to-back cable comparison on OnePlus Nord N200
Comparing this USB-A pass directly against the C-to-C pass run 4 minutes earlier:
- **Single-stream**: 17.8–20.1 Mbps on USB-A vs **29.0–50.6 Mbps on C-to-C**
- **Par-4 Aggregate**: 24.331 Mbps on USB-A vs **43.624 Mbps on C-to-C** (+79% faster on C-to-C)
- **RTT**: 69.9 ms (33.1 ms mdev) on USB-A vs **41.1 ms (9.5 ms mdev) on C-to-C**

Across all three handsets evaluated back-to-back across cables today:
1. **Galaxy Z Flip5**: 221.2 Mbps (C-to-C) vs 90.0 Mbps (USB-A) (+146% on C-to-C)
2. **iPhone 17 Pro**: 185.5 Mbps (C-to-C) vs 153.7 Mbps (USB-A) (+21% on C-to-C)
3. **OnePlus Nord N200**: 43.6 Mbps (C-to-C) vs 24.3 Mbps (USB-A) (+79% on C-to-C)

In every case, the Type-C connection delivered superior throughput.

Link counters remained completely clean with zero errors and zero drops.

## Issues

None at the physical or link layer (0 error delta, 0 drop delta).

## Follow-ups

- Retest both cable paths under 5G Standalone (`NR_SA`) coverage.
