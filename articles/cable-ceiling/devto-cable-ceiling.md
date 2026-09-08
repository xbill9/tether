---
title: "A $15 Cable Made the USB Bus Ten Times Faster and the Tether No Faster at All"
published: false
description: "Four cables, three receptacles, and a phone advertising 10 Gb/s that would not leave 480. The cable that finally trained SuperSpeed changed the bus by 10x and the throughput by nothing — and the reason it was still the right purchase did not show up for another eighteen hours."
tags: linux, networking, usb, debugging
cover_image: https://raw.githubusercontent.com/xbill9/tether/main/articles/cable-ceiling/devto-cover.43f70297.jpg
---

This article walks through diagnosing a USB tether that would not negotiate above
USB 2.0 speed, on a phone that advertises 10 Gb/s. The hunt took four cables and
three physical ports across two days. **The cable that finally worked made the bus
ten times faster and the downloads no faster at all**, and the most useful thing in
the whole investigation is why that is not a contradiction.

Every command below is one you can run against your own tether, and every number
comes from a record in the repository:

https://github.com/xbill9/tether

## The Symptom

The repository holds 45 measurement records across 14 handsets from four vendors,
each one a full pass — three sequential single-stream transfers, a four-stream
parallel test, and a ping — against a fixed endpoint and a fixed 8 MB transfer
size.

**41 of those 45 records enumerated at 480 Mbps.** Fourteen handsets, three
drivers, two carriers, three physical receptacles, and for two days not one USB 3.0
negotiation anywhere.

The most conspicuous offender was an iPhone 17 Pro, whose BOS descriptor is not
shy about what it can do:

```plaintext
bcdUSB               2.10
SuperSpeed USB Device Capability:
  wSpeedsSupported   0x000e     -> Full, High, SuperSpeed (5Gbps)
SuperSpeedPlus USB Device Capability:
  bmSublinkSpeedAttr[0]  10Gb/s Symmetric RX SuperSpeedPlus
  bmSublinkSpeedAttr[1]  10Gb/s Symmetric TX SuperSpeedPlus
```

A device declaring 10 Gb/s, enumerating at 480 Mbps. That is a factor of about
twenty-one, and it is the kind of gap that makes you stop measuring throughput and
start reading `sysfs`.

## At This Point You Should Have

- A phone tethered over USB and holding the default route — check this first, or
  you will measure Wi-Fi
- `lsusb` from `usbutils`, and `ip` from `iproute2`
- Read access to `/sys/bus/usb/devices` and `/sys/class/net`, which needs no root
- Every other route-capable interface **down**. If Wi-Fi is up, `curl` will
  succeed over it and the result will look like a tethering measurement

None of the diagnosis below transfers a single byte over the cellular link. That
matters here: a full measurement pass in this repository costs roughly 56 MB of
metered data, and everything in Steps 1 through 4 is free.

## Step 1 — Read the Bus Speed First

This is the one reading that invalidates everything downstream if you skip it. A
charge-only or USB 2.0 cable silently caps the bus at 480 Mbps and nothing
anywhere reports an error.

```bash
# find the tether interface and its USB device
for i in /sys/class/net/*/device/driver; do
  ifn=$(basename $(dirname $(dirname $i)))
  drv=$(basename $(readlink -f $i))
  case $drv in cdc_ncm|rndis_host|ipheth) echo "$ifn  $drv";; esac
done
```

```plaintext
enxb65575abcda3  ipheth
```

Then walk from the interface back to the USB device and read its trained speed:

```bash
dev=$(basename $(readlink -f /sys/class/net/enxb65575abcda3/device/..))
cat /sys/bus/usb/devices/$dev/speed
```

```plaintext
480
```

`480` is USB 2.0, `5000` is USB 3.0 Gen 1, `10000` is Gen 2. Alongside it,
`/sys/class/net/<if>/speed` gives the negotiated link rate — though note that
`ipheth` returns `EINVAL` there and reports nothing, so on an iPhone this field
stays blank in every record.

