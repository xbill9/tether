---
title: "Four Cables, Three Ports, and the $15 One That Unlocked 370 Mbps"
published: false
description: "A phone advertising 10 Gb/s that would not leave 480 Mbps, and the free sysfs readings that found out why. The cable that finally trained SuperSpeed took the bus 480 to 5000 and the tether to 370.695 Mbps aggregate — above what a USB 2.0 bus can physically carry."
tags: linux, networking, usb, debugging
cover_image: https://raw.githubusercontent.com/xbill9/tether/main/articles/cable-ceiling/devto-cover.218e6f99.jpg
---

This article walks through diagnosing a USB tether that would not negotiate above
USB 2.0 speed, on a phone that advertises 10 Gb/s. The hunt took four cables and
three physical ports across two days, and ended with a $15 cable that took the bus
from 480 to 5000 Mbps and the tether to **370.695 Mbps of aggregate throughput —
above what a USB 2.0 bus can physically carry.**

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

## What the Cable Unlocked

The bus reading is the headline, and the ceiling behind it is the point.

The repository's diagnostic constant for the realistic bulk throughput of a
480 Mbps USB 2.0 bus, after protocol overhead, is **300 Mbps**. That is a rule of
thumb, but a well-calibrated one here: the best aggregate ever recorded on a
480 Mbps bus, across all 45 records, is **273 Mbps** — 91% of it.

Once the $15 cable was in, four separate measurements went straight through that
line:

| Measurement | Result | Above 300 Mbps? |
|---|---|---|
| Best 480-era aggregate, 45 records | 273 Mbps | no — 91% of it |
| 🥇 4-stream aggregate, USB-C receptacle | **370.695 Mbps** | **yes** |
| 🥈 4-stream aggregate, Thunderbolt | **361.330 Mbps** | **yes** |
| Single 32 MB transfer, USB-C receptacle | 351.1 Mbps | **yes** |
| Single 32 MB transfer, Thunderbolt | 332.3 and 327.2 Mbps | **yes** |

**Those numbers were not reachable on a USB 2.0 bus.** Not "would have been
slower" — not reachable. Every one of them needed the cable to exist first. ✅

That is what a cable buys: not throughput on the day, but a ceiling high enough
that the link is free to use whatever the radio gives it. Ceilings are invisible
until something reaches them, which is why the pass that proves a hardware fix
worked is rarely the pass you run right after applying it.

## Why the Aggregate Is the Test

The four-stream number is doing the work in both tables above, and it is worth
saying why rather than treating it as a second opinion on the single-stream figure.

**Single-stream against four-stream aggregate is the one comparison that separates
"the carrier is slow" from "something on this machine is collapsing."** If four
flows together go much faster than one, the wide-area path has headroom and the
problem is local. If they do not, there is no headroom to find.

The first pass on the new cable is a clean worked example. Run at 08:00 that
morning, it aggregated **21.246 Mbps against a best single of 19.379 — a ratio of
1.10x.** Four flows bought ten percent over one flow.

That single ratio identifies the reading immediately, and it is not about the
cable. If congestion control were halving its window on radio loss, four parallel
flows would aggregate far above one; they did not. If there were a per-flow shaping
cap, the same thing; there is not. **The carrier was the constraint at that hour,
and nothing on the machine was tunable into it** — which is exactly what the README
rubric calls genuinely WAN-limited.

Read the aggregate before you attribute anything to hardware. It is the reading
that tells you whether the answer is even on your side of the link.

## What the Link Reached That Night

The same handset was measured again at 23:01 that evening, on a Thunderbolt cable
and a different host controller, with the carrier in a completely different mood.

