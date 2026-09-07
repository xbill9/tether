---
id: 2026-09-06-iphone-16e-google-fi-cubic
date: 2026-09-06
phone:
  make: Apple
  model: iPhone 16e (iPhone17,5)   # read over usbmuxd (ideviceinfo -k ProductType)
  os: iOS 27.0                     # read over usbmuxd (ideviceinfo -k ProductVersion)
carrier:
  name: Google Fi     # operator-confirmed; corroborated by a 2607:fb90::/32 delegation
  network:            # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable:              # TODO not confirmed by the operator - port 3-1, on controller 0000:00:14.0, NOT the Thunderbolt port
link:
  interface: enx925f7a841529
  ipv4: 172.20.10.5/28
  gateway: 172.20.10.1
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: cubic
  slow_start_after_idle: 1
  mtu_probing: 0
results:
  single_stream_mbps: [25.449, 46.284, 54.240]
  parallel_4_aggregate_mbps: 79.867
  rtt_ms:
    min: 24.540
    avg: 39.181
    max: 54.696
    mdev: 10.800
  errors: 0   # RX+TX delta across the pass; all cumulative counters 0 -> 0
  drops: 0    # RX+TX delta across the pass; all cumulative counters 0 -> 0
verdict: usable
---

# iPhone 16e on Google Fi - the same phone under CUBIC

The host defaults came back. Every prior iPhone 16e record was measured with
`bbr` / `slow_start_after_idle=0` / `mtu_probing=1`; this host is now on
**`cubic`, `slow_start_after_idle=1`, `mtu_probing=0`**, and `tcp_bbr` is not
even loaded (`lsmod` shows no instance, though the module is present at
`/lib/modules/7.1.8+deb13-amd64/kernel/net/ipv4/tcp_bbr.ko.xz`). That makes this
a congestion-control re-test of the
[C-to-C retest](2026-09-05-iphone-16e-google-fi-retest.md) rather than a new
device, so it gets its own file per methodology rule 3.

## Setup

Measured 2026-09-06, 22:53 EDT. The phone was already tethered when the session
started - nothing had to be done to bring it up. It enumerated as `05ac:12a8`,
bound `ipheth`, and came up as `enx925f7a841529` on `172.20.10.5/28` with
gateway `172.20.10.1` and a Google Fi IPv6 delegation. Same interface name and
same lease as the 2026-09-05 sessions.

It sits on port `3-1`, the USB-C receptacle behind the 480 Mbps root hub on
controller `0000:00:14.0` - the same receptacle as the C-to-C retest. The
operator did not confirm which cable was in it, so `usb.cable` is left blank
rather than assumed from the port.

`ip route show default` named the tether throughout and `wlo1` was `DOWN` with
`NO-CARRIER`, so nothing else could have carried the traffic.

**480 is this device's own ceiling, not a cable fault - two independent lines of
evidence say so.**

1. *The device.* `lsusb -v` under root shows `bcdUSB 2.10` and a BOS descriptor
   with two device capabilities - USB 2.0 Extension (LPM) and Platform - and
   **no SuperSpeed USB Device Capability**. Per the README that alone makes the
   cable moot.
2. *The host receptacle.* `usb3-port1`, where the phone enumerated as `3-1`, has
   peer `usb4-port1` at the same `location=0x80000101`, and root hub `usb4`
   reports `speed=10000`. Had the phone trained SuperSpeed it would have moved
   hubs and come up as `4-1`, the way the iPhone 17 Pro did on the neighbouring
   `usb3-port3`/`usb4-port2` pair. It stayed on `3-1` at 480.

So a SuperSpeed-capable port still produced 480, which leaves the cable as the
only unexcluded variable - and the descriptor in (1) already says the device
would not use a better one. Worth stating because a sibling handset went the other way on 2026-09-06 - the
iPhone 17 Pro trained SuperSpeed at 5000 on a new USB-A to USB-C cable
([record](2026-09-06-iphone-17-pro-att-superspeed.md)). The 16e does not. One
caveat on the descriptor: it
was read while the phone was attached at 480, which is where it was measured, so
it describes the device as tested.

## Observations

Single-stream ran **25.4 / 46.3 / 54.2 Mbps** - a 2.13x spread, and a
monotonic ramp rather than noise. Parallel-4 aggregated **79.9 Mbps**, made up
of 30.1 + 17.0 + 16.5 + 16.3, so one stream took roughly double the other three.
RTT averaged 39.2 ms with `mdev` 10.8.

Against the CUBIC-vs-BBR question this is the interesting part. The same phone,
same carrier, same receptacle, one day earlier under BBR ran 91.0 / 81.6 / 87.0
single with a 167.4 Mbps aggregate and a 1.11x spread. Under CUBIC today every
one of those numbers is worse: the mean single-stream fell from 86.6 to 42.0
Mbps, the aggregate from 167.4 to 79.9, and the spread widened from 1.11x to
2.13x. RTT average is essentially unchanged (40.7 -> 39.2 ms) while `mdev`
improved slightly (13.4 -> 10.8).

Wide spread with a flat RTT average is the README's first case - congestion
control collapsing on radio loss - and the direction matches the Pixel 9a
finding exactly: CUBIC reading random radio loss as congestion and halving the
window. The aggregate being 1.9x the single-stream mean says the WAN still had
headroom that one CUBIC flow could not take.

**But the attribution is not clean, and the record should not pretend it is.**
The BBR comparison run was 2026-09-05 at 16:01 EDT; this one is 2026-09-06 at
22:53. Different day, different hour, different radio conditions, and
`carrier.network` is unobtainable on iOS, so there is no way to confirm the
handset was even on the same radio type for both. The monotonic 25 -> 46 -> 54
ramp is also not what a loss-driven CUBIC collapse usually looks like - a
collapse scatters, a ramp suggests something warming up, and three runs cannot
tell those apart. The honest reading is that this is *consistent with* the
CUBIC-on-lossy-radio case and consistent with the log's other CUBIC results, but
a one-day-apart pair with an unknown radio is corroboration, not proof.

Nothing here points at the USB bus. An aggregate of 79.9 Mbps on a 480 Mbps bus
is nowhere near the ~300 Mbps mark where the USB 2.0 ceiling shows up, and
errors and drops were zero across the pass.

## Issues

None. The pass ran clean: no interface bounce, no route change, zero errors and
zero drops on `ip -s link` across all eight transfers.

`carrier.network` is blank again for the same structural reason as every other
iOS record here - there is no adb equivalent, and a status-bar reading is not
trustworthy enough to write down.

## Follow-ups

- **Re-run under BBR back-to-back.** `tcp_bbr` is present but not loaded. Load
  it, flip `net.ipv4.tcp_congestion_control`, and re-measure within minutes
  rather than a day later. That is the only way to separate the congestion
  control from the radio conditions, and it would settle whether the 2x gap
  above is real.
- Ask the operator which cable is in port `3-1` and backfill `usb.cable`. It
  cannot change the result - the phone advertises no SuperSpeed - but the field
  should not stay blank when it is one question away.
- The monotonic ramp across the three runs is worth a second look. If it repeats
  on a re-test, three runs may not be enough for this handset.
