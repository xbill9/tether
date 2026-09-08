---
title: "The Cable Buys Headroom: 91% of a USB 2.0 Bus, 3.6% of a Thunderbolt One"
published: false
description: "The best USB 2.0 pass in 45 tethering records used 91% of what that bus can usably carry. The same link on a SuperSpeed cable uses 3.6%. USB speed is autonegotiated between host, cable and device, the slowest one wins, and nothing anywhere tells you the cable capped you."
tags: linux, networking, usb, debugging
cover_image: https://raw.githubusercontent.com/xbill9/tether/main/articles/cable-ceiling/devto-cover.567bed21.jpg
---

This article walks through diagnosing a USB tether that would not negotiate above
USB 2.0 speed, on a phone that advertises 10 Gb/s. The hunt took four cables and
three physical ports across two days.

**USB link speed is autonegotiated between the host, the cable and the device, and
the result is the slowest mode all three can manage.** The cable is a full
participant in that negotiation, a USB 2.0 cable has no way to vote for anything
above 480 Mbps, and **nothing anywhere reports that it happened.** The tether comes
up, DHCP works, traffic flows, and the link is capped at a fifth of what both ends
were offering.

What the right cable buys is not speed. It is **headroom**, and the difference is
not subtle: the best USB 2.0 pass in this log used **91% of what that bus can
usably carry**, while the same link on a SuperSpeed cable uses **3.6%**.

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

## The Bus Rate Is Negotiated, and Every Link in the Chain Votes

USB link speed is not a property of the phone, and it is not a property of the
laptop. It is negotiated at every attach between three parties — host controller,
cable, device — and **the trained rate is the fastest mode all three can do.** One
USB 2.0 component anywhere in that chain and the entire link comes up at 480 Mbps.

The cable is a real participant in that vote, not a passive wire. SuperSpeed rides
on two extra differential pairs that a USB 2.0 cable does not physically contain —
it carries `D+`/`D-` and nothing else. Put one between a 10 Gb/s phone and a
10 Gb/s port and the two ends will negotiate down to High Speed and work perfectly.

**And nothing tells you.** No error, no `dmesg` warning, no degraded-mode
indicator, no line anywhere saying a cable capped you. The only evidence is a
number in `sysfs` that you have to go and read, next to a second number saying what
the device had offered:

| Reading | Where | What it is |
|---|---|---|
| `speed` | `/sys/bus/usb/devices/<dev>/speed` | what the three parties **agreed on** |
| BOS descriptor | `lsusb -v -d <vid>:<pid>` | what the device **offered** |

**The gap between those two numbers is the cable's vote.** Steps 1 and 2 below are
those two readings, and everything after them is narrowing down which participant
cast the low one.

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

A 480 reading only means something once you know what the device brought to the
negotiation.

```bash
lsusb -v -d 05ac:12a8 2>/dev/null | grep -A3 "SuperSpeed"
```

The descriptor block at the top of this article is that output. **The device
capability is the control.** Compare the iPhone 16e measured eight minutes before
the fastest pass in this log: it advertises no SuperSpeed capability at all, so its
480 is its own ceiling and no cable on earth will move it.

That single distinction separates "something in the chain voted 480" from "the
phone itself voted 480", and it is free to read. Where the device offers
SuperSpeed and the link trained at High Speed, one of the other two participants is
responsible — and there are only two of them.

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

## What the Cable Unlocked: Headroom

The bus reading is the headline. **Headroom is what it actually buys**, and it is
the number that says whether any of this was worth $15.

The repository's diagnostic constant for the realistic bulk throughput of a
480 Mbps USB 2.0 bus, after protocol overhead, is **300 Mbps**. Measure every pass
in the log as a share of the bus it ran on and the picture is stark:

| Pass | Bus | 4-stream aggregate | Share of the bus |
|---|---|---|---|
| 🥉 Best USB 2.0 pass in the log | 480 | 273 Mbps | **56.9%** of raw — and **91% of usable** |
| 🥈 Anker USB-A to USB-C, BBR | 5000 | **365.185 Mbps** | 7.3% |
| 🥈 Same receptacle, CUBIC | 5000 | **370.695 Mbps** | 7.4% |
| 🥇 Thunderbolt cable | 10000 | **361.330 Mbps** | **3.6%** |
| 🥇 Thunderbolt, BBR | 10000 | 317.250 Mbps | 3.2% |

**91% against 3.6% is the whole argument**, and the two denominators are worth
naming so the comparison is read correctly. The 91% is 273 Mbps against the
**usable** 300 Mbps of a 480 Mbps bus; the 3.6% is 361.330 against the **raw**
10000, because this repository has no measured usable ceiling for a SuperSpeed bus
and inventing one would be worse than the mismatch. Compared raw to raw it is
**56.9% against 3.6%** — a factor of sixteen rather than twenty-five, and the same
conclusion either way.

