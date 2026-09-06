---
id: 2026-09-06-pixel-9a-att-superspeed
date: 2026-09-06
phone:
  make: Google
  model: Pixel 9a     # host-observed - USB iProduct string; confirmed over adb afterwards (ro.product.model)
  os: Android 17      # backfilled 2026-09-06, see Issues - adb read after the pass; build CP41.260814.003.B1, sdk 37, patch 2026-08-05
carrier:
  name: AT&T          # corroborated by a 2600:382::/32 delegation and the same DHCP lease as the 2026-09-05 record
  network:            # TODO adb is not installed on this host - gsm.network.type unreadable, see Issues
usb:
  vendor_id: "18d1"
  product_id: "4eec"  # NCM+ADB composite - USB debugging is still on at the phone end
  driver: cdc_ncm
  bus_speed_mbps: 5000
  negotiated_link_mbps: 3750
  cable: "USB-C to USB-A, USB 3 rated"   # operator-supplied; confirmed - it trained SuperSpeed
link:
  interface: enx2e9319548995
  ipv4: 10.97.185.76/24
  gateway: 10.97.185.21
  ipv6: true          # global address present this session, unlike the 2026-09-05 pass
  mtu: 1500
  mtu_max: 1500
ntb:
  rx_max: 16384
  tx_max: 16384
  device_max_in: 16384
  device_max_out: 16384
  tx_timer_usecs: 400
tcp:
  congestion_control: cubic
  slow_start_after_idle: 1
  mtu_probing: 0
results:
  single_stream_mbps: [49.091, 51.870, 4.387]
  parallel_4_aggregate_mbps: 8.215
  rtt_ms:
    min: 16.996
    avg: 21.122
    max: 25.367
    mdev: 2.766
  errors: 0
  drops: 0
verdict: poor
---

# Pixel 9a on AT&T - the USB ceiling is gone and the collapse is not

Second SuperSpeed record, after
[the iPhone 17 Pro pass](2026-09-06-iphone-17-pro-att-superspeed.md) earlier
today. Direct counterpart to
[2026-09-05-pixel-9a-att-usba](2026-09-05-pixel-9a-att-usba.md): **same phone,
same USB-A receptacle, same DHCP lease** (`10.97.185.76/24` via
`10.97.185.21`), same NTB parameters. Two things differ - the cable is USB 3
rated, and the host is on CUBIC rather than BBR.

The bus went **480 -> 5000** and the negotiated link **425 -> 3750**.

The collapse did not go anywhere.

## Setup

Came up without intervention. WiFi was down (`wlo1` NO-CARRIER) and the tether
was the sole default route, checked before the transfers and again after.

The device attached at `4-2` - `usb4-port2`, whose peer `usb3-port3` is the
USB-A receptacle at `3-3`. That is the same receptacle as the 2026-09-05
USB-A pass, which enumerated at 480 on `3-3`; a SuperSpeed link simply lands on
the `usb4` hub instead. **The receptacle is a control here, not a variable** -
only the cable changed, and it is the second cable today to confirm that the
unmarked cables used on 2026-09-05 were USB 2.0.

