---
id: 2026-09-05-iphone-16e-google-fi
date: 2026-09-05
phone:
  make: Apple
  model: iPhone 16e (iPhone17,5)
  os: iOS 27.0        # build 24A5430a, read over usbmuxd (ideviceinfo)
carrier:
  name: Google Fi     # operator-supplied; iOS exposes no equivalent of gsm.operator.alpha
  network:            # TODO not obtainable - see Issues, there is no adb equivalent on iOS
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable:              # TODO unverified - moot, this device advertises no SuperSpeed
link:
  interface: enx925f7a841529
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
  single_stream_mbps: [87, 119, 101]
  parallel_4_aggregate_mbps: 228
  rtt_ms:
    min: 17.9
    avg: 25.6
    max: 38.8
    mdev: 7.6
  errors: 0
  drops: 0
verdict: good
---

# iPhone 16e on Google Fi - the first ipheth record

Closes the oldest open item in the log. The host side was prepared on
2026-09-05 (`ipheth` in tree, `usbmuxd` 1.1.1, `libimobiledevice-utils` 1.3.0)
but had never met real hardware, and the standing question was whether iOS 17+
would bind `cdc_ncm` instead.

**It does not. On iOS 27.0 this binds `ipheth`.** That question can be closed.

## Setup

Plugged in and came up without intervention. `usbmuxd` was already active and
the device was paired - `idevice_id -l` returned its UDID - so no trust prompt
had to be dealt with during this session.

Device identification came over usbmuxd rather than adb:

    ProductType     iPhone17,5     -> iPhone 16e
    ProductVersion  27.0
    BuildVersion    24A5430a
    BasebandVersion 3.01.03

The build string follows Apple's convention for a pre-release seed rather than a
release build. That is an inference from the numbering, not something the device
states, and it is worth confirming on the handset - two of the Android phones
here turned out to be on beta builds too.

**Three things differ structurally from every Android record:**

- **The subnet is a `/28`, not a `/24`.** iOS Personal Hotspot hands out
  172.20.10.0/28 - fourteen usable addresses. Every Android tether here issued a
  /24. Nothing about this run depends on it, but it is a real format difference
  worth knowing before someone tries to attach many clients.
- **`negotiated_link_mbps` is unavailable in a third distinct way.** `cdc_ncm`
  reports a number, `rndis_host` reports `-1`, and `ipheth` fails the read
  outright: `/sys/class/net/<if>/speed` returns `Invalid argument` (EINVAL). All
  three mean "no link speed", and none of them is an error.
- **No `ntb` block**, as with RNDIS - NTB aggregation is an NCM concept.

## Observations

Single-stream was 87 / 119 / 101 Mbps, a 1.37x spread - mid-pack, and tight
enough that congestion control is not in question.

**The four parallel streams shared the link more evenly than anything else
measured here:** 59 / 57 / 57 / 56 Mbps, a max:min of **1.05x**. The previous
best was the Galaxy S24 at 1.22x, and the Google Fi Pixel starved a stream at
9.5x. Four streams landing within 3 Mbps of each other is close to perfect
fairness.

Aggregate was 228 Mbps, the lowest of the BBR-era records (228 to 273), and
about 76% of the realistic USB 2.0 bulk ceiling. Note that the fairness and the
low aggregate are the same observation from two directions: nothing is being
starved, and nothing is getting a large share either.

RTT averaged 25.6 ms - the second lowest in the log after the Flip6's 23.0 -
with 7.6 ms mdev on a 17.9-38.8 ms range. The jitter is higher than the steady
RNDIS phones managed under BBR, though nowhere near the 16.5 ms the razr's CUBIC
pass produced.

Zero errors and zero drops across roughly 42k RX / 10k TX packets.

## Issues

**`carrier.network` cannot be obtained on iOS, and this is a method gap rather
than an omission.** On Android, `adb shell getprop gsm.network.type` gives the
radio access technology directly, and the skill now reads it before and after a
pass. iOS exposes no equivalent over usbmuxd. `ideviceinfo` surfaces
`BasebandVersion` and `MobileSubscriberNetworkCode` (240, which is T-Mobile
space and consistent with Google Fi without confirming it), but not the radio
in use. Left blank rather than read off the status bar - the AT&T Pixel showed
what that is worth.

`carrier.name` is operator-supplied for the same reason.

## Follow-ups

- **Not SuperSpeed-capable.** The BOS descriptor carries two capabilities, a USB
  2.0 Extension (LPM) and an Apple platform descriptor, and no SuperSpeed
  capability. So 480 Mbps is this device's own ceiling and `usb.cable` is moot,
  as it is on the razr. The running tally across the log:

        SuperSpeed-capable, pinned at 480:   Pixel 9a x2, Flip6, S25, S24
        not capable, 480 is the ceiling:     razr 2024, iPhone 16e

  Five capable devices across three vendors still enumerate at 480, and nothing
  on this host has ever trained SuperSpeed on any bus.
- A CUBIC pass would show whether the razr's result - faster under CUBIC, eight
  times the jitter - holds on a different driver. `ipheth` is the most different
  transport in the log.
- Radio type remains unobtainable here. If it matters for iOS records, the only
  route is reading it on the device and accepting that it is unverifiable.
