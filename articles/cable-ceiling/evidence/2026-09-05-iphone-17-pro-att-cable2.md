---
id: 2026-09-05-iphone-17-pro-att-cable2
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
  single_stream_mbps: [56, 36, 21]
  parallel_4_aggregate_mbps: 73
  rtt_ms:
    min: 41.2
    avg: 103.6
    max: 323.5
    mdev: 110.3
  errors: 0
  drops: 0
verdict: poor
---

# iPhone 17 Pro on AT&T - second cable, same 480

Cable re-test following
[2026-09-05-iphone-17-pro-att](2026-09-05-iphone-17-pro-att.md), whose
follow-up named the cable as the prime suspect after the same cable enumerated
at 480 in two different physical ports.

**The cable was changed. The enumeration did not move.** The throughput
numbers, unrelated to that, collapsed - see Observations.

## Setup

Phone attached with a different USB-C to USB-C cable, into the same physical
port as the previous pass (`3-1`, on the `usb3` 480 Mbps root hub). This was a
genuine fresh negotiation, not a stale reading: `/sys/bus/usb/devices/3-1`
timestamps the attach at 13:14:28, about ninety seconds before the first
transfer.

Came up without intervention. Same device identity as before - `05ac:12a8`,
`ipheth`, `/28` hotspot subnet, same `enxb65575abcda3`. WiFi (`wlo1`) was
`DOWN` and the tether was the sole default route for the whole pass.

    ProductType     iPhone18,1     -> iPhone 17 Pro
    ProductVersion  27.0
    BuildVersion    24A5430a

**The new cable's rating is unverified** - it is a second C-to-C cable, not a
cable known to be wired for SuperSpeed. That distinction is the whole weight of
this record and is why it does not close the question.

## Observations

### The bus: one more cable eliminated, the question still open

The BOS descriptor is unchanged, read again in the state the transfers ran in:

    bcdUSB               2.10
    SuperSpeed USB Device Capability:
      wSpeedsSupported   0x000e   -> Device can operate at SuperSpeed (5Gbps)
    SuperSpeedPlus USB Device Capability:
      bmSublinkSpeedAttr[0]  10Gb/s Symmetric RX SuperSpeedPlus
      bmSublinkSpeedAttr[1]  10Gb/s Symmetric TX SuperSpeedPlus

A 10 Gbps device, freshly re-enumerated across a different cable, came up at
480 again. `usb4` - the 10 Gbps root hub that is this port's SuperSpeed
companion - still has no device attached, as it has not across every phone and
peripheral this log covers.

What this does and does not establish:

- **It rules out that one specific first cable.** Two cables, two ports, four
  combinations' worth of evidence pointing the same way.
- **It does not rule out cables as a class.** Neither cable is *known* to carry
  SuperSpeed pairs, and a C-to-C cable shipped with a phone charger usually
  does not. Two USB 2.0 cables produce exactly this result. Until a cable
  verifiably rated 5 or 10 Gbps is tried, "both cables were USB 2.0" remains at
  least as likely as anything on the host side.

So the follow-up from the previous record is answered only in its narrow form.
The two clean remaining tests are unchanged: a cable with a known SuperSpeed
rating, and the Thunderbolt 4 controller at `00:0d.0` whose 20 Gb/s root hub
has still never seen a device.

### The measurements: everything moved, and none of it was the tether

Single-stream ran 56 / 36 / 21 Mbps - a **2.69x spread**, declining on every
transfer. Aggregate was **73 Mbps**, which is by a wide margin the lowest in
this log; the previous floor was 178, set by this same handset three hours
earlier. RTT averaged 103.6 ms against 38.0 ms on the earlier pass, with
`mdev` at 110.3 ms against 6.7 ms and a single 323 ms sample beside a 41.2 ms
minimum.

**This shape fits none of the five cases in the README's rubric**, and it is
worth saying so rather than forcing it:

- Not "wide spread, RTT flat" - the spread is wide but RTT is the opposite of
  flat, and this ran under BBR, which is the option that does *not* misread
  radio loss as congestion.
- Not "single ~= aggregate": aggregate is 1.31x the best single and 1.94x the
  mean, so there is some headroom, but nothing like the 2-3x that marks a
  per-flow limit.
- Not the USB 2.0 ceiling: 73 Mbps is 24% of the realistic bulk ceiling on this
  bus. The bus was nowhere near binding.
- Not bufferbloat: `mdev` rose sixteenfold, but the average rose too, from 38.0
  to 103.6 ms. Bufferbloat is the case where the average does *not* move.

The distinguishing fact is that **everything degraded at once while the host
side was byte-for-byte identical to the earlier pass** - same driver, same
`bbr`, same MTU 1500, same `/28`, same route, and **zero errors and zero drops**
across roughly 63k RX / 22k TX packets. A cable bad enough to cost 60% of the
throughput would show up in those counters. It does not.

That points upstream, at AT&T's radio at 13:15 rather than at anything this
machine or this cable is doing. The four parallel streams shared at 1.57x
max:min (23 / 19 / 17 / 15 Mbps), which is unremarkable.

One thing that is not a clean decay: the singles fell 56 -> 36 -> 21, but the
parallel run that followed them totalled 73 Mbps, well above that last 21. So
capacity partly recovered rather than sliding steadily; the third single caught
a trough.

`verdict: poor` describes this pass. It is a judgement about the twenty minutes
it occupied, not about the handset - the same phone was `good` earlier the same
day on the same carrier.

## Issues

`carrier.network` is unobtainable on iOS, as on every `ipheth` record here.
Left blank rather than read off the status bar.

The pass began about ninety seconds after plug-in, which is a confound worth
naming: a phone that has just started charging at high current, and a hotspot
that has just been brought up, are not necessarily in steady state. A second
pass with the phone settled is being recorded separately to separate that from
the carrier.

## Follow-ups

- **A cable with a verified SuperSpeed rating is still the test that matters.**
  Two cables of unknown rating both giving 480 is consistent with both of them
  being USB 2.0.
- **Find the Thunderbolt 4 port.** Unchanged from the previous record and now
  more attractive: TB4 is guaranteed SuperSpeed-wired, so a 480 reading there
  would convict the cable outright.
- A settled re-run on this handset, to separate the ninety-seconds-after-plug-in
  confound from AT&T's radio.