`lsusb` reads the device's own capability as `Device can operate at SuperSpeed
(5Gbps)`, and it trained at exactly that. Unlike the iPhone 17 Pro, this phone
advertises no SuperSpeedPlus, so 5000 is its ceiling and is now being reached.

The NTB buffers are worth stating because of the advice they refute:

    rx_max 16384 == dwNtbInMaxSize  16384
    tx_max 16384 == dwNtbOutMaxSize 16384

Host and device already agree at the device's advertised maximum, so the common
"raise these to 32768" tuning is a **no-op** on this pairing, exactly as the
README's field reference warns. Unchanged from 2026-09-05 despite the bus
being ten times faster - NTB sizing is negotiated from the descriptor, not from
the link rate.

## Observations

**The pass decayed monotonically and never recovered.** 49.091, then 51.870,
then 4.387 Mbps - an 11.82x spread produced almost entirely by the third run
cratering. The four-stream test ran immediately after and aggregated
**8.215 Mbps, which is 0.16x the best single stream.**

**RTT was low and flat throughout: 21.1 ms average, `mdev` 2.766 ms** - the
best latency figures of any AT&T record in this log, and less than half the
49.8 ms of the 2026-09-05 USB-A pass. Whatever is destroying throughput is not
queueing, not buffering, and not adding delay.

Taken at face value the shape is the README's first case - wide single spread
with flat RTT, congestion control collapsing on radio loss, fixable with BBR.
**I do not think that is what this is, and the reason is in the log already.**

- **It reproduces under BBR.** The 2026-09-05 USB-A pass ran `bbr` and produced
  the same shape: 30.418 / 20.302 / 6.908 descending, aggregate 5.054, below
  its own slowest single. A collapse that survives the congestion-control
  change is not a congestion-control collapse.
- **Aggregate below single is not a rubric case at all.** All five README cases
  describe an aggregate at or above the single-stream figure. Four flows
  summing to a sixth of one flow is outside the rubric, and per the README I am
  saying so rather than filing it under the nearest neighbour.

**The better-supported reading is that the link degrades under sustained load
and stays degraded.** Both passes were fine for the first transfers and
collapsed partway through, then stayed down for everything after - including
the parallel test, which is simply the last thing in the pass. That ordering
means the parallel number may be measuring *when* it ran rather than *what* it
ran. This is the same time-confound the `To test` list already flagged for the
2026-09-05 AT&T sequence, in the opposite direction: there the link was
recovering across passes, here it degrades within one.

A carrier-side per-device throttle after some volume within a session fits both
passes, but **this record does not establish it** - two passes on one phone with
no controlled test is a hypothesis, not a finding. Follow-ups below.

**What the record does settle:** USB was never the constraint on this phone.
The 2026-09-05 USB-A result was `poor` on a 480 Mbps bus, and the natural
suspicion was the USB 2.0 ceiling or the USB-A path. Same receptacle, 10x the
bus, 8.8x the negotiated link, and the aggregate went 5.054 -> 8.215 Mbps.
Both are far below anything the bus could explain.

## Issues

**`adb` was not installed on this host when the pass ran**, so `phone.os` and
`carrier.network` were both blank at test time. This was the second gap of the
day from the same cause - the system changed since 2026-09-05, and neither
`adb` nor `libimobiledevice-utils` survived it.

**Backfilled 2026-09-06, after the transfers:** `adb` was installed, the
handset authorised, and `phone.os` read from the device -
`ro.build.version.release` 17, `ro.build.id` CP41.260814.003.B1, sdk 37,
security patch 2026-08-05. `ro.product.model` also confirmed `Pixel 9a`,
matching the USB descriptor read at test time. **None of this was observed
during the pass**, and no measurement changed.

`phone.os` was deliberately **not** carried over from the 2026-09-05 records at
write time, even though they are the same handset, because a beta build can
move in a day and the README forbids carrying values between records. Read
independently it turned out identical - which vindicates the caution rather
than making it unnecessary, since that could only be known by reading it.

**`carrier.network` is still blank, and deliberately so.** It is the more
damaging of the two gaps: the 2026-09-05 records show this phone reporting
`LTE` while the status bar claimed 5G, and `2026-09-05-pixel-9a-att` has an
unresolved `network` field for exactly that reason. The skill requires it read
*before and after* the transfers and recorded only if the two agree; a value
read now cannot establish what the radio was doing during the pass, and
backfilling one would silently poison every carrier comparison drawn from this
record. **A radio switch therefore remains an unexcluded explanation for the
mid-pass collapse.** It gets captured properly on the decay re-test.

Authorising adb did bounce the tether - the handset was reconnected after
accepting the prompt - but it came back on the same interface
(`enx2e9319548995`), same MAC, same DHCP lease and still at 5000, so the `link`
and `usb` fields above still describe what was measured.

`product_id` is `4eec`, the NCM+ADB composite, the same as the 2026-09-05
USB-A pass. USB debugging is enabled at the phone end regardless of the host
lacking a client, so the descriptors here describe the same USB configuration
that record measured - the comparison is sound.

`ip -s link` was read only after the transfers, so the counters are cumulative
rather than a delta for the pass. Both zero, so it does not matter here. Still
does not close the open `To test` item.

## Follow-ups

- **Re-run this configuration under BBR.** Same reason as the iPhone record:
  bus and congestion control both moved since the last comparable pass. Here it
  is less likely to change the outcome - the 2026-09-05 BBR pass collapsed
  too - which is itself the useful result.
- **Test the decay hypothesis directly, and it is cheap.** Run the three single
  streams, wait five minutes idle, then run three more. If the second set comes
  back fast, the link recovers with time and a volume-triggered throttle is the
  live explanation. If it stays slow, it is not volume. One extra 24 MB against
  a hypothesis that currently rests on two uncontrolled passes.
- **Run the parallel test first, before the singles, on one pass.** Every
  record in this log runs singles then parallel, so a monotonic decay and a
  genuine parallel weakness are indistinguishable in all of them. Reversing the
  order once separates them for the whole log, not just this phone.
- ~~**Reinstall `adb`**~~ done 2026-09-06, along with
  `libimobiledevice-utils`. The next Android pass can read `gsm.network.type`
  before and after, which this one could not.
- **A Gen 2 cable remains untried but is moot for this phone** - it advertises
  SuperSpeed only, so 5000 is its ceiling and it is already there.
