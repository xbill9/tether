---
id: 2026-09-05-motorola-razr-2024-google-fi
date: 2026-09-05
phone:
  make: Motorola
  model: razr 2024 (XT2453-3)
  os: Android 16      # operator-supplied, confirmed over adb (ro.build.version.release=16, sdk 36)
carrier:
  name: Google Fi     # confirmed over adb (gsm.operator.alpha)
  network: 5G (NR SA) # operator-supplied as 5G, refined over adb (gsm.network.type=NR_SA)
usb:
  vendor_id: "22b8"
  product_id: "2e24"
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - /sys/class/net/<if>/speed reads -1
  cable:              # TODO unverified - but see body, the tether function is USB 2.0 only regardless
link:
  interface: enx9ad117016371
  ipv4: 10.142.52.87/24
  gateway: 10.142.52.254
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [104, 117, 140]
  parallel_4_aggregate_mbps: 234
  rtt_ms:
    min: 35.0
    avg: 37.6
    max: 41.1
    mdev: 2.1
  errors: 0
  drops: 0
verdict: good
---

# Motorola razr 2024 on Google Fi - first RNDIS record

The log's first `rndis_host` measurement; every prior record is `cdc_ncm` on the
Pixel 9a. Host TCP config is unchanged from
[2026-09-05-pixel-9a-google-fi](2026-09-05-pixel-9a-google-fi.md) - still BBR,
`slow_start_after_idle=0`, `mtu_probing=1` - so the two are directly comparable
and the driver is the variable.

## Setup

Plugged in and came up on its own; NetworkManager DHCPed it through the same
generic `Wired connection 1` profile that adopted the Pixel, dual-stacked, and
made it the only default route. The Pixel was unplugged first, so there was no
ambiguity about which interface the transfers used.

The USB descriptor reports the product only as `motorola razr 2024`; the full
model number **XT2453-3** was supplied by the operator, not read from the
device. This is the US unlocked variant.

OS (Android 16) and radio (5G) were likewise read off the phone during the
session - neither is visible from the host over a tether-only USB function.

Bound to `rndis_host`, not NCM. Two consequences for this format:

- **There is no `ntb` block.** RNDIS has no NTB aggregation parameters, so the
  block is omitted rather than left blank, per the field reference.
- **`negotiated_link_mbps` is unavailable.** `rndis_host` does not report a link
  speed; `/sys/class/net/<if>/speed` reads `-1`. This is a property of the
  driver, not a failed reading, and it will be true of every RNDIS record.

The interface also sits at operstate `UNKNOWN` rather than `UP`. Normal for this
driver - the flags show `UP,LOWER_UP` and it carries traffic fine.

## Observations

**Single-stream was the tightest of any record so far:** 104 / 117 / 140 Mbps, a
1.34x spread, against 1.4x for the Pixel's best BBR pass and 7.8x for the CUBIC
baseline. The three runs also rose monotonically, which reads as ordinary
warm-up rather than the sawtooth of a window collapsing.

RTT confirms it. mdev came in at **2.1 ms**, the lowest in the log by a wide
margin (4.1 / 5.8 / 6.4 elsewhere), on a 35-41 ms range. This is the most stable
path measured here, and it is why the spread is tight: with little loss to
misread, congestion control has nothing to overreact to.

Aggregate was 234 Mbps against a best single of 140 - a 1.67x gap, narrower than
the Pixel's 2.1x and nowhere near the CUBIC record's 14x. Less local headroom
left to reclaim, because there is less being lost in the first place.

**On the bus, this phone's story differs sharply from the Pixel's.** 234 Mbps on
a 480 Mbps bus is about 78% of the realistic USB 2.0 bulk ceiling, so the bus is
plausibly binding here too. But the reason is different and it is not fixable:

    Pixel 9a:  bcdUSB 2.10, BOS descriptor present,
               wSpeedsSupported 0x000f - "can operate at SuperSpeed (5Gbps)"
    razr 2024: bcdUSB 2.00, no BOS descriptor, no SuperSpeed capability

The Pixel advertises SuperSpeed and connects at 480 anyway, which is why its
cable is worth chasing. **The razr's tether function does not advertise
SuperSpeed at all**, so 480 Mbps is the device's ceiling and no cable will move
it. That makes `usb.cable` moot for this phone rather than merely unverified.

Zero errors and zero drops across roughly 42k RX / 20k TX packets in the test
window.

Incidental: traceroute distance differs from the Pixel runs - `ttl=53` on the
returning pings against `ttl=55` there, i.e. two more hops. Same carrier and the
same 2607:fb90::/32 T-Mobile prefix family, so this is likely a different
egress or a different radio site, not a different network.

## Issues

None. Nothing had to be done to bring it up.

The caveat on the SuperSpeed finding was that the descriptors read above are
those of the **tether function as enumerated during the test** (`22b8:2e24`),
and a phone can present different descriptors in other USB modes - so it ruled
out SuperSpeed tethering, not SuperSpeed on the port in general.

**Partly settled afterwards.** Enabling USB debugging moved the phone to a
second USB configuration, RNDIS+ADB composite at `22b8:2e25`, and that one is
also `bcdUSB 2.00` with no BOS descriptor and no SuperSpeed capability. Two
independent configurations agreeing makes it very likely the razr's USB port is
USB 2.0 only, rather than this being an artefact of the tether function. Not
proof - other modes exist - but the remaining doubt is small.

## Post-test: metadata confirmed over adb

`adb` was installed later the same day and this phone authorised, which allowed
the operator-supplied values to be checked against the device rather than taken
on trust. All of them held:

    ro.build.version.release  16                -> os: Android 16
    gsm.network.type          Unknown,NR_SA     -> network: 5G, refined to NR SA
    gsm.operator.alpha        ,Google Fi        -> carrier: Google Fi
    ro.product.model          motorola razr 2024

`network` has been refined from `5G` to `5G (NR SA)` - standalone 5G, not
non-standalone riding an LTE anchor - which is a meaningful distinction for
latency and was not knowable when the record was written. The model number
`XT2453-3` remains operator-supplied: `ro.product.model` carries the marketing
name only.

No measurement changed. These properties were read after the pass, not during
it; the interface, MAC, address and default route were all unchanged across the
USB debugging toggle, so the connection under test was not disturbed.

## Follow-ups

- Worth a second pass at a different time of day. This one caught an unusually
  clean radio - 2.1 ms mdev is the best in the log - so 104/117/140 may be a
  favourable sample rather than typical.
- The RNDIS-vs-NCM comparison is confounded: different phone, different radio
  conditions, possibly a different cable. It is suggestive that the tightest
  numbers here came from the RNDIS device, but nothing in this record isolates
  the driver as the cause. This phone is now confirmed to have been on **5G
  standalone**, while the radio the Pixel used was never recorded - so the two
  cannot be assumed to have been on comparable radios either.
- ~~No CUBIC baseline exists for this phone.~~ Done - see
  [2026-09-05-motorola-razr-2024-google-fi-cubic](2026-09-05-motorola-razr-2024-google-fi-cubic.md),
  which changed congestion control alone. CUBIC was **faster** here (mean 140
  against 120) with an identical 1.34x spread, but jitter went from 2.1 ms to
  16.5 ms mdev. The steadiness in this record is BBR's doing, not RNDIS's.
