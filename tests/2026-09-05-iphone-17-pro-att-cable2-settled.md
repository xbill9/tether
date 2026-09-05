---
id: 2026-09-05-iphone-17-pro-att-cable2-settled
date: 2026-09-05
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)
  os: iOS 27.0        # build 24A5430a, read over usbmuxd (ideviceinfo)
carrier:
  name: AT&T          # operator-supplied; corroborated by a 2600:381::/32 delegation
  network:            # TODO not obtainable - iOS exposes no equivalent of gsm.network.type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "USB-C to USB-C, second cable - SuperSpeed rating unverified"   # operator-supplied
link:
  interface: enxb65575abcda3
  ipv4: 172.20.10.5/28
  gateway: 172.20.10.1
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [64, 57, 59]
  parallel_4_aggregate_mbps: 85
  rtt_ms:
    min: 31.5
    avg: 54.2
    max: 112.4
    mdev: 30.9
  errors: 0
  drops: 0
verdict: usable
---

# iPhone 17 Pro on AT&T - second cable, phone settled

Immediate re-run of
[2026-09-05-iphone-17-pro-att-cable2](2026-09-05-iphone-17-pro-att-cable2.md),
same cable and same continuous USB session, started about five minutes after
plug-in instead of ninety seconds. It exists to separate two explanations for
that pass's collapse: a phone that had only just been attached, or AT&T's radio.

**The answer is both, and mostly the radio.**

## Setup

No re-plug between the two passes -
`/sys/bus/usb/devices/3-1` still timestamps the attach at 13:14:28, so this is
the same enumeration, the same cable in the same port, and the same
`enxb65575abcda3`. Bus speed re-read at 480 before and after. WiFi `DOWN`,
tether the sole default route throughout.

Nothing was changed between the passes except elapsed time.

## Observations

### Against the pass ninety seconds after plug-in

| | 12:40, first cable | 13:15, settled 90s | 13:19, settled 5min |
|---|---|---|---|
| Single (Mbps) | 96 / 103 / 103 | 56 / 36 / 21 | 64 / 57 / 59 |
| Spread | 1.07x | 2.69x | **1.11x** |
| Par-4 | 178 | 73 | 85 |
| RTT avg | 38.0 ms | 103.6 ms | 54.2 ms |
| RTT mdev | 6.7 ms | 110.3 ms | 30.9 ms |

**The spread is the part that recovered.** 2.69x back to 1.11x, and `mdev` from
110.3 ms to 30.9 ms - both essentially back to this handset's normal shape.
Whatever was making individual transfers fall over each other at 13:15 was
transient and is gone.

**The level is the part that did not.** Aggregate went 178 -> 73 -> 85, and
average RTT 38.0 -> 103.6 -> 54.2. Five settled minutes bought back the
variance but only 16% of the throughput; the link is still running at under half
what the same phone, same carrier and same host managed three hours earlier.

So the ninety-seconds-after-plug-in confound was real but small. It accounts for
the instability, not for the shortfall. The shortfall is upstream.

### Rubric

This pass fits the README's **"single ~= parallel aggregate"** case, genuinely
WAN-limited. Three transfers landed within 7 Mbps of each other, and four
concurrent streams together reached only 1.34x the best single - nowhere near
the 2-3x that marks a per-flow limit, and 85 Mbps is 28% of the realistic bulk
ceiling of a 480 Mbps bus, so neither the tether nor the USB bus is binding.

Congestion control is not the lever here either: this ran under BBR with a
near-flat spread, which is the signature of a link with nothing to misread.

The one loose end is `mdev` at 30.9 ms against 6.7 ms on the earlier pass. That
is not the README's bufferbloat case, because the average moved too (38.0 to
54.2 ms). Both ping samples that stretched - 59.7 and 112 ms - were the last two
of five, taken immediately after the parallel transfers rather than during them,
which is the wrong order for queue buildup on this host. Read as radio, in
keeping with everything else in this pass.

The four parallel streams shared at 1.31x max:min (25 / 22 / 20 / 19 Mbps).
Zero errors and zero drops across roughly 107k RX / 36k TX packets cumulative
over both passes.

### The cable, unchanged

Same enumeration as the previous record and for the same reason: a device whose
BOS descriptor advertises 10 Gb/s SuperSpeedPlus, coming up at 480. Nothing in
this pass adds to that question - it is the same USB session. See
[the previous record](2026-09-05-iphone-17-pro-att-cable2.md) for what the
second cable does and does not settle.

## Issues

`carrier.network` is unobtainable on iOS. Left blank rather than read off the
status bar - which matters more than usual here, since a record of an AT&T
handset slowing by half is exactly the kind of result someone would later want
to attribute to a radio change, and this log cannot support that.

## Follow-ups

- **AT&T at this location degraded across the afternoon.** Two handsets could
  test that cheaply: the AT&T Pixel 9a reached 273 Mbps aggregate earlier the
  same day, so re-running it now would say whether this is carrier-wide or
  specific to the iPhone.
- The cable question is untouched by this pass and still needs a cable of known
  SuperSpeed rating, or the Thunderbolt 4 port.
- Neither of these two passes should be read as a measurement of the iPhone 17
  Pro. Between them they measure an AT&T cell at 13:15 on a Saturday.
