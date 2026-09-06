---
id: 2026-09-06-iphone-17-pro-att-superspeed
date: 2026-09-06
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)   # operator-confirmed; corroborated by bcdDevice=1801
  os: iOS 27.0        # operator-confirmed - ideviceinfo was NOT available this run, see Issues
carrier:
  name: AT&T          # operator-confirmed; corroborated by a 2600:381::/32 delegation
  network:            # TODO not obtainable - iOS exposes no equivalent of gsm.network.type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 5000
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "USB-A to USB-C, new cable - first one in this log to train SuperSpeed"   # operator-supplied
link:
  interface: enxb65575abcda3
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
  single_stream_mbps: [10.872, 19.379, 16.698]
  parallel_4_aggregate_mbps: 21.246
  rtt_ms:
    min: 36.271
    avg: 85.105
    max: 255.464
    mdev: 85.342
  errors: 0
  drops: 0
verdict: usable
---

# iPhone 17 Pro on AT&T - SuperSpeed at last, and it changed nothing

The 2026-09-05 investigation asked one question across four cables and three
ports: why does a device advertising 10 Gb/s enumerate at 480? See
[the first pass](2026-09-05-iphone-17-pro-att.md), which framed it, and the
[cable2](2026-09-05-iphone-17-pro-att-cable2.md) /
[cable3](2026-09-05-iphone-17-pro-att-cable3.md) /
[usba](2026-09-05-iphone-17-pro-att-usba.md) records that failed to move it.

**This pass enumerated at 5000.** It is the first record in the log on a
SuperSpeed bus.

**It is also one of the slowest.** 21 Mbps aggregate on a bus with a 5000 Mbps
ceiling. The bus was never the constraint, and the whole cable hunt was
chasing a limit that was not binding.

## Setup

Came up without intervention. WiFi was down (`wlo1` NO-CARRIER) and the tether
was the sole default route for the entire pass, checked before the transfers
and again after.

The device attached at `4-2` rather than the `3-x` of every previous pass,
which is itself the finding - `4-2` is `usb4-port2`, and the port peer map says:

    usb4-port2  peer=usb3-port3  location=0x80000301
    usb3-port3  peer=usb4-port2  location=0x80000301

`usb3-port3` is the USB-A receptacle at `3-3`, the one tested at 480 on
2026-09-05 at 14:07. Same physical receptacle, same location code; the device
moved to the `usb4` hub only because it is now training SuperSpeed, which is
exactly what a successful 5 Gb/s negotiation looks like on this host. The
operator reports both cable and port were changed, but by the host's own
account the receptacle is not new - **the cable is the variable that actually
moved.**

Descriptors read in the state the transfers ran in:

    version     3.20      (device advertises USB 3.2)
    speed       5000      (trained at Gen 1, 5 Gb/s)
    bcdDevice   1801      (iPhone18,1)

Note the gap: the device advertises 3.2 and the prior record read
SuperSpeedPlus at 10 Gb/s, but the link trained at **5000, not 10000**. The new
cable is a Gen 1 cable. `usb4-port2` is a 10 Gb/s port, so the device's own
ceiling is still not being reached - it has simply stopped being the
interesting question.

## Observations

**Rubric case: single ~= parallel aggregate - genuinely WAN-limited.** Best
single 19.379 Mbps, four-stream aggregate 21.246 Mbps, a ratio of **1.10x**.
Four flows together bought 10% over one flow. There is no headroom on the WAN
side for a second flow to find, which rules out both the per-flow-limit case
and the congestion-control-collapse case: if CUBIC were halving its window on
radio loss, four parallel flows would aggregate far above one. They did not.

The single-stream spread is 1.78x (10.872 to 19.379) - moderate, and not the
7.7x signature of CUBIC misreading radio loss.

**So the constraint is upstream of this machine, and nothing here is tunable
into it.** That is the same conclusion the 480 Mbps records reached, now
reached on a bus ten times faster, which is what makes it worth stating: the
USB ceiling and the throughput ceiling were never the same ceiling.

**The RTT does not fit any of the five rubric cases, and I am not forcing it
into one.** Average 85.1 ms against the 38.0 ms of the 12:40 baseline on
2026-09-05, with `mdev` at 85.3 ms - but that `mdev` is the work of a single
255 ms outlier on the fifth of five pings, against 36-51 ms for the other four.
This is neither the bufferbloat case (average unchanged, `mdev` up) nor a clean
elevated-latency reading; five samples with one outlier cannot distinguish a
degraded radio from one scheduling hiccup. The honest reading is that the
latency data from this pass is too thin to diagnose.

**Two variables moved since the last iPhone 17 Pro record, not one.** The bus
went 480 -> 5000 *and* the host's TCP settings reverted to stock: this pass ran
`cubic` / `slow_start_after_idle=1` / `mtu_probing=0`, where every 2026-09-05
record ran `bbr` / `0` / `1`. Throughput is not attributable between them from
this record alone. The aggregate ratio argues congestion control is not what is
holding the number down, but that is an inference, not a measurement.

The `To test` note about AT&T recovering rather than degrading is also relevant
context: those passes were on a monotonic climb from a dip. This pass, a day
later, sits well below even the bottom of it.

## Issues

`ideviceinfo` was **not available** this run. Only `libimobiledevice-1.0-6`,
`libimobiledevice-glue` and `usbmuxd` are installed - the
`libimobiledevice-utils` package that the 2026-09-05 records read
`ProductType` / `ProductVersion` / `BuildVersion` from is gone from this host.
`usbmuxd` is running and the device is attached, so the daemon side is fine; it
is the CLI that is missing.

`phone.model`, `phone.os` and `carrier.name` are therefore **operator-supplied
this time**, not host observations, and are marked as such in the frontmatter.
The host evidence that corroborates them is real but circumstantial: the
interface MAC matches the 2026-09-05 iPhone 17 Pro records exactly,
`bcdDevice=1801` matches `iPhone18,1`, and the IPv6 delegation is in AT&T's
`2600:381::/32`. No independent evidence at all supports the **iOS version** -
it is carried on the operator's word, and a build change since 2026-09-05 would
not be visible from here.

`ip -s link` was read only after the transfers, per the current skill text, so
the counters are cumulative since the interface came up rather than a delta for
the pass. Both are zero, so the ambiguity does not matter here - but it would
have, had they not been. This is the open `To test` item about taking a
before-reading, and this pass did not close it.

## Follow-ups

- **Re-run this exact configuration under BBR.** It is the one change that
  separates the two variables that moved together. Costs a full pass and is the
  highest-value next test in the log: every 2026-09-05 iPhone number is a BBR
  number, and this record cannot be compared with any of them until there is a
  matching one.
- **Reinstall `libimobiledevice-utils`** before the next iOS pass, so model and
  build come back from the device instead of from the operator.
- **Close the USB-A flash-drive item in `INDEX.md` - it is now moot.** Its
  purpose was to decide between "every cable so far was USB 2.0" and "the fault
  is in the host". A cable swap on the same receptacle took it from 480 to
  5000, which answers it: the cables were the problem. No cable-free attach is
  needed.
- **A Gen 2 cable is still untried.** The device advertises USB 3.2 and
  `usb4-port2` is rated 10 Gb/s, but the link trained at 5 Gb/s. Low value for
  throughput - 21 Mbps does not care - but it would finish the descriptor
  story.
- `carrier.network` remains unobtainable on iOS. Unchanged from every previous
  iPhone record; noted so the blank is not mistaken for an oversight.
