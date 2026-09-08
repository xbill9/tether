---
id: 2026-09-05-iphone-17-pro-att-cable3
date: 2026-09-05
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)
  os: iOS 27.0        # build 24A5430a, read over usbmuxd (ideviceinfo)
carrier:
  name: AT&T          # operator-supplied; corroborated by a 2600:381::/32 delegation
  network:            # TODO not obtainable - iOS exposes no equivalent of gsm.network.type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 480
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable: "USB-C to USB-C, third cable - SuperSpeed rating unverified"   # operator-supplied
link:
  interface: enxb65575abcda3
  ipv4: 172.20.10.5/28
  gateway: 172.20.10.1
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [55, 25, 68]
  parallel_4_aggregate_mbps: 101
  rtt_ms:
    min: 34.5
    avg: 45.9
    max: 58.8
    mdev: 9.3
  errors: 0
  drops: 0
verdict: usable
---

# iPhone 17 Pro on AT&T - third cable, same 480

Third cable in the same investigation, after
[cable 1](2026-09-05-iphone-17-pro-att.md) and
[cable 2](2026-09-05-iphone-17-pro-att-cable2.md). Genuine re-plug: device
number stepped 6 -> 7 and `/sys/bus/usb/devices/3-1` timestamps the attach at
13:21:50, so this is a fresh negotiation across new copper.

**Third cable, third 480.** The BOS descriptor is unchanged - `bcdUSB 2.10`,
`wSpeedsSupported 0x000e`, and 10 Gb/s symmetric SuperSpeedPlus on both
sublinks - and `usb4`, the 10 Gb/s companion root hub, still has no device on it.

## Setup

Same phone, same port `3-1` on the `usb3` 480 Mbps root hub, same
`enxb65575abcda3`, same `/28` hotspot subnet, same `05ac:12a8` / `ipheth`.
WiFi `DOWN` and the tether the sole default route throughout. Pass started about
four and a half minutes after plug-in, so it is comparable with
[the settled cable-2 pass](2026-09-05-iphone-17-pro-att-cable2-settled.md)
rather than with the ninety-second one.

The re-plug reset the interface counters, so this record's error and drop
figures cover this pass alone.

**This cable's rating is unverified**, like the two before it.

## Observations

### The bus: three unknowns is not three pieces of evidence

The tally is now three C-to-C cables and two physical ports, always 480, on a
device that advertises 10 Gb/s. It is tempting to read that as a mounting case
against the host, and it is worth being precise about why it is not:

**None of the three cables is known to carry SuperSpeed pairs.** Unmarked C-to-C
cables - the kind that ship with phones and chargers - are overwhelmingly USB 2.0
by construction. Three of them all being USB 2.0 is not a coincidence requiring
explanation; it is the expected outcome. The three results are close to one
result repeated, not three independent tests.

What *is* independently interesting is the other half: **this host has never
trained SuperSpeed on any bus, with any device.** `usb2` (20 Gb/s) and `usb4`
(10 Gb/s) are enumerated and idle and have never had a device attached across
every phone and peripheral in this log. The only peripherals on this machine -
card reader, fingerprint reader, camera, Bluetooth - are all internal USB 2.0
devices, and every phone tested arrived over the same class of cable, so for
most of this investigation the host side had not been given a fair test either.

### The host side, settled - `/sys/class/typec`

*Added 13:35, after the transfers above; measurements unchanged.*

The question of which physical connector is which does not need another test. The
kernel answers it at boot, and this machine runs UCSI (`ucsi_acpi`), so the
Type-C connectors are enumerated objects with their USB ports bound to them:

    typec port0: bound usb3-port1 (ops connector_ops [usbcore])
    typec port0: bound usb4-port1 (ops connector_ops [usbcore])
    typec port1: bound usb3-port2 (ops connector_ops [usbcore])
    typec port1: bound usb2-port1 (ops connector_ops [usbcore])

Read against `lspci`, that is the whole map. **This machine has exactly two USB-C
connectors, and each is wired to both a USB 2.0 port and a SuperSpeed port:**

