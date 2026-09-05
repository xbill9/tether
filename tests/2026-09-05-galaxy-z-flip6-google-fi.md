---
id: 2026-09-05-galaxy-z-flip6-google-fi
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy Z Flip6 (SM-F741U1)
  os: Android 16      # read over adb (ro.build.version.release=16, sdk 36)
carrier:
  name: Google Fi     # operator-supplied, later corroborated over adb - see Issues
  network: 5G (NR SA) # read over adb (gsm.network.type=NR_SA)
usb:
  vendor_id: "04e8"
  product_id: "6864"
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - /sys/class/net/<if>/speed reads -1
  cable:              # TODO unverified - see body, this phone advertises SuperSpeed and still enumerated at 480
link:
  interface: enxb6077bbc1eca
  ipv4: 10.219.200.220/24
  gateway: 10.219.200.148
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [102, 121, 113]
  parallel_4_aggregate_mbps: 232
  rtt_ms:
    min: 21.1
    avg: 23.0
    max: 25.6
    mdev: 1.8
  errors: 0
  drops: 0
verdict: good
---

# Samsung Galaxy Z Flip6 - the cleanest path in the log

Second `rndis_host` record, after
[2026-09-05-motorola-razr-2024-google-fi](2026-09-05-motorola-razr-2024-google-fi.md).
Host TCP config unchanged from every record since
[2026-09-05-pixel-9a-bbr](2026-09-05-pixel-9a-bbr.md) - BBR,
`slow_start_after_idle=0`, `mtu_probing=1`.

## Setup

Came up on its own via the same generic `Wired connection 1` profile,
dual-stacked, sole default route. The AT&T Pixel was unplugged first.

The USB product string is just `SAMSUNG_Android` on the generic Samsung tether
ID `04e8:6864`; **the model is not readable from the host** and was supplied by
the operator. Expect this of Samsung devices - unlike Google and Motorola, which
both put the marketing name in the descriptor.

`rndis_host` again, so as with the razr there is no `ntb` block and
`negotiated_link_mbps` is unavailable (`/sys/class/net/<if>/speed` reads `-1`).

## Observations

**This is the best-behaved path measured here.** RTT averaged 23.0 ms with 1.8 ms
mdev - both the lowest in the log, against a previous best of 29.6 ms average and
2.1 ms mdev. Nothing else has come close on either figure.

**The four parallel streams shared the link almost evenly**, which no previous
record managed:

    Galaxy Z Flip6   65 / 61 / 56 / 49 Mbps    max:min = 1.3x
    Pixel 9a (AT&T)  94 / 73 / 67 / 39 Mbps    max:min = 2.4x
    razr 2024        94 / 77 / 51 / 11 Mbps    max:min = 8.3x
    Pixel 9a (Fi)    81 / 79 / 78 /  9 Mbps    max:min = 9.5x

In every earlier parallel test one stream was starved while the others ran. Here
the slowest stream still carried 75% of what the fastest did. Taken with the
1.8 ms mdev, this reads as a link with genuine spare capacity and no queue to
fight over, rather than four flows competing for a saturated pipe.

Single-stream was 102 / 121 / 113 Mbps, a 1.19x spread - second tightest after
the AT&T Pixel's 1.06x, and comfortably in the range where congestion control is
not the story.

Throughput itself is unremarkable: 232 Mbps aggregate is the lowest of the four
BBR-era records (273, 246, 234, 232), and about 77% of the realistic USB 2.0
bulk ceiling. The interesting result here is the latency and the fairness, not
the bandwidth.

Zero errors and zero drops across roughly 42k RX / 19k TX packets.

## Issues

**The carrier could not be determined from the host**, and this is worth
recording as a limit of the method rather than a one-off. The host sees an IPv6
delegation in 2607:fb90::/32, which is T-Mobile space - but that is equally
consistent with T-Mobile proper, Google Fi, or any T-Mobile MVNO. Google Fi
rides T-Mobile and produced 2607:fb90 and 2607:fb91 prefixes in earlier records,
so the prefix cannot separate them even in principle.

`carrier.name` was left blank at write time and backfilled on 2026-09-05 from
the operator, who confirmed **Google Fi**. Recorded here rather than silently
filled so that it is not mistaken for something the host observed. No
measurement changed.

**`adb` was then installed and this phone authorised**, which resolved the rest
and corrected the assumption above in one useful way: `gsm.operator.alpha`
reports `Google Fi` outright, so the radio *does* name the MVNO even though its
IPv6 delegation is indistinguishable from T-Mobile's. Backfilled from it:
`ro.build.version.release=16`, `gsm.network.type=Unknown,NR_SA` (dual-SIM, so
one entry per slot - slot 2 on 5G standalone), and the true model `SM-F741U1`,
which the USB descriptor never carried.

These were read immediately after the measurement pass, not before it, because
adb was not yet installed when the transfers ran. The connection was unchanged
throughout.

## Follow-ups

- **The USB ceiling evidence has moved.** This phone advertises SuperSpeed in
  its BOS descriptor and still enumerated at 480:

        Pixel 9a (Google Fi)   SuperSpeed-capable   -> 480
        Pixel 9a (AT&T)        SuperSpeed-capable   -> 480
        Galaxy Z Flip6         SuperSpeed-capable   -> 480
        razr 2024              not capable          -> 480

  Three SuperSpeed-capable phones from two vendors, all pinned at 480 on this
  host, and no device on this machine has ever trained SuperSpeed on any bus.
  That shifts suspicion from the cable toward the **host port** - though the
  runs may not all have used the same cable, so a single pass with a known-good
  USB 3 cable is still what settles it.
- A CUBIC baseline on this phone would be the cleanest driver comparison
  available, since it has the steadiest path in the log and so the least radio
  noise to confound it.
