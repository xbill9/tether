---
id: 2026-09-05-galaxy-s24-google-fi-lte
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy S24 (SM-S921U1)
  os: Android 16      # shipping build BP4A.251205.006, patch 2026-07-05, read over adb
carrier:
  name: Google Fi     # confirmed over adb; see Issues on the two operator strings
  network: LTE        # read DURING the pass - gsm.network.type=LTE before and after, agreeing
usb:
  vendor_id: "04e8"
  product_id: "6864"  # with USB debugging enabled throughout
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - reads -1
  cable:              # TODO unverified - phone advertises SuperSpeed and still enumerated at 480
link:
  interface: enxca69aa2b83f8
  ipv4: 10.79.117.131/24
  gateway: 10.79.117.191
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [115, 113, 143]
  parallel_4_aggregate_mbps: 263
  rtt_ms:
    min: 15.9
    avg: 22.0
    max: 26.7
    mdev: 3.8
  errors: 0
  drops: 0
verdict: good
---

# Galaxy S24 on LTE - the radio label does not predict performance

A **second, physically distinct Galaxy S24** - confirmed distinct by USB serial,
which differs from the first unit's. Serials are deliberately not recorded in
this log. Against
[2026-09-05-galaxy-s24-google-fi](2026-09-05-galaxy-s24-google-fi.md) this holds
constant everything the log records except one field:

    identical:  SM-S921U1, Android 16 BP4A.251205.006, patch 2026-07-05,
                Google Fi, rndis_host, bbr / ssai=0 / mtu_probing=1, 2026-09-05
    differs:    gsm.network.type = LTE   (the first S24 ran on NR_SA)

Same model, same build, same patch, same carrier, same driver, same host, same
day. **This is the closest the log gets to isolating the radio access
technology.**

## Setup

Came up on its own, sole default route, WiFi down throughout. `rndis_host`, so
no `ntb` block and no `negotiated_link_mbps`. adb was already authorised, so no
tether bounce this time - unlike the first S24, where accepting the prompt
recreated the interface.

Radio was read before and after the transfers, `LTE` both times.

## Observations

**LTE beat 5G standalone on every single measure:**

    S24 #1  NR_SA   98 / 112 / 113   mean 108   par-4 230   RTT 36.4 ms  mdev 3.6
    S24 #2  LTE    115 / 113 / 143   mean 124   par-4 263   RTT 22.0 ms  mdev 3.8

Single-stream mean is 15% higher, aggregate 14% higher, and **RTT is 14.4 ms
lower - 22.0 ms is the lowest average in the entire log**, beating the Flip6's
23.0 ms. Jitter is unchanged at 3.8 against 3.6 ms.

The latency result is the one that matters, because it is the opposite of what
the technology promises. 5G standalone is supposed to cut round-trip time
relative to LTE; here it added 14 ms. That points away from the air interface
and toward everything behind it - cell loading, backhaul, and where each session
egressed - none of which the radio label captures.

**What this does and does not show.** It is not evidence that LTE is faster than
5G. It is evidence that **`carrier.network` does not predict throughput or
latency**, and that a well-provisioned LTE cell can comfortably beat a 5G SA
cell on the same carrier. Two confounds remain and cannot be removed from a
single pass: these are different physical handsets, and the two passes ran at
different times, so cell load and site differ.

Read alongside the S24/S25 pair, the log now has two matched comparisons
pointing the same way: **the between-configuration differences it can measure
are smaller than the variance between passes.** The one exception so far is
congestion control on a clean radio, where the razr's CUBIC pass moved jitter
eightfold - a change large enough to survive the noise.

Aggregate at 263 Mbps is the second highest recorded, about 88% of the realistic
USB 2.0 bulk ceiling, so the bus is again close to binding. The four parallel
streams shared at 1.69x max:min (83 / 70 / 61 / 49 Mbps) - less even than the
first S24's 1.22x.

Zero errors and zero drops across roughly 46k RX / 23k TX packets.

## Issues

**The two carrier properties disagree, and the skill points at the wrong one:**

    gsm.operator.alpha      Project Fi
    gsm.sim.operator.alpha  Google Fi

`Project Fi` is the service's former name. The skill currently cites
`gsm.operator.alpha` as the corroborating property; on this handset it returns a
brand retired years ago, while `gsm.sim.operator.alpha` returns the current one.
Both identify the same carrier, so nothing here is ambiguous, but a reader
matching strings mechanically would not match them. `carrier.name` is recorded
as **Google Fi**.

## Follow-ups

- **Re-run both S24 units back to back at the same moment.** That removes the
  time-of-day confound and would settle whether the LTE advantage is the cell or
  the sample. It is the single most informative pass left that costs only data.
- Better still, force one handset between LTE and 5G and re-test on the same
  unit. That removes the last confound entirely.
- Sixth SuperSpeed-capable phone to enumerate at 480. The cable remains the
  prime suspect after two USB-C ports produced identical results.
