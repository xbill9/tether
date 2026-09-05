---
id: 2026-09-05-galaxy-z-flip5-google-fi
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy Z Flip5 (SM-F731U1)
  os: Android 16      # build BP4A.251205.006.F731U1UES8GZG3, read over adb
carrier:
  name: Google Fi     # both gsm.operator.alpha and gsm.sim.operator.alpha returned "Google Fi"
  network: 5G (NR SA) # read DURING the pass - gsm.network.type=NR_SA before and after, agreeing
usb:
  vendor_id: "04e8"
  product_id: "6864"  # with USB debugging enabled throughout; see body
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - /sys/class/net/<if>/speed reads -1
  cable:              # TODO unverified - phone advertises SuperSpeed and still enumerated at 480
link:
  interface: enxde5b627dd64d
  ipv4: 10.187.171.59/24
  gateway: 10.187.171.225
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [99, 111, 112]
  parallel_4_aggregate_mbps: 237
  rtt_ms:
    min: 25.8
    avg: 42.0
    max: 58.5
    mdev: 12.1
  errors: 6           # first non-zero in the log - see Observations, no pre-pass baseline was taken
  drops: 0
verdict: good
---

# Samsung Galaxy Z Flip5 on Google Fi - the flattest single-stream in the log, and the first non-zero error count

Two things make this record worth reading past the throughput numbers: the
single-stream spread is the tightest of any Google Fi record here, and the
interface reported **six RX errors** where every one of the previous seventeen
records reported zero.

## Setup

Came up on its own, dual-stacked, sole default route. `wlo1` was down and
`docker0` had no carrier, so the tether was the only route-capable link for the
whole pass - confirmed before the transfers and again after.

`rndis_host`, so no `ntb` block and no `negotiated_link_mbps`:
`/sys/class/net/<if>/speed` reads `-1` and the interface sits at operstate
`UNKNOWN`. Both are normal for this driver and neither is a failed reading.

USB debugging was already enabled and authorised when the phone was plugged in,
and stayed on for the transfers, so `04e8:6864` is genuinely the configuration
that was measured. That is the same ID the Flip6 showed with adb *off* and the
S25 showed with adb *on*. Three Samsung handsets, two adb states, one product
ID - the S25 record called this "a hint and not a finding", and it is now a
hint with a third observation behind it, still from different handsets rather
than one handset toggled.

**The dual-SIM slot ordering is not fixed.** This phone returned
`NR_SA,Unknown` - populated slot first - while the S25 returned
`Unknown,NR_SA`. Same carrier, same property, opposite positions. Reading a
fixed field out of that comma-separated string would have recorded this phone's
radio as the S25's idle slot.

## Observations

**Single-stream was 99 / 111 / 112 Mbps - a 1.13x spread**, the flattest of any
Google Fi record here and second only to the AT&T Pixel's 1.06x across the whole
log. Two consecutive transfers landing within 1 Mbps of each other is not
something any other Samsung in this log has done: the S25 spread 1.84x, the
Flip6 1.19x, the two S24 units 1.15x and 1.27x.

Aggregate reached 237 Mbps, **2.12x the best single stream**. Under the README's
rubric that combination - near-flat spread with aggregate far above it - is the
fifth case: a **per-flow limit**, either carrier shaping or one flow unable to
fill the bandwidth-delay product. This is the second sighting of that shape,
after the AT&T Pixel 9a (1.06x spread, aggregate 2.6x best single), and **the
first on Google Fi**, which weakens the reading that it was something specific
to AT&T.

One caveat on that diagnosis, which the rubric does not cover. The fifth case
assumes the aggregate shows real headroom. But 237 Mbps sits inside the
221-238 Mbps band that every `rndis_host` device in this log has landed in
(razr plus 221, S24 230, Flip6 232, razr 2024 234/238, S25 238), and only the
`cdc_ncm` Pixels have ever gone past it, at 246 and 273. So the aggregate here
may be a bus or driver ceiling rather than evidence of spare WAN capacity.
**What is safe to say is that a single flow stops reproducibly at ~110 Mbps
while four together reach at least 237** - the per-flow limit is real; whether
the WAN above it has more to give is not established by this pass.

The four parallel streams shared unevenly at 68 / 64 / 55 / 49 Mbps, 1.39x
max:min - fairer than the S25's 1.44x but not by much.

**RTT is the worst of any Google Fi record here**: 42.0 ms average against a
22.0-38.3 ms range across the other nine, with `mdev` at 12.1 ms against a
1.8-8.8 ms range. Both moved together, so this is *not* the bufferbloat
signature the README describes - that case is high `mdev` with the average
unchanged, as the razr's CUBIC pass showed (16.5 ms `mdev`, average flat at
37.7). Average and jitter rising together points at the path or the radio at
test time rather than at queueing on this host. This pass ran late in the
session, and the AT&T records in this log document a carrier-side dip and
recovery over the same afternoon, so time-of-day is a live confound here and
one pass cannot separate it from something about this handset.

**Six RX errors over 44,433 RX packets**, against zero in all seventeen earlier
records. Two things bound how much that is worth:

- It is a rate of 0.013%, and `drops`, `carrier` and `collsns` were all zero.
- **No pre-pass baseline was taken.** The interface was already up and carrying
  traffic when the pass started. Total RX was 59.7 MB against roughly 56 MB of
  transfers, so most of the counter is this pass - but the earlier few MB cannot
  be excluded as the source of all six.

The README reads non-zero errors as pointing at cable or power rather than
config. That is consistent with this host's unresolved USB situation, but six
errors is far too thin to carry the claim on its own.

## Issues

None that affected the run. The error count above is recorded as an observation,
not a fault - nothing failed and no transfer was retried.

## Follow-ups

- **Re-run this handset to separate the latency finding from time-of-day.** The
  42.0 ms average and 12.1 ms `mdev` are the worst on Google Fi in this log, but
  the pass ran late in a session where AT&T was independently observed dipping
  and recovering. A morning pass on this phone costs one full pass and settles
  it.
- **Take a baseline `ip -s link` reading before the transfers, on every future
  pass.** This record cannot attribute its six RX errors to the pass because no
  before-reading exists. That is a cheap fix and it applies to the whole
  methodology, not just this phone - worth folding into the skill.
- **The seventh SuperSpeed-capable phone to enumerate at 480.** The BOS
  descriptor advertises `Device can operate at SuperSpeed (5Gbps)` and `bcdUSB
  2.10`, and it came up on `3-1` - a port on the 480 Mbps `usb3` root hub -
  while `usb2` (20 Gb/s) and `usb4` (10 Gb/s) sit idle and have never had a
  device attached. This adds a seventh data point to a question that seven data
  points have not moved. The USB 3 flash drive test already at the top of the
  "To test" list remains the only pending experiment that removes the cable
  variable instead of repeating it.
- A CUBIC pass on this handset would pair with the S25 as a second
  shipping-OS driver comparison, and the flat BBR spread here makes it an
  unusually clean baseline to compare against.
