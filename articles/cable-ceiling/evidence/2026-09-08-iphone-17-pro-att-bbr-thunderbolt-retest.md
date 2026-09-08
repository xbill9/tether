---
id: 2026-09-08-iphone-17-pro-att-bbr-thunderbolt-retest
date: 2026-09-08
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)   # read over usbmuxd (ideviceinfo); corroborated by bcdDevice=18.01
  os: iOS 27.0                        # read over usbmuxd (ideviceinfo -k ProductVersion)
carrier:
  name: AT&T         # operator-confirmed 2026-09-08; corroborated - 2600:381::/32 is registered to AT&T Enterprises, LLC, NetName ATTMOV6-1
  network:           # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 10000
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "Thunderbolt, USB-C to USB-C"   # operator-supplied; unchanged from the pass this supersedes
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
  single_stream_mbps: [100.848, 127.493, 91.988]
  parallel_4_aggregate_mbps: 317.250   # closing test, the log's standard position; an opening one gave 317.069 - see Observations
  rtt_ms:
    min: 28.309
    avg: 31.314
    max: 38.423
    mdev: 3.810
  errors: 0   # RX+TX delta across the pass; all cumulative counters 0 -> 0
  drops: 0    # RX+TX delta across the pass; all cumulative counters 0 -> 0
verdict: good
---

# iPhone 17 Pro on AT&T - the stable Thunderbolt retest, and the parallel-first question answered

A repeat of the
[Thunderbolt BBR pass](2026-09-08-iphone-17-pro-att-bbr-thunderbolt.md) taken
earlier the same day, whose link decayed while it was being measured. Nothing
changed but the passage of time: same handset, same port, same Thunderbolt
cable, same DHCP lease, same `bbr` settings.

**It answers two open questions and it does not supersede the earlier record**,
which remains the log's only captured instance of a link degrading mid-pass and
is worth keeping for exactly that.

## Setup

Measured 2026-09-08, after the link had been left idle. The phone was still at
`2-1` on `0000:00:0d.0` / `usb2` - the Thunderbolt 4 controller - at **10000**,
`ipheth` bound as `enxb65575abcda3` on the unchanged `172.20.10.5/28` lease.
`ideviceinfo` returned `iPhone18,1` / `27.0` before and after, bus still 10000
afterwards. Wi-Fi was disabled at the radio (`nmcli radio wifi off`) and the
tether was the only default route throughout. RX grew **221.8 MB** against
roughly 208 MB of requested payload, accounting for every transfer.

**The pass was deliberately bracketed by two parallel-4 tests** - one before the
singles and one after - to settle the standing `INDEX.md` item asking for the
parallel test to be run first, once. The frontmatter carries the **closing**
figure, which sits in the same position as every other record in this log, so
comparability is unaffected. The opening figure is reported below as the probe
it was.

## Observations

Single-stream ran **100.8 / 127.5 / 92.0 Mbps**, a 1.386x spread around a
106.8 Mbps mean. Parallel-4 aggregated **317.3 Mbps**. RTT averaged 31.3 ms
with `mdev` **3.81**.

**The two bracketing aggregates agree to 0.06%.**

| parallel-4 | result |
|---|---|
| opening, before the singles | 317.069 Mbps |
| closing, after the singles | **317.250 Mbps** |

**That answers the parallel-first item, and the answer is that the ordering is
not a systematic confound.** The log's universal singles-then-parallel order
does not bias the aggregate on a stable link - measured first or last, this one
landed on the same number to four significant figures. What the earlier pass
showed is therefore narrower than it looked: the ordering distorts a record
*only when the link is decaying*, in which case the aggregate is penalised
simply for being last. It is a real hazard, but a conditional one, and it has a
cheap detector - bracket the pass, and if the two aggregates disagree the
record is contaminated.

**The earlier pass was understated, as predicted.** Against it:

| | earlier (decaying) | this retest (stable) |
|---|---|---|
| parallel-4 | 282.496 Mbps | **317.250 Mbps** |
| RTT avg | 36.516 ms | 31.314 ms |
| RTT `mdev` | 8.159 ms | **3.810 ms** |
| single mean | 123.578 Mbps | 106.776 Mbps |
| single spread | 1.12x | 1.386x |

The aggregate is **12.3% higher** and `mdev` less than half, which is the
signature of a link that has settled. The follow-up written on that record -
that its 282.5 was "very likely understated" - holds.

**Single-stream went the other way, and that does not fit a README case.** The
mean fell from 123.6 to 106.8 while the spread widened from 1.12x to 1.386x,
even as the aggregate rose and jitter halved. A link that is steadier by every
latency measure and better in aggregate produced *worse and more variable*
single-stream numbers. The README's five cases do not cover this and it is
recorded rather than forced: the first case (wide spread, flat RTT) is the
closest shape, but that case is congestion control misreading radio loss, and
this ran under BBR with zero errors and zero drops. Three samples is also thin
for a spread claim.

**The transfer-size effect is confirmed cleanly, on a link now proven stable.**
The previous pass's interleaved test returned 1.05x with the sets overlapping
and was written off as uncontrolled, because its two 32 MB transfers disagreed
with each other by 1.31x. Repeated here with three pairs across 4.60 s:

| transfer | result |
|---|---|
| 8 MB | 119.780 Mbps |
| 32 MB | **257.458 Mbps** |
| 8 MB | 123.876 Mbps |
| 32 MB | **274.329 Mbps** |
| 8 MB | 111.637 Mbps |
| 32 MB | **270.739 Mbps** |

8 MB mean **118.431**, 32 MB mean **267.509**, a **2.26x ratio with no overlap**
- best 8 MB 123.876 against worst 32 MB 257.458 - and every 32 MB run beat the
8 MB run beside it. The 32 MB set is tight at 1.066x, against 1.31x last time,
which is the direct evidence that the link is behaving and the earlier null was
instability rather than absence of the effect.

That makes **four clean confirmations** of the size effect and one contaminated
null:

| pass | CC | ratio |
|---|---|---|
| 09-06 USB-C port | cubic | 2.28x |
| 09-08 usb4 | bbr | 2.14x |
| 09-08 TB4 (decaying) | bbr | *1.05x - uncontrolled* |
| 09-08 TB4 retest | bbr | **2.26x** |

The three controlled figures sit within 7% of each other across two congestion
control algorithms and two host ports. **The effect is a property of the
transfer size, not of the port, the cable or the congestion control** - and the
mechanism named in the README, a startup cost larger than textbook slow-start
accounts for, remains the open question.

**The bus remains irrelevant.** 317 Mbps on a 10000 Mbps bus is **3.2%** of it.

## Issues

None. Zero errors and zero drops across all seventeen transfers, no interface
bounce, no route change, and the bracketing aggregates agree, so nothing in
this pass is contaminated.

`carrier.network` is blank for the usual structural reason on iOS.

## Follow-ups

- ~~Re-run this port when the link is stable.~~ **Done - this record.** The
  earlier aggregate was understated by 12.3%.
- ~~Run the parallel test before the singles, once.~~ **Done here, bracketed.**
  Ordering does not bias the aggregate on a stable link; it only distorts a
  decaying one. **Worth adopting the bracket as standard**: a second
  parallel-4 costs 32 MB and turns "was this link stable?" from a judgement
  call into a measurement.
- **Why did single-stream get worse while everything else got better?** Mean
  down 14%, spread up from 1.12x to 1.386x, against a higher aggregate and
  half the jitter. Unexplained, and three samples is thin - worth more runs
  before it is treated as real.
- The startup-cost question is untouched by this pass and still open.