## Step 2 — Ask the Device What It Is Capable Of

A 480 reading only means something once you know the device could do better.

```bash
lsusb -v -d 05ac:12a8 2>/dev/null | grep -A3 "SuperSpeed"
```

The descriptor block at the top of this article is that output. **The device
capability is the control.** Compare the iPhone 16e measured eight minutes before
the fastest pass in this log: it advertises no SuperSpeed capability at all, so its
480 is its own ceiling and no cable on earth will move it.

That single distinction separates "your cable is bad" from "your phone is a USB 2.0
phone", and it is free to read.

## Step 3 — Find Every Port, Not Just the Pretty Ones

This step exists because the investigation got it wrong, in print, twice.

The obvious move on a modern laptop is to enumerate the Type-C connectors, since
the kernel binds each one to its USB ports at boot:

```bash
dmesg | grep "typec port"
```

```plaintext
typec port0: bound usb3-port1 (ops connector_ops [usbcore])
typec port0: bound usb4-port1 (ops connector_ops [usbcore])
typec port1: bound usb3-port2 (ops connector_ops [usbcore])
typec port1: bound usb2-port1 (ops connector_ops [usbcore])
```

Read against `lspci`, that is a complete map of the machine's USB-C:

| Type-C connector | USB 2.0 half | SuperSpeed half | Controller |
|---|---|---|---|
| `port0` | `3-1` | `4-1` (10 Gb/s) | `00:14.0` Alder Lake PCH |
| `port1` | `3-2` | `2-1` (20 Gb/s) | **`00:0d.0` Thunderbolt 4** |

That table is correct. The conclusion drawn from it — *"there is no untried port on
this machine"* — was wrong, and it cost about an hour.

**`/sys/class/typec` enumerates Type-C connectors only.** A Type-A receptacle has
no Power Delivery and therefore no connector object, so it cannot appear there. The
machine had a third external receptacle the map could not see.

Take the port inventory from the hotplug entries in the port list instead:

```bash
for p in /sys/bus/usb/devices/usb*/*/usb*-port*; do
  [ "$(cat $p/connect_type 2>/dev/null)" = "hotplug" ] || continue
  peer="-"; [ -L "$p/peer" ] && peer=$(basename "$(readlink -f "$p/peer")")
  echo "$(basename $p)  peer=$peer  location=$(cat $p/location)"
done | sort
```

```plaintext
usb3-port3  peer=usb4-port2  location=0x80000301
usb4-port2  peer=usb3-port3  location=0x80000301
```

`usb3-port3` is the USB-A receptacle. Its `peer` is a 10 Gb/s port on another hub,
and the shared `location` is the kernel saying *these two entries are two halves of
one physical hole in the side of the laptop*.

**That peer relationship is the single most useful line in this whole
investigation**, for a reason that only becomes clear in a moment.

## Step 4 — Ask the Cable Directly, and Watch It Refuse

An electronically marked USB-C cable declares its own data capability over Power
Delivery, and Linux exposes that as a `portN-cable` device with an `identity/`
directory of PD VDOs. The USB-C specification **requires** an e-marker on a passive
cable supporting more than USB 2.0, and does not require one on a USB 2.0 cable. So
a missing e-marker would be real evidence.

```bash
ls /sys/class/typec/
cat /sys/class/typec/port0-partner/usb_power_delivery_revision
```

```plaintext
port0  port0-partner  port1  usb_power_delivery_revision
0.0
```

**There is no cable node, and that is not evidence about the cable.** The stack is
not surfacing VDO data at all: the connected partner — the phone itself — has an
empty `identity/` directory and reports PD revision `0.0`. A stack that will not
show the phone's PD identity was never going to show the cable's.

Worth knowing precisely because it looks like it should work. On a host that does
report cable identity this is the whole answer in one `cat`. Here it is silence,
not a finding, and treating it as a finding would have convicted the cable on no
evidence.

## The Hunt