*Share of the bus is arithmetic throughout — each record's 4-stream aggregate over
its own `bus_speed_mbps`, so 273/480 = 56.9% and 365.185/5000 = 7.3%. The 91%
figure is 273 against the 300 Mbps usable ceiling rather than the raw 480.*

**On USB 2.0 the best pass in 45 records was at 91% of what the bus can usably
carry.** There was nothing left. Every good pass in the 480 era was pressed up
against a ceiling, and the ones that were not were being held down by the carrier
instead.

**On SuperSpeed the same link uses about 7% of the bus.** The cable did not make
anything faster by itself; it moved the ceiling from *just above the traffic* to
*fourteen times above the traffic*, so the tether is now free to take whatever the
radio gives it on any given evening — and this link swings by more than 4x on its
own within minutes.

Four of those measurements also clear the 300 Mbps line outright:

| Measurement | Result | Above 300 Mbps? |
|---|---|---|
| Best 480-era aggregate, 45 records | 273 Mbps | no — 91% of usable |
| 4-stream aggregate, USB-C receptacle | 370.695 Mbps | **yes** |
| 4-stream aggregate, Anker cable under BBR | 365.185 Mbps | **yes** |
| 4-stream aggregate, Thunderbolt | 361.330 Mbps | **yes** |
| Single 32 MB transfer, USB-C receptacle | 351.1 Mbps | **yes** |

**Those numbers were not reachable on a USB 2.0 bus.** Not "would have been
slower" — not reachable. Every one of them needed a cable that could vote for
SuperSpeed. ✅

## Why the Aggregate Is the Test

The four-stream number is doing the work in both tables above, and it is worth
saying why rather than treating it as a second opinion on the single-stream figure.

**Single-stream against four-stream aggregate is the one comparison that separates
"the carrier is slow" from "something on this machine is collapsing."** If four
flows together go much faster than one, the wide-area path has headroom and the
problem is local. If they do not, there is no headroom to find.

The Anker cable's BBR pass is a clean worked example. Single-stream ran
134.930 / 113.576 / 123.229 Mbps — a 1.19x spread — against a four-stream
aggregate of **365.185 Mbps, 2.95x the single-stream mean.**

Read those two numbers together and the link describes itself. Four flows found
nearly three times what one flow did, so the wide-area path plainly had that much
to give and nothing local was collapsing: a 1.19x spread with zero errors and zero
drops leaves no radio loss for congestion control to misread. **The ceiling in
that reading is not on this machine**, which is exactly the state you want to be
in — the tether is out of the way and the only thing left is the radio.

The reverse reading is the one that catches people. Where the aggregate lands on
top of the single-stream figure, four flows found nothing extra, and no amount of
tuning on the host will produce headroom that is not there.

Read the aggregate before you attribute anything to hardware. It is the reading
that tells you whether the answer is even on your side of the link.

## What the Link Reached

Once the bus was out of the way, three passes on this handset across two evenings,
on two cables and two host controllers:

| | 🥇 Thunderbolt, CUBIC | 🥈 USB-C receptacle, CUBIC | 🥉 Anker cable, BBR |
|---|---|---|---|
| Bus speed | **10000 Mbps** | 5000 Mbps | 5000 Mbps |
| Single stream (Mbps) | 151.036 / 119.931 / 147.540 | 134.856 / 143.749 / 129.250 | 134.930 / 113.576 / 123.229 |
| 4-stream aggregate | **361.330** | **370.695** | **365.185** |
| RTT avg | 27.268 ms | 29.601 ms | 36.715 ms |
| RTT mdev | **2.272 ms** | 7.171 ms | 5.597 ms |

**Three aggregates within 3% of each other — 361.330, 370.695 and 365.185 — across
two different cables, two host controllers, two congestion control algorithms and a
bus that differs by 2x.** None of those variables moved the number. The link
settles around 365 Mbps and the hardware underneath it has stopped mattering,
which is what having headroom looks like.

The RTT came with it: 27.268 ms average with `mdev` of **2.272 ms** on the
Thunderbolt pass, the flattest jitter anywhere in the log.

The BBR column is worth its place for a second reason. Every early SuperSpeed pass
ran `cubic` where the 480-era records ran `bbr`, so bus and congestion control had
moved together and neither could be credited. Matched on the same port and bus,
BBR gives 365.185 against CUBIC's 370.695 — within a few percent, with `mdev`
slightly lower. **The bus is what these figures rest on.**

