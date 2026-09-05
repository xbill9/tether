---
id: 2026-09-05-motorola-razr-2024-google-fi
date: 2026-09-05
phone:
  make: Motorola
  model: razr 2024
  os:                 # TODO not readable from the host - no adb, no MTP mount; needs Settings > About phone
carrier:
  name: Google Fi
  network:            # TODO not readable from the host - needs the phone's status bar / About phone
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

The caveat on the SuperSpeed finding: the descriptors read above are those of
the **tether function as currently enumerated** (`22b8:2e24`). A phone can
present different descriptors in other USB modes, so this rules out SuperSpeed
tethering, not SuperSpeed on the port in general.

## Follow-ups

- OS version and radio type, both readable only on the phone.
- Worth a second pass at a different time of day. This one caught an unusually
  clean radio - 2.1 ms mdev is the best in the log - so 104/117/140 may be a
  favourable sample rather than typical.
- The RNDIS-vs-NCM comparison is confounded: different phone, different radio
  conditions, possibly a different cable. It is suggestive that the tightest
  numbers here came from the RNDIS device, but nothing in this record isolates
  the driver as the cause.
- No CUBIC baseline exists for this phone. If the driver comparison matters,
  a CUBIC pass on the razr would show whether RNDIS is inherently steadier or
  whether this radio was simply better behaved.
