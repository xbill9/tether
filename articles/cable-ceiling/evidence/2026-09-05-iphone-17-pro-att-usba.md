---
id: 2026-09-05-iphone-17-pro-att-usba
date: 2026-09-05
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)
  os: iOS 27.0        # build 24A5430a, read over usbmuxd (ideviceinfo)
carrier:
  name: AT&T          # operator-supplied; corroborated by a 2600:382::/32 delegation
  network:            # TODO not obtainable - iOS exposes no equivalent of gsm.network.type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "USB-A to USB-C, fourth cable - unmarked, SuperSpeed rating unverified"   # operator-supplied
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
  single_stream_mbps: [76, 58, 61]
  parallel_4_aggregate_mbps: 130
  rtt_ms:
    min: 32.4
    avg: 52.1
    max: 65.8
    mdev: 12.1
  errors: 0
  drops: 0
verdict: usable
---

# iPhone 17 Pro on AT&T - the USB-A port, which nobody knew existed

Fourth pass on this handset today, after
[cable 1](2026-09-05-iphone-17-pro-att.md) (`3-2`),
[cable 2](2026-09-05-iphone-17-pro-att-cable2.md) and
[its settled re-run](2026-09-05-iphone-17-pro-att-cable2-settled.md) (`3-1`),
and [cable 3](2026-09-05-iphone-17-pro-att-cable3.md) (`3-1`).

**This machine has a third physical port, and the log had concluded it did not.**
The phone came up on `3-3`, a USB-A receptacle, and enumerated at **480 again**.

## Setup

Genuine fresh attach: device number stepped 7 -> 13 and the kernel logged

    usb 3-3: new high-speed USB device number 13 using xhci_hcd
    usb 3-3: New USB device found, idVendor=05ac, idProduct=12a8, bcdDevice=18.01
    ipheth 3-3:4.2: Apple iPhone USB Ethernet device attached

at 14:07:03. Same device identity as every previous pass - `05ac:12a8`,
`ipheth`, `enxb65575abcda3`, same `/28` hotspot subnet, `172.20.10.5`. WiFi
(`wlo1`) was `DOWN` and the tether was the sole default route throughout, checked
again between the single-stream and parallel runs.

    ProductType     iPhone18,1     -> iPhone 17 Pro
    ProductVersion  27.0
    BuildVersion    24A5430a

Transfers started at 14:11:59, **296 seconds after attach**, deliberately matched
to the ~4.5-5 minute settle of the two comparable passes rather than the
ninety-second one. See "Settling" below for what filled that time.

**A USB-A port forces a fourth cable.** A C-to-C cable cannot enter a Type-A
receptacle, so this pass necessarily changed the port *and* the cable together.
That confound is not incidental - it is the main limit on what this record
proves, and it is treated below rather than buried. The cable is unmarked, like
the three before it; the operator could not confirm how the receptacle is
marked, so nothing is recorded about that.

## Observations

### The finding: there was an untried port, and the log said there was not

[Cable 3](2026-09-05-iphone-17-pro-att-cable3.md) established the Type-C mapping
from `/sys/class/typec` and concluded, in its own words, that the claim
"there is a port on this machine that has never been used" was wrong, that
"this machine has exactly two USB-C connectors, and both have been tested", and
that the host was "largely exonerated".

The mapping was right. **The conclusion drawn from it was not, and the reason is
worth stating plainly: `/sys/class/typec` enumerates Type-C connectors only.**
A Type-A receptacle has no PD, no connector object and no `typec` node, so it is
structurally invisible to that enumeration. Reasoning from `/sys/class/typec` to
"every port on this machine" cannot see a USB-A port, and here there was one.

The port list shows it, and shows that firmware declares it SuperSpeed-capable:

| `usb3` port | connect_type | location | SuperSpeed peer |
|---|---|---|---|
| `usb3-port1` | hotplug | `0x80000101` | `usb4-port1` (10 Gb/s) |
| `usb3-port2` | hotplug | `0x80000201` | `usb2-port1` (20 Gb/s, TB4) |
| **`usb3-port3`** | **hotplug** | **`0x80000301`** | **`usb4-port2` (10 Gb/s)** |