## Buy Headroom Once, and Stop

Note the third column of that table: moving from the Thunderbolt port back to a
plain USB-C receptacle **halved the bus and cost nothing** — 370.695 Mbps against
361.330. At 361 Mbps the phone is using about 3.6% of a 10000 Mbps bus, by
arithmetic, against 7.4% of a 5000 Mbps one. Both are miles of headroom. Doubling
an already-idle ceiling buys exactly nothing, and Gen 2 is not worth chasing on a
tether.

So the rule is narrow and cheap:

- ✅ **One known-good cable, then stop.** Four unmarked cables cast four identical
  480 votes. One rated cable produced 5000 on two different handsets, on the same
  receptacle, with nothing else changed.
- ✅ **Read the bus before you tune anything.** `cat /sys/bus/usb/devices/<dev>/speed`
  is free, and a 480 reading on a SuperSpeed-capable phone caps you at roughly
  300 Mbps of real throughput no matter what else you fix.
- ✅ **Do not buy ceiling you cannot reach.** 5000 and 10000 measured the same on
  this link, repeatedly. Headroom is binary in practice: you either have enough or
  you do not.
- ❌ **Do not trust the connector to tell you.** Two of the four failing cables were
  USB-C on both ends, in a Thunderbolt 4 port, on a phone advertising 10 Gb/s.
  Every visible part of that chain looked right.

**One limit on all of this, and it is being closed by measurement rather than
argument.**
The 300 Mbps figure is the repository's diagnostic constant, so the claim above is
a bound argument rather than a controlled A/B — no pass has yet put the fast link
back onto a USB 2.0 cable to measure what it would cost. That controlled re-test is
queued, and it is the number this article most wants.

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

Both of these are in the repository and run directly, no arguments needed:

```bash
bin/tether-bus-check      # everything below, plus a verdict. No cellular data
bin/tether-report         # the full diagnostic rubric. No cellular data
bin/tether-report --measure   # the standard pass. ~56 MB of metered data
bin/tether-interleave     # A/B two transfer sizes against a moving link
```

`tether-bus-check` reads both sides of the negotiation and says which participant
cast the low vote. `tether-interleave` is the design from the section above —
alternating sizes back to back so link drift falls on both equally — and it prints
the cost before it spends it.

The individual readings, if you would rather run them by hand:

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
The key to the solution was treating the link rate as a three-way negotiation and
reading both sides of it — what the link agreed on against what the device
offered — then reading the port peer map rather than the Type-C connector list, so
that a receptacle could be held constant while only the cable changed. The measured results were:

- **A $15 cable took the bus from 480 to 5000 Mbps** on two handsets, on the same
  physical receptacle, confirming that four earlier unmarked cables voted 480.
- **The Pixel 9a's negotiated link went 425 to 3750 Mbps**, 8.8x, with the
  receptacle and the DHCP lease held constant.
- **Headroom went from 91% consumed to about 7% consumed.** The best USB 2.0 pass
  in 45 records used 91% of what that bus can usably carry; the best SuperSpeed
  passes use 7.3% and 7.4% of theirs.
- **Four aggregates cleared 300 Mbps** — 370.695, 365.185 and 361.330, plus a
  351.1 Mbps single 32 MB transfer — none of them reachable on a USB 2.0 bus.
- **5000 and 10000 Mbps of bus measured the same** — 370.695 against 361.330 — so
  once the ceiling clears the traffic, more ceiling buys nothing.
- **Four cables and three ports produced an apparent 73 → 130 Mbps improvement that
  was entirely the carrier recovering**, and zero USB errors throughout said so.

Scope: one host, two handsets on AT&T, one physical location, measured 2026-09-05
and 2026-09-06, against a fixed endpoint and a fixed 8 MB transfer size across 45
records. The first SuperSpeed passes moved congestion control alongside the bus,
running `cubic` where the 2026-09-05 records ran `bbr`; that confound has since
been closed by matched BBR passes on 2026-09-08 — 365.185 Mbps aggregate against
the CUBIC pass's 370.695 on the same port and bus — so the bus, not the congestion
control, is what the SuperSpeed figures rest on. The 300 Mbps USB 2.0 bulk ceiling
is the repository's own diagnostic constant rather than a measurement on this host,
so the claim that the fast figures were unreachable on the old cable is a bound
argument; no control run has yet put the fast link back onto a USB 2.0 cable, and
that re-test is queued. `carrier.network` is unobtainable on iOS, so carrier
conditions across passes cannot be read directly and are inferred from RTT.

The strategy for using a fixed rubric for USB tethering diagnosis was validated with
an incremental step by step approach.
