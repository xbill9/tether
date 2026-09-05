---
id: 2026-09-05-galaxy-s25-google-fi
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy S25 (SM-S931U1)
  os: Android 16      # shipping build BP4A.251205.006, read over adb
carrier:
  name: Google Fi     # confirmed over adb (gsm.operator.alpha)
  network: 5G (NR SA) # read DURING the pass - gsm.network.type=NR_SA before and after, agreeing
usb:
  vendor_id: "04e8"
  product_id: "6864"  # with USB debugging enabled throughout; see body
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - /sys/class/net/<if>/speed reads -1
  cable:              # TODO unverified - phone advertises SuperSpeed and still enumerated at 480
link:
  interface: enx7e778a30707b
  ipv4: 10.223.144.154/24
  gateway: 10.223.144.14
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [70, 112, 61]
  parallel_4_aggregate_mbps: 238
  rtt_ms:
    min: 27.8
    avg: 31.4
    max: 37.4
    mdev: 3.3
  errors: 0
  drops: 0
verdict: good
---

# Samsung Galaxy S25 on Google Fi - the first record with the radio actually pinned down

Two firsts here, and both are about the method rather than the numbers.

**`carrier.network` is trustworthy for the first time.** Every earlier record
either left it blank or took it from a human reading a status bar. Here
`gsm.network.type` was read over adb immediately before the transfers and again
immediately after, and both returned `NR_SA`:

    before:  Unknown,NR_SA
    after:   Unknown,NR_SA

Agreeing readings on either side of the pass are what the field was always
supposed to mean. Four other records still have it blank precisely because that
was not done, and the AT&T Pixel shows why it matters - reported as 5G at test
time, read as `LTE` afterwards, now unresolvable.

**This is also the only phone in the log on a shipping OS.** Android 16, build
`BP4A.251205.006`. Both Pixel 9a units run an Android 17 beta
(`CP41.260814.003.B1`), so anything they do could be an artefact of a
pre-release network stack. This one cannot be.

## Setup

Came up on its own through the same generic `Wired connection 1` profile,
dual-stacked, sole default route. USB debugging was already enabled and
authorised when it was plugged in.

`rndis_host`, the third such record after the razr 2024 and the Flip6, so no
`ntb` block and no `negotiated_link_mbps` - `/sys/class/net/<if>/speed` reads
`-1`, and the interface sits at operstate `UNKNOWN`. Both are normal for this
driver.

**USB debugging was on for the whole session, including the transfers**, so
`04e8:6864` is genuinely the configuration that was measured. Worth recording
because Google and Motorola both shift product ID when adb is enabled -
`18d1:4eeb` to `4eec`, `22b8:2e24` to `2e25` - while this phone shows the same
`6864` the Flip6 showed with adb *off*. That hints Samsung uses one ID for both
configurations, but the two observations are from different handsets in
different states, so it is a hint and not a finding.

## Observations

Single-stream was 70 / 112 / 61 Mbps, a **1.84x spread - the widest of any
BBR-era record here** (the Flip6 managed 1.19x, the AT&T Pixel 1.06x).

The README's rubric would read a wide spread with flat RTT as congestion control
collapsing on radio loss, but that diagnosis does not fit and should not be
applied:

- The host is already on **BBR**, which is the fix that rubric points to. The
  CUBIC baseline it was written from showed 7.8x; this is 1.84x.
- RTT was **flat and clean** - 31.4 ms average, 3.3 ms mdev, no loss.
- The four parallel streams shared the link **evenly** (66 / 65 / 60 / 46 Mbps,
  1.44x max:min - second fairest in the log after the Flip6). A host-side
  congestion problem does not produce fair sharing.

What is left is ordinary radio variance on 5G NR standalone, which is exactly
the kind of burstiness a single sample of three transfers will catch. The
shape is close to the Google Fi Pixel's 114 / 116 / 63 at 1.8x, also on Fi, and
that record was likewise not a congestion-control failure.

Aggregate reached 238 Mbps, about 79% of the realistic USB 2.0 bulk ceiling, and
2.1x the best single. Mid-pack: the AT&T Pixel hit 273, the Flip6 232.

Zero errors and zero drops across roughly 42k RX / 20k TX packets.

## Issues

None.

## Follow-ups

- **The fourth SuperSpeed-capable phone to enumerate at 480.** The count now
  stands at four capable devices across three vendors, plus the razr which is
  genuinely USB 2.0 only, and nothing on this host has ever trained SuperSpeed
  on any bus. The circumstantial case for a **host port** problem rather than a
  cable is now about as strong as it can get without testing a known-good USB 3
  cable, which remains the highest-value experiment in this repo.
- A CUBIC baseline on this phone would be the cleanest driver comparison in the
  log: it is the only handset here on a shipping OS, and its radio type is the
  only one actually established at test time.
- The 1.84x spread deserves a second pass. With RTT flat, fair parallel sharing
  and BBR already in place, radio variance is the explanation that fits, but
  three transfers is a thin basis for it.
