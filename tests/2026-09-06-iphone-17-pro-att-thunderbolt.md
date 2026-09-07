---
id: 2026-09-06-iphone-17-pro-att-thunderbolt
date: 2026-09-06
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)   # read over usbmuxd (ideviceinfo); corroborated by bcdDevice=18.01
  os: iOS 27.0                        # read over usbmuxd (ideviceinfo -k ProductVersion)
carrier:
  name: AT&T         # operator-supplied in earlier records; this session's delegation is 2600:382::/32, adjacent to the 2600:381::/32 seen before
  network:           # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 10000
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "Thunderbolt, USB-C to USB-C"   # operator-supplied
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
  single_stream_mbps: [151.036, 119.931, 147.540]
  parallel_4_aggregate_mbps: 361.330
  rtt_ms:
    min: 23.770
    avg: 27.268
    max: 30.084
    mdev: 2.272
  errors: 0   # RX+TX delta across the pass; all cumulative counters 0 -> 0
  drops: 0    # RX+TX delta across the pass; all cumulative counters 0 -> 0
verdict: good
---

# iPhone 17 Pro on AT&T - Thunderbolt, and the first 10000 Mbps bus in the log

The fastest record here by a wide margin, and the first device to enumerate
above 5000. It supersedes nothing - it is a new cable and a new host controller
against the
[SuperSpeed record](2026-09-06-iphone-17-pro-att-superspeed.md) from earlier
the same day - but the comparison with that record is the most interesting thing
in it, and not for the reason the numbers first suggest.

## Setup

Measured 2026-09-06, 23:01 EDT. The handset was swapped in after an
[iPhone 16e pass](2026-09-06-iphone-16e-google-fi-cubic.md) finished at 22:53;
`ideviceinfo` returned `iPhone18,1` and `lsusb` `bcdDevice 18.01`, both the
iPhone 17 Pro. It bound `ipheth` as `enxb65575abcda3` on `172.20.10.5/28`,
gateway `172.20.10.1`, with an AT&T IPv6 delegation.

**This is a different host controller from every previous record.** The phone
enumerated on `0000:00:0d.0` / `usb2` - the Thunderbolt controller - not the
`0000:00:14.0` / `usb3` + `usb4` pair that carried every earlier test. Bus speed
read **10000**, twice the 5000 the same handset trained on the USB-A to USB-C
cable earlier today, and the first four-figure-above-5000 reading in the log.

The device side supports it: `bcdUSB 3.20`, `bNumDeviceCaps 4`, and a
SuperSpeed USB Device Capability advertising "Device can operate at SuperSpeed
(5Gbps)". Contrast the iPhone 16e measured eight minutes earlier, which
advertises no SuperSpeed capability at all and cannot leave 480.

`ip route show default` named the tether for the whole pass, `wlo1` was `DOWN`
with `NO-CARRIER`, and `ideviceinfo` still returned `iPhone18,1` with the bus
still at 10000 afterwards - so the same device carried all eight transfers.

## Observations

Single-stream ran **151.0 / 119.9 / 147.5 Mbps**, a 1.26x spread around a
139.5 Mbps mean. Parallel-4 aggregated **361.3 Mbps** (105.7 + 98.3 + 90.8 +
66.6). RTT averaged 27.3 ms with `mdev` **2.27** - the flattest jitter in the
log next to the razr's CUBIC pass.

**A near-flat spread with an aggregate 2.59x the single-stream mean is the
README's fifth case: a per-flow limit.** Four streams together reached 361 Mbps,
so the WAN plainly had that much headroom; one stream reproducibly stopped near
140. Nothing on this machine was collapsing - the spread is 1.26x and `mdev` is
2.27 ms, so there is no loss being misread and no queue being filled.

**This is the third sighting of that shape and the second on AT&T**, after the
AT&T Pixel 9a (1.06x spread, aggregate 2.6x best single) and the Google Fi razr
plus 2023 (1.25x, 2.47x). At 2.39x best / 2.59x mean this run sits right on top
of them.

