---
id: 2026-09-05-galaxy-s24-google-fi
date: 2026-09-05
phone:
  make: Samsung
  model: Galaxy S24 (SM-S921U1)
  os: Android 16      # shipping build BP4A.251205.006, patch 2026-07-05, read over adb
carrier:
  name: Google Fi     # confirmed over adb (gsm.operator.alpha)
  network: 5G (NR SA) # read DURING the pass - gsm.network.type=NR_SA before and after, agreeing
usb:
  vendor_id: "04e8"
  product_id: "6864"  # with USB debugging enabled throughout
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - reads -1
  cable:              # TODO unverified - phone advertises SuperSpeed and still enumerated at 480
link:
  interface: enx763dd1c95175   # renamed from enx6e6e82944d55 before the transfers, see Issues
  ipv4: 10.37.154.19/24
  gateway: 10.37.154.17
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [98, 112, 113]
  parallel_4_aggregate_mbps: 230
  rtt_ms:
    min: 31.1
    avg: 36.4
    max: 40.3
    mdev: 3.6
  errors: 0
  drops: 0
verdict: good
---

# Samsung Galaxy S24 on Google Fi - a matched pair with the S25

The most tightly controlled comparison in this log. Against
[2026-09-05-galaxy-s25-google-fi](2026-09-05-galaxy-s25-google-fi.md) this
shares **carrier, radio type, driver, OS build, host config and test day**:

    both:  Google Fi, 5G NR SA, rndis_host, Android 16 BP4A.251205.006,
           bbr / slow_start_after_idle=0 / mtu_probing=1, 2026-09-05

The only differences are the handset itself and the security patch level
(2026-07-05 here, 2026-08-05 on the S25). Everything else that has confounded
comparisons in this log - different carriers, unrecorded radios, a beta OS on
the Pixels, different drivers - is held constant.

## Setup

Came up on its own, dual-stacked, sole default route, through the same generic
`Wired connection 1` profile. `rndis_host`, so no `ntb` block and no
`negotiated_link_mbps`.

Radio type was captured over adb immediately before and immediately after the
transfers, both `NR_SA`, which is what makes `carrier.network` usable here. Only
the S25 record and this one have that.

## Observations

Single-stream was 98 / 112 / 113 Mbps - a **1.16x spread**, and the shape is
tight enough that congestion control is not in question.

**The four parallel streams shared the link more evenly than in any other
record:** 65 / 56 / 55 / 54 Mbps, a max:min of **1.22x**, beating the Flip6's
1.30x and far ahead of the Pixels, which starved one stream at 9.5x. Aggregate
was 230 Mbps, about 77% of the realistic USB 2.0 bulk ceiling.

RTT averaged 36.4 ms with 3.6 ms mdev - mid-pack, and flat.

**The matched pair is the interesting result, and it argues against reading much
into single-stream rankings:**

    S24   98 / 112 / 113   mean 108   spread 1.16x   par-4 230
    S25   70 / 112 /  61   mean  81   spread 1.84x   par-4 238

The means differ by 34%, which looks decisive until the rest is read. The
aggregates are within 3% of each other, and both phones hit an identical peak
single of 112 Mbps. The gap comes entirely from the S25's two low runs, which
sit inside its own 1.84x spread. With everything else held constant, the most
plausible reading is that the S25 pass caught a worse moment on the radio, not
that the S24 is a faster tether.

That is the same conclusion the log has been converging on: **within-phone
variance across three transfers exceeds the between-phone differences**, so
single-stream means do not rank hardware. The aggregates agreeing to 3% while
the means differ by 34% is the cleanest evidence of it so far.

Zero errors and zero drops. The counter baseline was lost when the interface was
recreated (see Issues), so these are cumulative since that interface came up -
covering the whole test and a little of the setup before it.

## Issues

**Authorising the adb prompt bounced the tether**, which is the first time this
has actually happened in the log rather than merely being warned about. The
interface was recreated with a **new MAC**, so it also got a new name and a new
DHCP lease:

    before:  enx6e6e82944d55   10.37.154.148/24   IPv6 in 2607:fb91::/32
    after:   enx763dd1c95175   10.37.154.19/24    IPv6 in 2607:fb90::/32

Same phone throughout - the USB serial on `3-2` never changed - and the same
gateway, `10.37.154.17`.

**The measurements are unaffected, and that was checked rather than assumed.**
The bounce completed *before* the first transfer, not during one: the attempt to
read the old interface's counters failed with "does not exist" while the three
single-stream runs then succeeded, so all of them ran on the new interface. More
importantly, `wlo1` was **DOWN** for the entire session and the sole default
route was the tether, so no traffic could have silently fallen back to WiFi and
been recorded as a tethering result.

The frontmatter records the interface that carried the traffic. The lesson for
the method is that USB debugging should be authorised *before* a pass is
started, not between collecting metadata and measuring.

## Follow-ups

- **The fifth SuperSpeed-capable phone to enumerate at 480**, now across three
  vendors and five handsets. Nothing on this host has ever trained SuperSpeed on
  any bus. The USB 3 cable test remains the highest-value experiment here, and
  the host port is the likelier culprit.
- A CUBIC pass on this phone would now be the best-controlled driver comparison
  available, given how much this pair holds constant.
- A second pass on the S25 would test the reading above directly. If its numbers
  land near the S24's, radio variance is confirmed as the explanation.