With the cable unreadable, the only remaining instrument is substitution. Four
cables, three receptacles, over one afternoon:

| Pass | Cable | Receptacle | Bus |
|---|---|---|---|
| 1 | C-to-C, unmarked | `3-2` (Thunderbolt 4 connector) | 480 |
| 1b | same cable | `3-1` (the other Type-C) | 480 |
| 2 | C-to-C, second cable | `3-1` | 480 |
| 3 | C-to-C, third cable | `3-1` | 480 |
| 4 | A-to-C, unmarked | `3-3` (USB-A) | 480 |

Zero USB errors and zero drops in every pass. The host has two SuperSpeed root
hubs, both enumerated, both idle, and neither had ever seen a device.

**The tempting reading is that four negatives is mounting evidence against the
host. It is not.** None of those four cables was *known* to carry SuperSpeed pairs.
Unmarked C-to-C cables — the kind that ship in the box with a phone or a charger —
are overwhelmingly USB 2.0 by construction. Four of them all being USB 2.0 is not a
coincidence in need of explanation; it is the expected outcome.

Four unknowns is close to one result repeated, not four independent tests.

## The Trap in the Middle

Here is the part of the investigation most worth stealing, because it has nothing
to do with USB.

Throughput was measured on every one of those passes, and it moved a great deal:

| | 12:40 cable 1 | 13:15 cable 2 | 13:19 cable 2, settled | 13:26 cable 3 | 14:07 cable 4 |
|---|---|---|---|---|---|
| Single (Mbps) | 96 / 103 / 103 | 56 / 36 / 21 | 64 / 57 / 59 | 55 / 25 / 68 | 76 / 58 / 61 |
| 4-stream aggregate | 178 | **73** | 85 | 101 | **130** |
| RTT avg | 38.0 ms | 103.6 ms | 54.2 ms | 45.9 ms | 52.1 ms |
| RTT mdev | 6.7 ms | 110.3 ms | 30.9 ms | 9.3 ms | 12.1 ms |

Aggregate climbed 73 → 85 → 101 → 130 across four consecutive cable swaps. Every
new cable looked better than the one before it.

**None of that is a cable effect.** The carrier was recovering from a dip across
the afternoon, and each swap happened to coincide with a step of that recovery.
Time is the variable that moved; the cable is the one that did not. The USB errors
were zero throughout, and a cable degrading throughput by 60% would show up in
those counters.

Two rules came out of this and both are now in the repository's methodology:

1. **Record three single-stream runs, never one.** One phone in this log produced
   15, 44 and 116 Mbps on three consecutive identical transfers. Any single number
   is a lie about the link.
2. **A/B a hardware change against time, not against the previous hour.** If you
   cannot interleave, do not attribute.

## The Cable That Worked

The next day, a new USB-A to USB-C cable — around $15, bought specifically to be a
*known* SuperSpeed cable rather than another unknown.

```plaintext
480  ->  5000
```

The iPhone trained SuperSpeed and moved to a different hub in `sysfs`, appearing at
`4-2` rather than the `3-x` of every previous pass. That looks like a port change
and it is not:

```plaintext
usb4-port2  peer=usb3-port3  location=0x80000301
```

`4-2` is `usb4-port2`, whose peer is `usb3-port3` — the same USB-A receptacle
tested at 480 the day before, same location code. **The device moved hubs only
because it started training SuperSpeed, which is exactly what a successful 5 Gb/s
negotiation looks like on this host.** The receptacle is a control here. The cable
is the only variable that moved.

A Pixel 9a on the same new cable, same receptacle, same DHCP lease, confirmed it
from the other side:

| | 2026-09-05, old cable | 2026-09-06, $15 cable |
|---|---|---|
| Bus speed | 480 Mbps | **5000 Mbps** |
| Negotiated link | 425 Mbps | **3750 Mbps** |

Two handsets, one cable swap, and the question that had eaten an afternoon was
answered. The unmarked cables were USB 2.0 cables. ✅