The open item in `INDEX.md` asks whether that is carrier shaping per flow or one
flow failing to fill the bandwidth-delay product. **This run narrows it from the
host side.** The BDP at 151 Mbps and 27.3 ms RTT is about 503 KB, while
`tcp_rmem` maxes at 33554432 and window scaling is on, so the receive window is
two orders of magnitude clear of the requirement. The host was never the binding
constraint, which leaves carrier shaping as the better-supported of the two.
That is not proof - it excludes the receive window, not sender-side cwnd
behaviour - so the direct experiment in the open item is still worth running.

**Appended 2026-09-06, minutes after this pass - the per-flow reading above is
wrong.** The follow-up experiment was run on this same connection before the
handset was unplugged, and it does not support a per-flow limit:

| transfer | result |
|---|---|
| 8 MB single, default buffer | 135.8 Mbps, then 159.7 Mbps |
| 8 MB single, `SO_RCVBUF` forced to 8 MB | 51.6 Mbps |
| **32 MB single, default buffer** | **332.3 Mbps, then 327.2 Mbps** |
| 4 x 8 MB concurrent (this record) | 361.3 Mbps aggregate |

**One flow reached 332 Mbps - essentially the whole 4-stream aggregate.** The
single-vs-aggregate gap measured above is an artifact of the fixed 8 MB transfer
size, not a property of the link. At ~140 Mbps an 8 MB transfer lasts about
0.45 s while slow-start needs roughly 6 RTTs (~160 ms here) just to open the
window to the 503 KB BDP, so a third of it is spent ramping; four parallel flows
ramp with four times the initial window and so look far faster in aggregate.

Enlarging the socket buffer made it three times *worse*, which is the expected
behaviour - an explicit `SO_RCVBUF` disables receive-window autotuning. That
confirms the BDP argument above from the other direction: the window was never
binding.

The measurements in the frontmatter are left exactly as taken - they are a
correct 8 MB pass and comparable to every other record. What changes is their
interpretation. `README.md`'s fifth diagnostic case and `bin/tether-report` were
both updated to guard on transfer duration as a result, and the two earlier
sightings of this shape are now in doubt for the same reason.

An attempt to instrument the flow with `ss -ti` during the transfer produced
nothing usable - at 0.77 s the transfer is shorter than the sampling could
resolve, and the sockets captured were unrelated idle connections. The
throughput result stands on its own and was reproduced twice; the cwnd evidence
was not obtained.

**The bus is not the story, and the jump from this morning is not the cable.**
It is tempting to read 21.2 -> 361.3 Mbps aggregate against 5000 -> 10000 Mbps
of bus and call it a cable win. It is not. The earlier SuperSpeed pass managed
10.9 / 19.4 / 16.7 single and a 21.2 Mbps aggregate **on a 5000 Mbps bus** - it
was using well under one percent of the bus it had. A link that idle cannot be
relieved by doubling it. Something else changed between that pass and this one,
and the honest candidate is the radio: `carrier.network` is unobtainable on iOS,
so there is no way to check what the handset was on either time. The earlier
record's RTT tells the same story - avg 85.1 ms with `mdev` 85.3, against 27.3
and 2.27 here. That is not a different cable, that is a different network
condition.

So: the Thunderbolt cable and the 10000 Mbps bus are real and worth recording,
but they explain none of the throughput difference. At 361 Mbps aggregate this
pass is still using under 4% of the bus.

## Issues

None. Zero errors and zero drops across all eight transfers, no interface
bounce, no route change.

`carrier.network` is blank for the same structural reason as every iOS record
here. `carrier.name` is carried as AT&T on the operator's earlier confirmation
for this handset; note that the delegation this session was `2600:382::/32`
rather than the `2600:381::/32` recorded before. Both are consistent with the
same carrier, but the prefix alone does not establish it and it was not
re-confirmed tonight.

## Follow-ups

- ~~Run the per-flow experiment.~~ **Done 2026-09-06, immediately
  after this pass, and it overturned the reading above** - see the note appended
  to Observations. There is no per-flow limit on this link.
- **Re-test the earlier SuperSpeed configuration now.** The 17x gap against this
  morning's pass is attributed to the radio on circumstantial evidence. Putting
  the USB-A to USB-C cable back in at this hour would separate "the radio was bad
  this morning" from "that host port is bad" in one pass.
- Nothing here approaches the bus ceiling. Until a record does, `bus_speed_mbps`
  above 480 has no measured consequence anywhere in this log.
