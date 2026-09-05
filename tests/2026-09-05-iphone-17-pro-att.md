---
id: 2026-09-05-iphone-17-pro-att
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
  cable:              # TODO unverified - and this record makes it the whole question, see body
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
  single_stream_mbps: [96, 103, 103]
  parallel_4_aggregate_mbps: 178
  rtt_ms:
    min: 30.7
    avg: 38.0
    max: 46.0
    mdev: 6.7
  errors: 0
  drops: 0
verdict: good
---

# iPhone 17 Pro on AT&T - a 10 Gbps device running at 480

Second `ipheth` record, after
[2026-09-05-iphone-16e-google-fi](2026-09-05-iphone-16e-google-fi.md). Same iOS
build (27.0, `24A5430a`), same `/28` hotspot subnet, same EINVAL on
`/sys/class/net/<if>/speed`. iOS 27 binds `ipheth` on the Pro line too.

The measurements are secondary here. **The USB descriptor is the finding.**

## Setup

Came up without intervention; `usbmuxd` already active and the device paired.
WiFi was down and the tether was the sole default route for the whole pass.

    ProductType     iPhone18,1     -> iPhone 17 Pro
    ProductVersion  27.0
    BuildVersion    24A5430a

The IPv6 delegation is in 2600:381::/32, AT&T space, corroborating the
operator-supplied carrier.

## Observations

### The bus question is now answered as far as this repo can answer it

This device advertises **both** SuperSpeed and SuperSpeedPlus:

    SuperSpeed USB Device Capability:
      wSpeedsSupported   0x000e     -> Full, High, SuperSpeed (5Gbps)
    SuperSpeedPlus USB Device Capability:
      bmSublinkSpeedAttr[0]  10Gb/s Symmetric RX SuperSpeedPlus
      bmSublinkSpeedAttr[1]  10Gb/s Symmetric TX SuperSpeedPlus

**A 10 Gbps-capable device enumerated at 480 Mbps.** The host is not the
limitation at the controller level: it has two working SuperSpeed root hubs,
`usb2` at 20 Gbps and `usb4` at 10 Gbps, both enumerated and idle. Link speed is
negotiated for the device, not per function, so this phone would have come up at
5 or 10 Gbps had the physical path allowed it.

That leaves exactly two candidates, and this record cannot separate them:

1. **The cable** carries no SuperSpeed pairs - i.e. it is a USB 2.0 cable.
2. **The physical port** in use (`3-2`, on the USB 2.0 companion bus) is not
   wired for SuperSpeed, so its partner on `usb4` never sees the device.

Everything else is eliminated. Seven handsets from four vendors have now been
attached to this host; six advertise High Speed or better, six enumerate at 480,
and **nothing has ever trained SuperSpeed on any bus of this machine**.

The cheapest next step is free and costs no cellular data: **move this same
cable to a different physical port.** If the phone appears on `usb4` at 10000,
the port was the problem. If it stays at 480, the cable is.

### The measurements

Single-stream was 96 / 103 / 103 Mbps - a **1.07x spread**, second only to the
AT&T Pixel's 1.06x, and three transfers landing within 7 Mbps of each other.

**Aggregate was 178 Mbps, and that is the lowest in the log by a wide margin**
(next lowest is 211, and every BBR-era record before this sat between 228 and
273). At about 59% of the realistic USB 2.0 bulk ceiling, this is the **first
record in which the USB 2.0 bus is not the binding constraint.** Every previous
run pressed against 76-91% of it.

So for once the aggregate figure is measuring something real rather than the
bus. With a flat single-stream spread and aggregate only 1.73x the best single,
the ceiling here is upstream - AT&T's radio at this moment - not the tether.
Compare the AT&T Pixel, which reached 273 Mbps aggregate earlier in the day on
the same carrier: that is a carrier-side difference in time or place, not a
handset one.

RTT averaged 38.0 ms with 6.7 ms mdev. The four parallel streams shared at
1.48x max:min (54 / 50 / 38 / 36 Mbps) - fair, though not the near-perfect 1.05x
the iPhone 16e produced.

Zero errors and zero drops across roughly 46k RX / 14k TX packets.

## Issues

`carrier.network` is unobtainable, as on the 16e: iOS exposes no equivalent of
`gsm.network.type` over usbmuxd. Left blank rather than read off the status bar.

## Follow-ups

- ~~Move the cable to another port.~~ **Done, same day: the phone was moved to
  the other USB-C port (`3-2` to `3-1`, confirmed by the physical slot swap with
  the Lenovo receiver) with the same cable, and enumerated at 480 again.** Two
  distinct physical ports failing identically is far less likely than one USB 2.0
  cable, so the **cable is now the prime suspect** and a known-good USB 3 cable
  is the remaining test.
- Neither USB-C port reaches the Thunderbolt 4 controller at `00:0d.0`, whose
  20 Gb/s root hub has still never seen a device. There is a port on this machine
  that has never been used; TB4 is guaranteed SuperSpeed-wired, so a 480 reading
  there would settle it beyond doubt.
- If the port turns out to be the problem, every `usb.cable` field in the log is
  answerable at once, and the aggregate figures in the eight bus-limited records
  become lower bounds rather than measurements.
- A repeat pass on this phone would separate "AT&T was slow at 12:40" from
  anything intrinsic. One sample of three transfers is thin for a claim about a
  carrier.
