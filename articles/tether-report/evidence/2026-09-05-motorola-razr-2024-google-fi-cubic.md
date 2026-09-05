---
id: 2026-09-05-motorola-razr-2024-google-fi-cubic
date: 2026-09-05
phone:
  make: Motorola
  model: razr 2024 (XT2453-3)
  os: Android 16      # confirmed over adb (ro.build.version.release=16, sdk 36)
carrier:
  name: Google Fi     # confirmed over adb (gsm.operator.alpha)
  network: 5G (NR SA) # read DURING the pass - gsm.network.type=NR_SA before and after, agreeing
usb:
  vendor_id: "22b8"
  product_id: "2e25"  # RNDIS+ADB composite; the BBR record measured 2e24, with adb off
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - reads -1
  cable:              # TODO unverified - moot, this phone advertises no SuperSpeed
link:
  interface: enx9ad117016371
  ipv4: 10.142.52.87/24
  gateway: 10.142.52.254
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: cubic
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [135, 121, 163]
  parallel_4_aggregate_mbps: 238
  rtt_ms:
    min: 15.7
    avg: 37.7
    max: 59.6
    mdev: 16.5
  errors: 0
  drops: 0
verdict: usable
---

# razr 2024 under CUBIC - faster, and much worse

A controlled re-test of
[2026-09-05-motorola-razr-2024-google-fi](2026-09-05-motorola-razr-2024-google-fi.md).
**Exactly one variable changed**: `tcp_congestion_control` from `bbr` to
`cubic`. `slow_start_after_idle=0` and `mtu_probing=1` were deliberately left
alone, so this is not a repeat of the as-shipped configuration in
[2026-09-05-pixel-9a-cubic](2026-09-05-pixel-9a-cubic.md), which also had
`slow_start_after_idle=1` and `mtu_probing=0`. Same phone, same cable, same
interface and DHCP lease, same day, radio confirmed `NR_SA` on both sides of the
pass.

The change was made at runtime only; `/etc/sysctl.d/99-tether.conf` still
specifies `bbr`, and `bbr` was restored immediately after the pass.

## Setup

Nothing to bring up - the razr was reattached and came back on the same
interface and lease it used for the BBR pass. WiFi was down and the tether was
the sole default route throughout.

One difference from the BBR record: USB debugging is now enabled, so the phone
enumerates as `22b8:2e25` rather than the `2e24` measured before. That is a
different USB configuration, and it is recorded as such rather than copied
across. Both configurations advertise no SuperSpeed, so the 480 Mbps bus is
unchanged and the difference is not expected to matter for throughput.

## Observations

**CUBIC was the faster of the two, and this inverts the finding the repo was
built on:**

    bbr     104 / 117 / 140   mean 120   spread 1.34x   par-4 234   mdev  2.1 ms
    cubic   135 / 121 / 163   mean 140   spread 1.34x   par-4 238   mdev 16.5 ms

Single-stream mean rose 16% under CUBIC, and its 163 Mbps peak is the highest
single-stream figure anywhere in this log - above the 153 Mbps the Pixel 9a
managed under BBR. The spread was **identical at 1.34x**. There is no sign here
of the window collapse that the Pixel's CUBIC baseline showed at 7.8x, and
nothing that would justify calling CUBIC broken on this link.

Aggregate was 238 against 234, within 2%. Both sit near 78% of the realistic
USB 2.0 bulk ceiling, so that number is measuring the bus in both runs and
cannot separate the two.

**The cost shows up entirely in latency.** RTT mdev went from 2.1 ms to
**16.5 ms**, an eightfold increase, with the range widening from 35-41 ms to
15.7-59.6 ms:

    bbr     min 35.0  avg 37.6  max 41.1  mdev  2.1
    cubic   min 15.7  avg 37.7  max 59.6  mdev 16.5

Average RTT is unchanged - 37.6 against 37.7 - which is exactly why the average
is the wrong number to look at. The pings were taken in the same position in
both passes, immediately after the four-stream test, so this is like for like.
Per the README, rising `mdev` under load is bufferbloat: CUBIC is filling the
queue to find the limit, and the extra throughput is bought out of buffer depth.

**This is the BBR trade-off working as designed**, in the direction the theory
predicts and the repo had not yet observed. BBR models bandwidth and RTT instead
of probing until loss, so it leaves throughput on the table on a link that is
not actually lossy - and returns a path steady enough to use interactively. The
razr's BBR pass produced the lowest jitter in the log at the time; its CUBIC
pass produces the highest.

**Why this differs from the Pixel.** The Pixel's CUBIC baseline collapsed
because its radio was dropping packets and CUBIC read that loss as congestion.
This radio is clean - zero packet loss across every ping in both passes - so
CUBIC has nothing to misread and behaves the way it does on a wired link: fast,
and queue-hungry. **The lesson is that "BBR is faster" was never the finding.
The finding is that BBR is more robust to radio loss.** Where there is no loss,
CUBIC wins on throughput and loses on latency.

Zero errors and zero drops across roughly 43k RX / 20k TX packets.

## Issues

None.

`verdict` is `usable` rather than `good` despite the best single-stream numbers
in the log. 16.5 ms of jitter is poor for anything interactive, and a tether
that is fast for bulk transfer but unsteady under load is worse in practice than
the slightly slower, steady configuration it replaced.

## Follow-ups

- **The README's rubric and rule 3 want revisiting.** Rule 3 says congestion
  control changes results by 7x, which came from the Pixel. Here it changed
  single-stream by 16% and jitter by 8x, in the opposite direction. Both are
  true; the rule as written implies only the first.
- A second CUBIC pass would confirm the jitter result is not a one-off. The
  throughput difference is small enough to be radio variance - the S24/S25 pair
  showed within-phone variance of that size - but an eightfold jitter change is
  not.
- Still untested on this phone: whether `slow_start_after_idle` and
  `mtu_probing` contribute anything. This pass isolated congestion control
  alone; the Pixel's CUBIC baseline moved all three at once.