`usb3-port3` and `usb4-port2` name each other as `peer` and share location
`0x80000301` - the kernel saying they are the two halves of one receptacle,
exactly as it does for the two Type-C connectors. The other nine `usb3` ports are
`hardwired` (the internal card reader, fingerprint reader, camera and Bluetooth)
or `not used`. **So this host has three hotplug receptacles, all three declared
SuperSpeed-capable by firmware, and the third is USB-A.**

The tally is now **three physical ports, four cables, always 480**, on a device
whose BOS descriptor - re-read in the state these transfers ran in - is unchanged:

    bcdUSB               2.10
    SuperSpeed USB Device Capability:
      wSpeedsSupported   0x000e   -> Full, High, SuperSpeed (5Gbps)
    SuperSpeedPlus USB Device Capability:
      bmSublinkSpeedAttr[0]  10Gb/s Symmetric RX SuperSpeedPlus
      bmSublinkSpeedAttr[1]  10Gb/s Symmetric TX SuperSpeedPlus

And `usb4` was checked again immediately after the transfers: **still no device
attached, on either of its two hotplug ports.** Nothing in this log has ever
trained SuperSpeed on any bus of this machine.

### What this does and does not move

**It does not isolate the port from the cable**, and cannot: the receptacle
change forced the cable change. A fourth unmarked cable giving 480 is exactly
what a fourth USB 2.0 cable would give, and unmarked cables of this class
usually are. On its own the throughput-free part of this pass is one more
repetition of the same ambiguous result.

**What it does move is the host-side reasoning.** The previous record narrowed
the field to "cables, or something physical behind one of two connectors" by
asserting the port inventory was complete. It was not. A USB-A receptacle is
wired differently from a Type-C one - different traces, no retimer, no PD, no
mux - and it still produced 480. That is not proof, but it is the first evidence
about the host that did not come from a Type-C connector, and it weakens
"something physical behind the connector" as a single-fault explanation, because
it would now have to be a fault behind all three.

**The decisive test is unchanged and is now easier.** A USB 3 mass-storage
device with its own rated cable, plugged into `3-3`, settles it in seconds and
costs no cellular data. A USB-A receptacle is also the friendliest place to try
it, since USB 3 flash drives with a fixed A connector need no cable at all -
which removes the cable variable completely, something none of the four passes
so far has managed. **Do that before a fifth cable.**

### Settling, and an idle RTT baseline worth having

The 296 seconds between attach and the first transfer were spent on
`ping -c 130 -i 1` - about 10 KB of data, no meaningful cost on a metered plan -
which gives something this log has not had before: **RTT on an idle tether, over
130 samples.**

    idle, 130 samples   min 31.6   avg 47.8   max 72.4   mdev 7.7   0% loss
    after transfers, 5  min 32.4   avg 52.1   max 65.8   mdev 12.1  0% loss

This matters for reading every earlier record on this handset. The 12:40 baseline
pass measured 38.0 ms average; this pass measures 52.1 ms. **That 14 ms is not a
load effect - the idle baseline is already at 47.8 ms.** The path itself is
slower now than it was at 12:40, and load added roughly 4 ms of average and 4 ms
of `mdev` on top. A five-sample `ping` after the transfers cannot separate those
two things; 130 idle samples can, and they say the average is carrier state, not
queueing.

Zero packet loss across 135 total pings is also the cleanest loss figure recorded
here, and it is a point against any reading of the single-stream spread as
congestion control reacting to radio loss.

### The measurements

Single-stream ran 76 / 58 / 61 Mbps - a **1.32x spread**. Aggregate was
**130 Mbps**, the highest of the four afternoon passes.

| | 12:40 c1, `3-2` | 13:15 c2, `3-1` 90s | 13:19 c2, `3-1` settled | 13:26 c3, `3-1` | 14:12 c4, **`3-3` USB-A** |
|---|---|---|---|---|---|
| Single (Mbps) | 96 / 103 / 103 | 56 / 36 / 21 | 64 / 57 / 59 | 55 / 25 / 68 | 76 / 58 / 61 |
| Spread | 1.07x | 2.69x | 1.11x | 2.72x | **1.32x** |
| Par-4 | 178 | 73 | 85 | 101 | **130** |
| RTT avg | 38.0 ms | 103.6 ms | 54.2 ms | 45.9 ms | **52.1 ms** |
| RTT mdev | 6.7 ms | 110.3 ms | 30.9 ms | 9.3 ms | **12.1 ms** |