| Type-C connector | USB 2.0 half | SuperSpeed half | Controller |
|---|---|---|---|
| `port0` | `3-1` | `4-1` (10 Gb/s) | `00:14.0` Alder Lake PCH |
| `port1` | `3-2` | `2-1` (20 Gb/s) | **`00:0d.0` Thunderbolt 4** |

`usb3-port1` and `usb4-port1` confirm it from the other side - they list each
other as `peer` and share location `0x80000101`, which is the kernel saying they
are two halves of one connector. The ACPI table that declares all this is named
`TbtTypeC`.

**Three claims in this log were wrong and are corrected in place:**

1. **"There is a port on this machine that has never been used."** There is not.
   There are two connectors and both have been tested.
   *(Half wrong, and corrected again at 14:15: there were two **Type-C**
   connectors, both tested, and a **third USB-A receptacle at `3-3`** that this
   record could not see. It has since been tested - also 480. See the correction
   above.)*
2. **"Neither USB-C port reaches the Thunderbolt 4 controller."** `port1` does -
   it *is* the TB4 port.
3. **"Find the Thunderbolt 4 port; a 480 reading there would convict the cable
   beyond doubt."** It was found and it had already been tested:
   [cable 1](2026-09-05-iphone-17-pro-att.md) ran in `3-2`, which is `port1`, and
   enumerated at 480. By this log's own stated standard, **that verdict is
   already in.**

So the host is largely exonerated. Both connectors have a SuperSpeed port
declared by firmware and enumerated by the kernel, and a 10 Gb/s device came up
at 480 in both, across three cables, with zero USB errors. **The cable is now the
strong favourite, not merely the surviving suspect.**

**Correction, 14:15 - the table above is right, the inventory it implies is not.**
*Measurements in this record are unchanged.* `/sys/class/typec` enumerates
**Type-C connectors only**; a Type-A receptacle has no PD and no connector
object, so it cannot appear there. This machine has a **third** external
receptacle - USB-A at `3-3`, `usb3-port3`, peered with `usb4-port2` at 10 Gb/s
and declared `hotplug` by firmware exactly like the two Type-C ports. It was
untried when this record was written, and it also enumerates the iPhone at 480
([record](2026-09-05-iphone-17-pro-att-usba.md)). The complete list of external
ports is the `hotplug` entries in the `usb3` port list - `port1`, `port2`,
`port3` - not the `typec` nodes. The three claims corrected below were corrected
in the right direction but one step short.

Two caveats, because this is inference and not a measurement: firmware declaring
a SuperSpeed port on a connector is not proof that the traces and retimer behind
it are intact, and nothing here reads a cable directly - see below.

### What the cable itself will not tell you

An electronically marked USB-C cable declares its own data capability over Power
Delivery, and Linux exposes that as a `portN-cable` device with an `identity/`
directory of PD VDOs. **There is none here.** No cable node exists anywhere under
`USBC000:00`, so the cables cannot be read directly.

That absence is not evidence about these cables. The stack is not surfacing VDO
data at all: `usb_typec_revision` is 1.1, the connected `port0-partner` -
the iPhone - has an **empty** `identity/` directory and reports
`usb_power_delivery_revision = 0.0`. A stack that will not show the phone's PD
identity was never going to show the cable's.

Worth knowing for the same reason it is tempting: the USB-C spec **requires** an
e-marker on a passive cable supporting more than USB 2.0 speeds, and does not
require one on a USB 2.0 cable. So on a stack that did report cable identity, a
missing e-marker would be real evidence. On this one it is silence, not a
finding.

That leaves one cheap decisive test:

- **A USB 3 mass-storage device** - an SSD enclosure or flash drive with its own
  rated cable - in either connector. Costs no cellular data and takes seconds. If
  it trains SuperSpeed, the ports and traces are good and every cable tried so
  far was USB 2.0. If it does not, the fault is physical and behind the connector,
  which is the only hypothesis the typec mapping cannot rule out.

### The measurements, and a confound worth naming

Four passes on this handset this afternoon:

| | 12:40 cable 1 | 13:15 cable 2, 90s | 13:19 cable 2, settled | 13:26 cable 3 |
|---|---|---|---|---|
| Single (Mbps) | 96 / 103 / 103 | 56 / 36 / 21 | 64 / 57 / 59 | 55 / 25 / 68 |
| Spread | 1.07x | 2.69x | 1.11x | 2.72x |
| Par-4 | 178 | 73 | 85 | **101** |
| RTT avg | 38.0 ms | 103.6 ms | 54.2 ms | **45.9 ms** |
| RTT mdev | 6.7 ms | 110.3 ms | 30.9 ms | **9.3 ms** |

**Aggregate, average RTT and `mdev` have all improved monotonically across the
three afternoon passes** - 73 -> 85 -> 101, 103.6 -> 54.2 -> 45.9, and
110.3 -> 30.9 -> 9.3 - climbing steadily back toward the 12:40 baseline.

**That trend is a trap, and it is the main reason this record exists.** Each
cable swap happened to coincide with a step of that recovery, so comparing cable
2 against cable 3 makes cable 3 look better. It is not. Time is the variable
that moved; the cable is the one that did not. Nothing in these numbers
distinguishes any of the three cables from each other, and no future reader
should take the 73 -> 101 climb as a cable effect.

For this pass on its own: single-stream 55 / 25 / 68 Mbps looks like a 2.72x
spread, but the statistic is carried entirely by one transfer. The other two, 55
and 68, bracket the settled pass's 64 / 57 / 59 exactly. It is one transient
trough, not a wide distribution, and three samples cannot tell those apart.

By the README's rubric this is closest to **wide spread with flat RTT** -
`mdev` at 9.3 ms is the flattest since the 12:40 baseline, and min-to-max spans
only 34.5 to 58.8 ms. But the rubric's remedy for that case is BBR, **and this
already ran under BBR**, so the prescription is spent. Either BBR is also
backing off on sustained radio loss, or - more likely given the flat RTT and an
aggregate four times the size of the dip - the radio briefly lost capacity and
congestion control had nothing to do with it. The aggregate of 101 Mbps is 1.49x
the best single and 33% of the realistic bulk ceiling of a 480 Mbps bus, so
neither the tether nor the USB bus was binding.

The four parallel streams shared at 1.16x max:min (28 / 26 / 24 / 24 Mbps), the
most even sharing of any pass on this handset. Zero errors and zero drops across
roughly 51k RX / 20k TX packets - a cable degrading throughput would show up
here, and across three cables it never has.

## Issues

`carrier.network` is unobtainable on iOS. Left blank rather than read off the
status bar.

## Follow-ups

- **Plug in a USB 3 flash drive or SSD before trying a fourth cable.** It costs
  nothing, takes seconds, and is now the only open question: it separates "every
  cable so far was USB 2.0" from "something physical behind the connector is
  broken". Three phone cables cannot do that; the typec mapping above has
  eliminated everything else.
  **Still open, and the right place for it is now the USB-A port `3-3`** - a
  flash drive with a fixed A connector needs no cable, which removes the cable
  variable instead of swapping it. *Added 14:15.* A fourth cable was tried first
  ([record](2026-09-05-iphone-17-pro-att-usba.md)), on that third port, and gave
  480 like the rest.
- ~~The Thunderbolt 4 port at `00:0d.0` remains untried.~~ **It is Type-C
  `port1` = physical `3-2`, and it was the port used for the very first pass on
  this handset.** Nothing to find *among the Type-C connectors* - but there was
  a USB-A port left, and this record missed it. *Added 14:15; see the correction
  in Observations.*
- **AT&T recovered across the afternoon** rather than degrading. Worth one Pixel
  9a pass to confirm it is carrier-wide, but the urgency is lower than it looked
  an hour ago - the 13:15 collapse now reads as the bottom of a dip rather than a
  new normal.
- None of these three passes should be read as a measurement of the iPhone 17
  Pro. Between them they measure an AT&T cell recovering between 13:15 and 13:26.