## What It Changed

Nothing. 🟢 on the bus, and nothing anywhere else.

The iPhone 17 Pro pass on that 5000 Mbps bus:

| | 4 cables at 480 (best of) | 🥇 $15 cable at 5000 |
|---|---|---|
| Bus speed | 480 Mbps | **5000 Mbps** |
| Single stream (Mbps) | 96 / 103 / 103 | 10.872 / 19.379 / 16.698 |
| 4-stream aggregate | 178 Mbps | **21.246 Mbps** |
| RTT avg | 38.0 ms | 85.105 ms |
| Verdict | `good` | `usable` |

**The first SuperSpeed record in the log is also one of the slowest records in the
log.** 21.246 Mbps of aggregate throughput on a bus rated 5000 — that is 0.4% of
the bus, by arithmetic — and it is worse than every single one of the four passes
on the cables it replaced.

The Pixel 9a did the same thing. Same receptacle, ten times the bus, 8.8x the
negotiated link:

| | 480 Mbps bus | 🥇 5000 Mbps bus |
|---|---|---|
| Single stream (Mbps) | 30.418 / 20.302 / 6.908 | 49.091 / 51.870 / 4.387 |
| 4-stream aggregate | 5.054 Mbps | 8.215 Mbps |
| Verdict | `poor` | `poor` |

An aggregate of 5.054 became 8.215. Both are far below anything a 480 Mbps bus
could explain, let alone a 5000 Mbps one.

## Why the Aggregate Is the Test

The four-stream number is doing the work in both tables above, and it is worth
saying why rather than treating it as a second opinion on the single-stream figure.

**Single-stream against four-stream aggregate is the one comparison that separates
"the carrier is slow" from "something on this machine is collapsing."** If four
flows together go much faster than one, the wide-area path has headroom and the
problem is local. If they do not, there is no headroom to find.

On the iPhone's SuperSpeed pass the aggregate was **21.246 against a best single of
19.379 — a ratio of 1.10x.** Four flows bought ten percent over one flow.

That single ratio rules out both of the plausible local explanations at once. If
congestion control were halving its window on radio loss, four parallel flows would
aggregate far above one; they did not. If there were a per-flow shaping cap, the
same thing; there is not. **The constraint was upstream of the machine, and nothing
on the machine was tunable into it.**

Which is the same conclusion the 480 Mbps records had already reached — now reached
on a bus ten times faster. That is what makes it worth stating. **The USB ceiling
and the throughput ceiling were never the same ceiling.**

## Eighteen Hours Later

The story would end there, with a $15 cable that bought a `sysfs` reading, except
that the same handset was measured again at 23:01 the same evening on a Thunderbolt
cable and a different host controller.

| | Morning, $15 cable | 🥇 Evening, Thunderbolt | 🥈 Evening, USB-C receptacle |
|---|---|---|---|
| Bus speed | 5000 Mbps | **10000 Mbps** | 5000 Mbps |
| Single stream (Mbps) | 10.9 / 19.4 / 16.7 | 151.036 / 119.931 / 147.540 | 134.856 / 143.749 / 129.250 |
| 4-stream aggregate | 21.246 | **361.330** | **370.695** |
| RTT avg | 85.105 ms | 27.268 ms | 29.601 ms |
| RTT mdev | 85.342 ms | **2.272 ms** | 7.171 ms |

Aggregate went from 21.2 to 361.3 Mbps on the same phone, seventeen-fold, and the
bus doubled at the same time.

**It is not the bus.** ❌ The morning pass was using well under one percent of the
bus it already had; a link that idle cannot be relieved by doubling it. The RTT
tells the same story — 85.1 ms average with 85.3 ms of `mdev` in the morning
against 27.3 and 2.27 at night. That is not a different cable, that is a different
network condition. The honest candidate is the radio, and on iOS there is no way to
read it, so it stays a candidate.