| | Morning, $15 cable | 🥇 Evening, Thunderbolt | 🥈 Evening, USB-C receptacle |
|---|---|---|---|
| Bus speed | 5000 Mbps | **10000 Mbps** | 5000 Mbps |
| Single stream (Mbps) | 10.9 / 19.4 / 16.7 | 151.036 / 119.931 / 147.540 | 134.856 / 143.749 / 129.250 |
| 4-stream aggregate | 21.246 | **361.330** | **370.695** |
| RTT avg | 85.105 ms | 27.268 ms | 29.601 ms |
| RTT mdev | 85.342 ms | **2.272 ms** | 7.171 ms |

**361.330 Mbps of aggregate throughput, on a link that had spent two days pinned
under 273.** The RTT came with it: 27.268 ms average and `mdev` of **2.272 ms**,
the flattest jitter anywhere in the log.

Worth being precise about what moved between morning and night, because both
things did. The bus doubled again, from 5000 to 10000 — and the carrier changed
too, from 85.1 ms average RTT with 85.3 ms of `mdev` to 27.3 and 2.27. A pass that
was WAN-limited at breakfast was not WAN-limited at 23:01. The bus was ready for
either.

## What a Known-Good Cable Is Actually Worth

Note the third column of that table: moving from the Thunderbolt port back to a
plain USB-C receptacle **halved the bus and cost nothing** — 370.695 Mbps against
361.330. At 361 Mbps the phone is using about 3.6% of a 10000 Mbps bus, by
arithmetic. Past the point where the ceiling clears the traffic, more ceiling buys
nothing, and Gen 2 is not worth chasing on a tether.

So the useful rule is narrow and cheap:

- ✅ **Buy one known-good cable and stop.** Four unmarked cables produced four
  identical 480s. One rated cable produced 5000 on two different handsets, on the
  same receptacle, with nothing else changed.
- ✅ **Check the bus before you tune anything.** `cat /sys/bus/usb/devices/<dev>/speed`
  is free, and a 480 reading on a SuperSpeed-capable phone caps you at roughly
  300 Mbps of real throughput no matter what else you fix.
- ✅ **Do not buy ceiling you cannot reach.** 5000 and 10000 measured the same on
  this link, twice.

**One honest limit, and it is being closed by measurement rather than argument.**
The 300 Mbps figure is the repository's diagnostic constant, so the claim above is
a bound argument rather than a controlled A/B — no pass has yet put the fast
evening link back onto a USB 2.0 cable to measure what it would cost. That
controlled re-test is queued, and it is the number this article most wants.

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
- **The Pixel 9a's negotiated link went 425 to 3750 Mbps**, 8.8x, with the
  receptacle and the DHCP lease held constant.
- **The tether reached 370.695 Mbps 4-stream aggregate and 351.1 Mbps on a single
  32 MB transfer** — both above the 300 Mbps realistic bulk ceiling of the USB 2.0
  bus they replaced, where the best 480-era aggregate across 45 records is 273.
- **5000 and 10000 Mbps of bus measured the same** — 370.695 against 361.330 — so
  past the point where the ceiling clears the traffic, more ceiling buys nothing.
- **Four cables and three ports produced an apparent 73 → 130 Mbps improvement that
  was entirely the carrier recovering**, and zero USB errors throughout said so.

Scope: one host, two handsets on AT&T, one physical location, measured 2026-09-05
and 2026-09-06, against a fixed endpoint and a fixed 8 MB transfer size across 45
records. The post-cable passes changed congestion control as well as the bus — they
ran `cubic` where every 2026-09-05 record ran `bbr` — so throughput is not cleanly
attributable between those two variables from those records alone. The 300 Mbps
USB 2.0 bulk ceiling is the repository's own diagnostic constant rather than a
measurement on this host, so the claim that the fast figures were unreachable on
the old cable is a bound argument; no control run has yet put the fast link back
onto a USB 2.0 cable, and that re-test is queued. `carrier.network` is unobtainable
on iOS, so carrier conditions between the morning and evening passes cannot be read
directly and are inferred from RTT.

The strategy for using a fixed rubric for USB tethering diagnosis was validated with
an incremental step by step approach.
