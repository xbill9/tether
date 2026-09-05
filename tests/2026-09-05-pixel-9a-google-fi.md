---
id: 2026-09-05-pixel-9a-google-fi
date: 2026-09-05
phone:
  make: Google
  model: Pixel 9a
  os: Android 17      # beta build CP41.260814.003.B1, read over adb after the pass
carrier:
  name: Google Fi
  network:            # TODO unresolved - only a reading taken during a pass can fill this, see body
usb:
  vendor_id: "18d1"
  product_id: "4eeb"
  driver: cdc_ncm
  bus_speed_mbps: 480
  negotiated_link_mbps: 425
  cable:              # TODO unverified - enumerated at USB 2.0 on a port whose SuperSpeed companion bus is idle
link:
  interface: enxce1d58e89c0f
  ipv4: 10.244.144.215/24
  gateway: 10.244.144.214
  ipv6: true
  mtu: 1500
  mtu_max: 1500
ntb:
  rx_max: 16384
  tx_max: 16384
  device_max_in: 16384
  device_max_out: 16384
  tx_timer_usecs: 400
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [114, 116, 63]
  parallel_4_aggregate_mbps: 246
  rtt_ms:
    min: 25.9
    avg: 37.4
    max: 43.6
    mdev: 6.4
  errors: 0
  drops: 0
verdict: good
---

# Pixel 9a on Google Fi - BBR with the parallel test

Third pass on the same phone and cable as
[2026-09-05-pixel-9a-cubic](2026-09-05-pixel-9a-cubic.md) and
[2026-09-05-pixel-9a-bbr](2026-09-05-pixel-9a-bbr.md). Host config is unchanged
from the BBR record - this run exists to close the two gaps it left: the
4-stream parallel test was never run under BBR, and the carrier was never
recorded. Carrier is now identified as Google Fi.

## Setup

Nothing to bring up. Still bound to `cdc_ncm` at `enxce1d58e89c0f`, still
DHCPed from the phone at 10.244.144.215/24, dual-stacked. Host sysctls read back
`bbr` / `slow_start_after_idle=0` / `mtu_probing=1`, i.e. the persisted settings
from the BBR record survived.

The IPv6 prefix handed out by the phone is in 2607:fb91::/32, which is
T-Mobile - the expected upstream for a Google Fi SIM. That identifies the
carrier's plumbing but says nothing about which radio was in use, so
`carrier.network` is left blank rather than inferred.

## Observations

**The parallel gap is closed: 246 Mbps aggregate under BBR, against 211 Mbps
under CUBIC.** So the four-stream ceiling did rise, and single-stream did not
simply catch up to a fixed ceiling - the BBR record's open question resolves in
favour of both having improved.

Single-stream came in at 114 / 116 / 63 Mbps. That is a 1.8x spread, wider than
the 1.4x of the earlier BBR run but nowhere near CUBIC's 7.8x. Two runs sat
tight together and the third dropped; with RTT stable this looks like ordinary
radio variance rather than a return of window collapse, but it is one sample and
the earlier BBR pass was tighter.

The more interesting number is the ratio. Aggregate 246 Mbps against a best
single of 116 is roughly 2x - still headroom, but far from CUBIC's 14x gap
between the single-stream floor and the aggregate. The local bottleneck the
first two records chased is largely gone.

**What replaces it is the bus.** 246 Mbps aggregate on a 480 Mbps bus is around
80% of the realistic USB 2.0 bulk ceiling (~300 Mbps), which by the README's
rubric is the point where the cable, not the software, becomes the thing worth
fixing. Every remaining record on this phone will be measuring the cable until
that changes.

RTT rose: 37.4 ms avg here against 29.6-29.7 ms in both earlier records, with
mdev 6.4 vs 4.1-5.8. This ping ran immediately after the parallel transfers, so
some of it may be residual queue, and the earlier records' pings were not
sequenced identically. Not enough to call bufferbloat, but it is the first
RTT movement across the three passes and worth watching.

Zero errors and zero drops across the test window (about 45k RX / 13k TX
packets), same as both earlier runs - the cable is not erroring, it is just
slow.

## Issues

The phone's OS version could not be read from the host. `adb` is not installed,
the phone exposes only the tether function (18d1:4eeb) with no MTP interface, and
no gvfs mount is present, so there is no path to the Android build string over
USB. Android version is not carried in USB descriptors. Left blank rather than
guessed - it needs reading off the device.

`carrier.network` has the same problem for the same reason.

## Follow-ups

- OS version and radio type, both readable only on the phone.
- The USB 3 cable test is now the highest-value remaining experiment: aggregate
  is close enough to the USB 2.0 ceiling that it is probably the binding
  constraint.
- Single-stream spread was 1.8x here vs 1.4x in the earlier BBR pass. Worth a
  fourth pass to see which is representative.

## Post-test: metadata over adb

`adb` was installed on 2026-09-05, after this pass, and this handset authorised.
Read from the device:

    ro.build.version.release        17
    ro.build.id                     CP41.260814.003.B1   (device name tegu_beta)
    ro.build.version.security_patch 2026-08-05
    gsm.operator.alpha              ,Google Fi
    gsm.network.type                Unknown,NR_SA

`phone.os` is backfilled to **Android 17 on a beta build**. The build id is
recorded alongside it because "Android 17" on its own understates the situation
- this is not a shipping OS, and its network stack need not match one. Reading a
version hours after a pass is safe in a way a radio reading is not: an OS does
not change without a deliberate update and a reboot.

`carrier.network` is **deliberately left blank**. The phone read `NR_SA` (5G
standalone) afterwards, but that does not establish what the radio was doing
during the transfers. The AT&T Pixel showed the cost of assuming otherwise: it
was reported as 5G at test time and read `LTE` later, and that field is now
blank there too. Only a reading taken during a pass can fill this.

**Both Pixel 9a units in this log run the identical build**
`CP41.260814.003.B1`, which removes the OS as a variable between them - useful,
because they differ in carrier, in physical unit, and in little else that was
ever recorded.

No measurement changed.