Note also the third column: moving from the Thunderbolt port back to a plain USB-C
receptacle **halved the bus and did not cost a single megabit** — 370.695 against
361.330. At 361 Mbps the phone is using about 3.6% of a 10000 Mbps bus, by arithmetic.

## The Ceiling That Was Never Binding, Until It Was

Now the part that rescues the $15.

The repository's diagnostic constant for the realistic bulk throughput of a
480 Mbps USB 2.0 bus, after protocol overhead, is **300 Mbps**. That is a rule of
thumb, but a well-calibrated one here: the best aggregate ever recorded on a
480 Mbps bus across all 45 records is **273 Mbps**, which is 91% of it.

Post-cable, four separate measurements sit above that line:

| Measurement | Result | Above 300? |
|---|---|---|
| Best 480-era aggregate, 45 records | 273 Mbps | no — 91% of it |
| 4-stream aggregate, Thunderbolt | 361.330 Mbps | **yes** |
| 4-stream aggregate, USB-C receptacle | 370.695 Mbps | **yes** |
| Single 32 MB transfer, Thunderbolt | 332.3 and 327.2 Mbps | **yes** |
| Single 32 MB transfer, USB-C receptacle | 351.1 Mbps | **yes** |

**Those numbers were not reachable on a USB 2.0 bus.** Not "would have been
slower" — not reachable. The evening's throughput needed the cable, and the cable
by itself produced none of it.

So the correct statement about a $15 cable is neither of the two you would reach
for:

- ❌ *"The cable made it faster."* It did not. Measured twice, on two handsets, the
  pass immediately after the swap was **worse**.
- ❌ *"The cable was a waste."* It was not. Four measurements later that night
  exceeded what the old cable could physically carry.
- ✅ **The cable removed a ceiling that was not in contact with anything yet.** It
  bought no throughput on the day it was installed and was a precondition for all
  of the throughput eighteen hours later.

Ceilings are invisible until something reaches them. A ceiling you are at 0.4% of
is indistinguishable from a ceiling that is not there — which is why the pass that
proves a hardware fix worked is almost never the pass you run right after applying
it.

**And one honest limit on that claim:** nobody re-ran the fast link on a USB 2.0
cable. The 300 Mbps figure is a bound argument, not a controlled A/B. It says those
four measurements could not have happened on the old cable; it does not measure how
much of the evening the old cable would have cost.

## One More Trap: the Transfer Size

While measuring the fast link, the single-stream figure sat near 140 Mbps against a
four-stream aggregate of 361 — the classic shape of per-flow carrier shaping, and
that is what it was written up as.

It was wrong, and the correction is worth the paragraph.

A single **32 MB** transfer on the same connection ran 332.3 Mbps — essentially the
whole four-stream aggregate, from one flow. So the gap was about the fixed 8 MB
transfer size, not the link. Except the first attempt to prove that was also
uncontrolled: a fitted model predicted 267 Mbps at 20 MB and the measurement came
back at **73.0 Mbps**, because this link can collapse by 4.8x on its own between
one transfer and the next.

The design that settled it was six transfers alternating 8 and 32 MB, **the whole
run spanning 3.89 seconds** so that link variation could not fall differently on
the two sizes:

| # | size | duration | throughput |
|---|---|---|---|
| 1 | 8 MB | 0.418 s | 153.3 Mbps |
| 2 | 32 MB | 0.722 s | 354.6 Mbps |
| 3 | 8 MB | 0.438 s | 146.1 Mbps |
| 4 | 32 MB | 0.701 s | 365.1 Mbps |
| 5 | 8 MB | 0.362 s | 176.9 Mbps |
| 6 | 32 MB | 0.699 s | 366.3 Mbps |

8 MB mean **158.75** Mbps, 32 MB mean **361.96** Mbps, a ratio of **2.28x**. Every
32 MB run beat the 8 MB run beside it, and the two sets do not overlap at all — the
fastest 8 MB run, 176.9, is below the slowest 32 MB run, 354.6.

