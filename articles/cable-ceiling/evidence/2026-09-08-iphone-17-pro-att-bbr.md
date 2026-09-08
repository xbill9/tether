---
id: 2026-09-08-iphone-17-pro-att-bbr
date: 2026-09-08
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)   # read over usbmuxd (ideviceinfo); corroborated by bcdDevice=18.01
  os: iOS 27.0                        # read over usbmuxd (ideviceinfo -k ProductVersion)
carrier:
  name: AT&T         # operator-confirmed 2026-09-08 (backfilled); independently corroborated - 2600:381::/32 is registered to AT&T Enterprises, LLC, NetName ATTMOV6-1
  network:           # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 5000
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "Anker USB-C to USB-A, USB 3.0"   # operator-supplied, backfilled 2026-09-08 - see Setup
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
  single_stream_mbps: [134.930, 113.576, 123.229]
  parallel_4_aggregate_mbps: 365.185
  rtt_ms:
    min: 31.106
    avg: 36.715
    max: 47.310
    mdev: 5.597
  errors: 0   # RX+TX delta across the pass; all cumulative counters 0 -> 0
  drops: 0    # RX+TX delta across the pass; all cumulative counters 0 -> 0
verdict: good
---

# iPhone 17 Pro on AT&T - BBR, and the host port is cleared

The first BBR record for this handset, and it settles the open question left by
the [SuperSpeed pass](2026-09-06-iphone-17-pro-att-superspeed.md) two days ago.
It supersedes nothing: the closest comparison is the
[USB-C port record](2026-09-06-iphone-17-pro-att-usbc-port.md), same bus speed
and same handset, differing in congestion control.

## Setup

Measured 2026-09-08. The phone was already attached when the session opened -
`lsusb` showed `05ac:12a8` at `4-2` and `ipheth` had bound
`enxb65575abcda3` on `172.20.10.5/28`, gateway `172.20.10.1`, with a
`2600:381::/32` delegation. `ideviceinfo` returned `iPhone18,1` and `27.0`,
and `bcdDevice 18.01` corroborates it.

**This is the same host controller as the SuperSpeed and USB-C port records** -
`0000:00:14.0` / `usb4`, with the device enumerating at **5000**. Not the
`0000:00:0d.0` Thunderbolt controller.

**Corrected 2026-09-08, when `usb.cable` was backfilled.** This paragraph
originally read that "the 5000 is the device's ceiling on this controller and
not a cable artifact", on the strength of a BOS descriptor advertising
`bcdUSB 3.20` and "Device can operate at SuperSpeed (5Gbps)". **That was
wrong, and it was wrong because only part of the descriptor was read.** The
`wSpeedsSupported` field of the SuperSpeed capability stops at 5 Gbps by
construction - SuperSpeedPlus rates are declared in a *separate* capability
block, and this device has one:

    SuperSpeedPlus USB Device Capability:
      bmSublinkSpeedAttr[0]   0x000a4030
        Speed Attribute ID: 0 10Gb/s Symmetric RX SuperSpeedPlus
      bmSublinkSpeedAttr[1]   0x000a40b0
        Speed Attribute ID: 0 10Gb/s Symmetric TX SuperSpeedPlus

The operator has since confirmed the cable as an **Anker USB-C to USB-A, USB
3.0** - a Gen 1 cable, rated 5 Gbps. So **5000 was the cable's ceiling, not the
device's**, and the [Thunderbolt pass](2026-09-08-iphone-17-pro-att-bbr-thunderbolt.md)
taken an hour later proves it directly by training **10000** on the same
handset with a Thunderbolt cable. Read only the capability block that matches
the speed you are trying to explain, and read all four.

**Congestion control was `bbr`, not the `cubic` of every previous iPhone
record**, with `tcp_slow_start_after_idle=0` and `tcp_mtu_probing=1` - all
three differing from the 2026-09-06 passes. That is what makes this a new
record rather than a repeat.

`wlo1` was brought down before the pass and `ip route show default` named only
the tether. NetworkManager brought the Wi-Fi back up at some point during the
run, but the tether kept the lower metric (100 against 600) and **the interface
counters settle it**: RX grew by 145.0 MB across the pass against roughly
136 MB of payload requested, so the tether carried all of it. See Issues.

## Observations

Single-stream ran **134.9 / 113.6 / 123.2 Mbps**, a 1.19x spread around a
123.9 Mbps mean. Parallel-4 aggregated **365.2 Mbps** (99.4 + 95.5 + 88.5 +
81.9). RTT averaged 36.7 ms with `mdev` 5.60.

**The host port is cleared, and the radio explanation holds.** The SuperSpeed
record's follow-up asked for exactly this run: it managed a 21.2 Mbps aggregate
on this same controller at this same 5000 bus, and attributed the collapse to
the radio on circumstantial evidence, since `carrier.network` is unobtainable
on iOS. Today the same port and the same bus produced **365.2 Mbps, 17.2x that
figure**. The port is not the problem. The RTT agrees: 85.1 ms average with
`mdev` 85.3 that morning, against 36.7 and 5.60 now.