**The climb continues: 73 -> 85 -> 101 -> 130 Mbps aggregate.** Cable 3's record
warned that each swap has coincided with a step of that recovery, and **this pass
is the fourth consecutive instance of the same trap.** Nothing here distinguishes
the USB-A port or the fourth cable from any earlier combination. Time is still
the variable that moved. The 130 Mbps figure is the afternoon's best because it
was measured last, not because it was measured on USB-A - and it is still only
73% of the 178 Mbps this handset managed at 12:40 on the port and cable that
looked worst on paper.

**Against the README's rubric, this pass does not fit one case cleanly, so it is
recorded as not fitting rather than forced.** The relevant numbers:

- Aggregate is **1.71x the best single** and **2.00x the mean single**. That is
  real headroom, so this is not the "single ~= aggregate" WAN-limited case.
- 130 Mbps is **43% of the realistic bulk ceiling of a 480 Mbps bus**, so the USB
  2.0 bus is not binding - as it has not been on any pass on this handset.
- `mdev` rose 7.7 -> 12.1 ms while the average rose 47.8 -> 52.1 ms. Both moved,
  and both barely. Not bufferbloat, which is the case where the average does not
  move.
- The 1.32x spread is too tight for "wide spread with flat RTT", and that case's
  remedy is BBR, which was already in use.

The closest fit is **the per-flow limit** - a moderate spread with aggregate
twice the mean single - but it is a weaker instance than the two the log already
has: the AT&T Pixel 9a at 1.06x spread and 2.6x best single, and the razr plus
2023 at 1.25x and 2.47x. Here it is 1.32x and 1.71x best single. Read as "a
single flow is not reaching the ceiling, but the evidence is soft", and note that
the outstanding per-flow test - one stream with an enlarged socket buffer - would
resolve it for one 8 MB transfer.

The four parallel streams shared at 1.22x max:min (35 / 34 / 33 / 29 Mbps).
Zero errors and zero drops across roughly 44.7k RX / 13.2k TX packets for this
pass. **Four cables and three ports have now produced zero USB errors between
them**, which continues to argue that whatever holds this link at 480 is a
negotiation outcome and not a marginal or damaged connection.

## Issues

`carrier.network` is unobtainable on iOS, as on every `ipheth` record here. Left
blank rather than read off the status bar - and on AT&T that matters more than
elsewhere, since the carrier brands LTE-Advanced as "5G E".

The port and cable changed together and cannot be separated by this pass. Named
in Observations rather than left for a reader to notice.

The receptacle's own marking (blue / SS logo) was not observed, so nothing is
recorded about it. Firmware declaring `usb4-port2` as its SuperSpeed peer is the
only evidence here that the port is wired for it.

## Follow-ups

- **Plug a USB 3 flash drive into `3-3`.** Still the only open question, still
  free, and now easier than it was: a flash drive with a fixed USB-A connector
  removes the cable from the experiment entirely, which no pass in this
  investigation has managed. Trains SuperSpeed and every cable tried so far was
  USB 2.0; stays at 480 across a cable-free attach and the fault is in the host.
- **The port inventory should be taken from the USB port list, not
  `/sys/class/typec`.** The three `hotplug` entries under `usb3` - `port1`,
  `port2`, `port3` - are the complete list of external receptacles on this
  machine, and each names its SuperSpeed peer. `/sys/class/typec` shows two of
  the three by construction. Corrections filed against
  [cable 3](2026-09-05-iphone-17-pro-att-cable3.md), which drew the wrong
  conclusion from the right data.
- **Do not read the 73 -> 85 -> 101 -> 130 climb as anything but time.** Four
  passes, four different port/cable combinations, one monotonic recovery. A Pixel
  9a pass now would still be the cleanest way to confirm the recovery is
  carrier-wide, and it is worth more than a fifth cable.
- The 130-sample idle ping cost about 10 KB and separated carrier latency from
  queueing latency in a way `ping -c5` cannot. Worth doing on every pass where
  the RTT average is part of the finding.
- This pass is a measurement of an AT&T cell at 14:12, not of the iPhone 17 Pro,
  for the same reason as the three before it.