The mechanism is still open. A fixed-cost fit to those durations gives an asymptote
of 637 Mbps and a startup cost of **0.305 s**, which is about **10 round trips** at
this link's 29.6 ms, where slow-start to the ~503 KB bandwidth-delay product should
need roughly 6. Something beyond textbook slow-start is in there, and six transfers
cannot say what.

**Same failure mode as the cable, one layer up.** A measurement instrument was
producing a number that described the instrument rather than the link, and the only
way out was interleaving the two conditions inside a window too short for anything
else to change.

## Cheat Sheet

```bash
# 1. which interface is the tether, and what driver
for i in /sys/class/net/*/device/driver; do
  ifn=$(basename $(dirname $(dirname $i)))
  case $(basename $(readlink -f $i)) in
    cdc_ncm|rndis_host|ipheth) echo "$ifn $(basename $(readlink -f $i))";; esac
done

# 2. is it holding the default route (or are you about to measure Wi-Fi)
ip route show default

# 3. THE READING THAT MATTERS - 480 / 5000 / 10000
dev=$(basename $(readlink -f /sys/class/net/<if>/device/..))
cat /sys/bus/usb/devices/$dev/speed

# 4. could the device do better? if no SuperSpeed capability, stop here
lsusb -v -d <vid>:<pid> 2>/dev/null | grep -A3 SuperSpeed

# 5. every external port, including the ones /sys/class/typec cannot see
for p in /sys/bus/usb/devices/usb*/*/usb*-port*; do
  [ "$(cat $p/connect_type 2>/dev/null)" = hotplug ] || continue
  peer="-"; [ -L "$p/peer" ] && peer=$(basename "$(readlink -f "$p/peer")")
  echo "$(basename $p) peer=$peer location=$(cat $p/location)"
done | sort

# 6. errors and drops - non-zero points at cable or power, not config
ip -s link show <if>
```

Steps 1 through 6 cost no cellular data. Only run a transfer once they have told
you what you are looking at.

## Summary

The goal of this article was to find out why a phone advertising 10 Gb/s would not
negotiate above USB 2.0 speed on any cable or port, and what fixing it was worth.
The key to the solution was reading the port peer map rather than the Type-C
connector list, so that a receptacle could be held constant while only the cable
changed. The measured results were:

- **A $15 cable took the bus from 480 to 5000 Mbps** on two handsets, on the same
  physical receptacle, confirming that four earlier unmarked cables were USB 2.0.
- **The pass immediately after the swap was worse, not better** — 21.246 Mbps
  4-stream aggregate against 178 Mbps on a 480 Mbps bus for the same phone.
- **A 1.10x aggregate-to-single ratio proved the constraint was upstream**, ruling
  out congestion-control collapse and per-flow shaping in one reading.
- **The same connection reached 370.695 Mbps aggregate eighteen hours later** — a
  figure above the 300 Mbps realistic ceiling of the bus it replaced, so the cable
  was a precondition for it and the cause of none of it.
- **Four cables and three ports produced an apparent 73 → 130 Mbps improvement that
  was entirely the carrier recovering**, and zero USB errors throughout said so.

Scope: one host, two handsets on AT&T, one physical location, measured 2026-09-05
and 2026-09-06, against a fixed endpoint and a fixed 8 MB transfer size across 45
records. The two SuperSpeed passes changed congestion control as well as the bus —
they ran `cubic` where every 2026-09-05 record ran `bbr` — so throughput is not
cleanly attributable between those two variables from those records alone; the
1.10x aggregate ratio argues congestion control was not the limiter, but that is an
inference and not a measurement. The 300 Mbps USB 2.0 bulk ceiling is the
repository's own diagnostic constant rather than a measurement on this host, and no
control run put the fast evening link back on a USB 2.0 cable. `carrier.network` is
unobtainable on iOS, so a radio change between the morning and evening passes is
unexcluded and is the leading explanation for the seventeen-fold throughput
difference.

The strategy for using a fixed rubric for USB tethering diagnosis was validated with
an incremental step by step approach.