**BBR changed almost nothing here, which is the README's rule-3 "clean radio"
case.** Against the USB-C port record - same handset, same bus, same
controller, CUBIC:

| | CUBIC (09-06) | BBR (today) |
|---|---|---|
| single mean | 136.0 Mbps | 123.9 Mbps |
| single spread | 1.11x | 1.19x |
| parallel-4 | 370.7 Mbps | 365.2 Mbps |
| RTT avg | 29.6 ms | 36.7 ms |
| RTT `mdev` | 7.17 ms | 5.60 ms |

Throughput is within a few percent on the aggregate and slightly lower on
single-stream. With zero errors, zero drops and a 1.19x spread there is no
radio loss for CUBIC to misread, so BBR has nothing to repair - the same
conclusion the razr 2024 produced. **It differs from the razr in one way: BBR
did not cost jitter here.** `mdev` came in slightly *below* the CUBIC pass
rather than eight times above it. The two runs are on different evenings, so
this is a weak comparison and not a finding about BBR.

**The fifth-case shape appeared again and is again not a per-flow limit.** A
1.19x spread with an aggregate 2.95x the single-stream mean is textbook
per-flow shaping, and the README forbids writing that down on a fast link
without checking the transfer size first. Interleaved 8 and 32 MB transfers,
the whole run spanning 2.94 s:

| transfer | result |
|---|---|
| 8 MB | 134.7 Mbps |
| 32 MB | **274.2 Mbps** |
| 8 MB | 121.3 Mbps |
| 32 MB | **273.8 Mbps** |

8 MB mean 128.0, 32 MB mean 274.0, a **2.14x ratio with no overlap** - the
worst 32 MB run beat the best 8 MB run - and each 32 MB transfer beat the 8 MB
transfer immediately beside it. This is the third independent confirmation of
the transfer-size effect and **the first under BBR**, which matters because the
previous two were both CUBIC and the effect could have been a CUBIC slow-start
artifact. It is not.

**One thing differs from the CUBIC runs and is worth flagging.** There, a
single 32 MB transfer reached essentially the whole 4-stream aggregate - 327
and 332 against 361, 351 against 371. Here 274 against 365 is only 0.75x, so
one long flow got much closer to the aggregate than the 8 MB transfer did but
did not match it. Two 32 MB samples is too thin to call that a BBR property,
and the 2.14x ratio here against 2.28x on the USB-C port is close enough that
the effect itself looks unchanged. Recorded as an observation, not a
conclusion.

## Issues

**Wi-Fi came back up mid-pass.** `wlo1` was downed before the transfers and
verified down, but NetworkManager restored it during the run. It did not
contaminate the measurement - the tether held the lower route metric
throughout, and the tether's own RX counter grew by 145.0 MB against roughly
136 MB of requested payload, which accounts for the entire pass. Anyone
repeating this should mask the connection rather than just downing the link,
or check the counters afterwards as was done here.

`carrier.network` is blank for the same structural reason as every iOS record
here. `carrier.name` was carried on the `2600:381::/32` delegation at test time
and has since been **operator-confirmed as AT&T and backfilled 2026-09-08**. It
is now independently corroborated too: a registry lookup of that /32 returns
**AT&T Enterprises, LLC, `NetName: ATTMOV6-1`** - AT&T's mobility v6
allocation. Earlier records here noted that "the prefix alone does not
establish it"; with the allocation actually checked rather than assumed it
very nearly does, and with the operator's confirmation alongside it this field
is no longer a weak point.
`usb.cable` was blank at test time - the phone was already connected when the
session began - and was **backfilled 2026-09-08** from the operator as an Anker
USB-C to USB-A USB 3.0 cable. It was not observed by the host, and it corrected
a wrong claim in Setup; see there.

## Follow-ups

- ~~Re-test the earlier SuperSpeed configuration to separate "the radio was bad
  that morning" from "that host port is bad".~~ **Done here.** The port is
  fine; the morning's 21.2 Mbps aggregate was not caused by it.
- ~~Confirm the cable with the operator and backfill the field.~~ **Done
  2026-09-08** - Anker USB-C to USB-A, USB 3.0, and it overturned the ceiling
  claim in Setup. `carrier.name` is still unconfirmed.
- The 32 MB single reached only 0.75x the aggregate under BBR where CUBIC
  reached 0.90-0.95x. Worth more than two samples if anyone wants to know
  whether that is real.
- Still nothing approaching the bus ceiling: 365 Mbps aggregate on a 5000 Mbps
  bus is 7% of it. `bus_speed_mbps` above 480 continues to have no measured
  consequence anywhere in this log - and note that the cable *did* bind the
  enumerated bus speed here while having no effect whatever on throughput.
