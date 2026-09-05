---
id: 2026-09-05-galaxy-z-flip5-google-fi-usba
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
  cable: "USB-A to USB-C" # operator switched to USB-A port
link:
  interface: enx1ae9077d21c1
  ipv4: 10.187.171.105/24
  gateway: 10.187.171.225
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [60.606, 65.202, 65.445]
  parallel_4_aggregate_mbps: 89.964
  rtt_ms:
    min: 24.947
    avg: 32.890
    max: 43.944
    mdev: 7.198
  errors: 1 # RX+TX delta across transfers and ping; cumulative RX 0 -> 1, TX 0 -> 0
  drops: 0 # RX+TX delta; all cumulative drop counters remained zero
verdict: usable
---

# Samsung Galaxy Z Flip5 on Google Fi — USB-A port

## Setup

Measured 2026-09-05, 15:15:03–15:15:15 EDT. This fourth session for the Flip5
follows switching the handset from the USB-C port (`3-1`) to the host's USB-A
port (`3-3`) using a USB-A to USB-C cable.

The handset re-enumerated on `3-3` as `04e8:6864` (`rndis_adb`), bringing up
new network interface `enx1ae9077d21c1` on `10.187.171.105/24` with default
gateway `10.187.171.225`. Wi-Fi (`wlo1`) remained down, and `enx1ae9077d21c1`
was the sole active default route.

ADB verified Samsung SM-F731U1, Android 16, Google Fi, and active network
`NR_SA` both before and immediately after transfers
(`gsm.network.type: NR_SA,Unknown`).

The USB bus enumerated at 480 Mbps (USB 2.0). Complete privileged USB descriptors
advertised SuperSpeed capability (5 Gbps). Driver is `rndis_host`
(`/sys/class/net/enx1ae9077d21c1/speed` returns -1; NTB block omitted). Pre-test
link error and drop counters were clean at 0.

## Observations

Three sequential single-stream downloads and four concurrent downloads used
`https://speed.cloudflare.com/__down?bytes=8000000`. All transfers completed
with HTTP 200, exit code 0, and 8,000,000 bytes transferred.

Single-stream speeds: 60.606 / 65.202 / 65.445 Mbps (1.08x spread, tightly clustered).
Parallel 4-stream individual speeds: 28.171 / 13.192 / 27.850 / 20.752 Mbps
(summed from unrounded bytes/sec: 89.964 Mbps).

The parallel aggregate of 89.964 Mbps is 1.37x the best single stream (65.445 Mbps).
Compared to earlier Type-C sessions on port `3-1` (which reached ~90 Mbps single
and 221–237 Mbps aggregate), throughput was noticeably lower across both single
and multi-stream runs, while idle RTT latency remained steady at 32.890 ms average
and 7.198 ms mdev.

## Issues

Pre-test RX errors were 0; post-test RX errors were 1 (delta: 1). TX errors and
all drop counters remained at 0. No transfers failed or dropped.

## Follow-ups

- Test with a known USB 3.0 flash drive directly in port `3-3` to confirm the host
  port's SuperSpeed peer (`usb4-port2`).
- Compare another device over this same USB-A to USB-C cable to see if the
  throughput ceiling is cable-specific or port/controller-related.
