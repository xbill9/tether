---
title: "Generosity Is a Default Setting"
published: false
description: "A USB tethering diagnostic that costs no cellular data to run, forty measurements across fourteen phones, and one free setting that took the worst run from 15 to 106 Mbps."
tags: weekendchallenge, linux, networking, python
cover_image: https://raw.githubusercontent.com/xbill9/tether/main/articles/tether-report/devto-cover.07de6d03.jpg
---

International Day of Charity falls on September 5, and the most generous thing in
most software is not a donation button. It is a default.

Defaults decide what happens to everyone who never opens the settings, which is
almost everyone. A default that quietly spends a resource its user is short of is
a small unkindness repeated at scale. A default that does not is a gift nobody
has to ask for.

Here is one worth changing. For a lot of people the phone is not a second
connection — it is the connection, and tethering is how the laptop gets online
without a second line, a second bill, or a router that has to be bought before
anything works. That tether is often far slower than the radio it sits on, the
reason is usually on the laptop rather than the carrier, and **the fix is a
default setting that costs nothing to change.**

This is a tool that finds out which problem you have without spending your data
to do it, and the survey that taught it what to look for.

Repository: https://github.com/xbill9/tether

## What I Built

`tether-report` reads every host-observable fact about an attached USB tether,
applies a diagnostic rubric, and prints a markdown report telling you what is
wrong and what to change.

**By default it measures nothing and costs no cellular data.**

That default is the whole point. The standard measurement pass in this repo is
three single-stream transfers, a four-stream parallel test and a ping — roughly
56 MB of metered data. On an unlimited home plan that is nothing. On a prepaid
plan bought by the gigabyte, spending 56 MB to discover that your problem is a
one-line setting is a bad trade, and it is exactly the trade most speed-test
tools make you take before they tell you anything.

So the tool splits the two. Everything the kernel already knows — the driver, the
bus speed, the negotiated link rate, the MTU ceiling, the NCM aggregation
buffers, the congestion control algorithm, the interface error counters — is free
to read, and most real problems are visible in it. `--measure` is opt-in, and it
prints what it will cost before it spends it.

The rubric it applies is the same one the survey was written against:

| Shape | Diagnosis | Where the fix is |
|---|---|---|
| 🥇 Single-stream spread wide, RTT flat | Congestion control collapsing on radio loss | **Your laptop.** Free |
| Single ≈ 4-stream aggregate | Genuinely WAN-limited | Nowhere. Nothing to tune |
| Aggregate near 300 Mbps on a 480 Mbps bus | USB 2.0 ceiling | Cable or port |
| RTT `mdev` high, average unchanged | Bufferbloat | Depends what you run |
| Spread flat, aggregate far above single | Per-flow limit or shaping | Carrier, probably |

The first row is the one worth having, because it is the only one where the
answer is both free and on your side of the link.

## Demo

A Pixel 9a on Google Fi, attached over USB-C. This is a real run, captured while
writing this article, and it spent **no cellular data at all**:

```
$ python3 bin/tether-report
```

It opens with what the link actually is:

| | |
|---|---|
| Interface | `enxce1d58e89c0f` |
| Driver | `cdc_ncm` |
| IPv4 | `10.244.144.215/24` |
| MTU / max | 1500 / 1500 |
| Negotiated link | 425 Mbps |
| Holds default route | yes |

Then the bus, which is where the ceiling usually is:

| | |
|---|---|
| Device | `3-2` 18d1:4eec - Pixel 9a |
| Bus speed | **480 Mbps** (USB 2.0) |
| BOS capability | SuperSpeed |
| Type-C connector | `port1` |

And then the part that matters — the rubric's verdict on all of it:

> ### BLOCKER: Another route-capable link is up
>
> `wlo1` is up alongside the tether. If the tether drops mid-run, curl still
> succeeds and the result looks like a tethering measurement. Take these down
> first.

> ### Problem: Device can do better than 480 Mbps
>
> The device advertises SuperSpeed in its BOS descriptor but enumerated at
> 480 Mbps. Connector `port1` has an enumerated SuperSpeed half, so the host is
> declared capable and **the cable is the leading suspect** — an unmarked C-to-C
> cable is very often USB 2.0.

> ### Note: NCM aggregation buffers
>
> `rx_max=16384`, `tx_max=16384`. Compare these against the device-advertised
> `dwNtbInMaxSize`/`dwNtbOutMaxSize`: **if they already match, the common "raise
> these to 32768" advice is a no-op** and changing them will do nothing.

> ### Note: No measurements taken
>
> Run again with `--measure` for the throughput and latency half of the rubric.
> That costs roughly 56 MB of metered cellular data.

Four useful things about this link, and the price was zero.

The blocker is the one I want to point at. Wi-Fi was still up, so any transfer
run at that moment could have gone out over Wi-Fi and come back looking like a
tethering result. That is not a hypothetical — it is the most common way a
tethering measurement quietly becomes a measurement of something else, and a
tool that charged you 56 MB before mentioning it would have charged you for a
number that meant nothing.

The last note is the design in one line. It did not measure. It told me what
measuring would cost and let me decide.

*One difference from the records in this repo: the tether was enabled here with
`adb shell svc usb setFunctions ncm` rather than the phone's own tethering
toggle, and it enumerated as `18d1:4eec` where the recorded passes show
`18d1:4eeb`. Same driver and same interface, slightly different USB function
composition.*

## Code

Everything is in one public repository: https://github.com/xbill9/tether

| Path | What it is |
|---|---|
| `bin/tether-report` | The diagnostic. One file, standard library only |
| `README.md` | The format spec, field reference and the diagnostic rubric |
| `tests/` | 40 measurement records, one markdown file each |
| `INDEX.md` | One row per test |
| `TEMPLATE.md` | The skeleton a new record is copied from |

`tether-report` has no dependencies beyond the Python standard library and the
`curl`, `ping` and `ip` binaries. That is deliberate: a tool for people on
expensive connections should not begin by downloading a dependency tree.

```
git clone https://github.com/xbill9/tether
cd tether
python3 bin/tether-report
```

No install step, no virtualenv, no package manager. If it runs, it runs.

## How I Built It

### The measurements came first, the tool second

The tool is a rubric with a reader attached, and the rubric came out of taking
the same measurement forty times and noticing which distinctions actually
separated one failure from another.

Three rules turned out to matter, and all three exist because ignoring them
produced a wrong answer first:

**Record three runs, never one.** The Pixel 9a produced 15, 44 and 116 Mbps on
three consecutive identical transfers. Any one of those numbers, reported alone,
is a lie about the link. The spread is the finding.

**Always run the parallel test too.** Single-stream against four-stream aggregate
is the one comparison that separates "the carrier is slow" from "congestion
control is collapsing on this machine". If four streams together go much faster
than one, the WAN has headroom and the problem is local. That distinction drove
every fix worth making.

**Record the congestion control algorithm.** It is the largest single lever
available, and a record without it cannot be interpreted.

### The finding

Same phone, same cable, same session. Only the host TCP settings changed:

```
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
```

| | Single-stream runs (Mbps) | Spread | RTT avg | RTT mdev |
|---|---|---|---|---|
| CUBIC, as shipped | 15 / 44 / 116 | **7.73x** | 29.6 ms | 4.1 ms |
| BBR | 125 / 153 / 106 | **1.44x** | 29.7 ms | 5.8 ms |

The worst run went from **15 Mbps to 106 Mbps**. Average round-trip time did not
move — 29.6 to 29.7 ms — which is what rules out the boring explanation that BBR
simply bought throughput by filling a queue.

The mechanism is that CUBIC treats packet loss as a congestion signal. A radio
drops packets for reasons that have nothing to do with congestion, CUBIC halves
its window anyway, and a single flow spends its life recovering. BBR models the
path instead of reacting to loss, so random drops stop being interpreted as a
full pipe.

### The part that generalises, and the part that does not

**This is a mechanism argument, not a second measurement, and it should be read
as one.** CUBIC's failure is triggered by random loss. Weak signal produces more
random loss. So the worse the radio, the more this setting should be worth — and
the people on the worst radios are the ones for whom a free fix matters most.

I have not measured that. Every record in this survey was taken on Google Fi or
AT&T, in one location, on networks whose 120 individual transfers ran from 5.3 to
163.0 Mbps with a median of 69.8. Nothing here was collected anywhere
under-served, and I am not going to claim otherwise.
What I can say is that the mechanism does not depend on geography, that the fix
costs nothing to try, and that `tether-report` will tell you for free whether
your link has the shape the fix addresses.

### What the survey actually showed

Across 40 records and 14 handsets:

- **Every single record enumerated at 480 Mbps.** Fourteen handsets, three
  drivers, and not one USB 3.0 negotiation anywhere in 40 records. The bus is a
  more consistent ceiling than the radio. On the one phone chased hardest — an
  iPhone 17 Pro that advertises SuperSpeedPlus — 480 survived four cables and
  three physical ports, and that hunt is still open in the repo. No cable tried
  was verifiably wired for SuperSpeed, so those four results may be closer to one
  result repeated.
- **The driver is not the story.** `cdc_ncm`, `rndis_host` and `ipheth` all
  appear at both ends of the results.
- **The radio label predicts nothing.** Two Galaxy S24 units differing only in
  radio — 5G against LTE — and the LTE unit won on every measure, including
  14.4 ms of round-trip time.
- **Re-running the same phone moves the answer more than changing phones does.**
  Which is the finding that makes a single-run speed test close to worthless.

### Scope and limits

Forty records, fourteen handsets, two carriers (Google Fi and AT&T), one host, one
physical location, all on 2026-09-05. The endpoint and transfer size are fixed by
the README so records stay comparable. The CUBIC-against-BBR comparison rests on
**two** CUBIC records against 38 BBR ones, so it should be read as a strong result
on one phone plus a consistent second case, not as a survey-wide average. Radio
type is unrecorded on several records because a reading taken after a pass does
not establish what was in use during it, and those fields are left blank rather
than guessed. No measurement in this repository has ever been edited; a re-test
after a configuration change is always a new file.

## Three defaults, and who pays for them

The theme this weekend is generosity, and the argument of this piece is that
defaults are where most of it either happens or does not. Three of them here:

1. **The diagnostic's default spends nothing.** Reading the kernel is free, so
   the free half does the diagnosing and `--measure` is opt-in and prices itself
   before it runs. The alternative default — measure first, explain later — bills
   the user in the exact currency they came in short of.
2. **The fix is a default someone else already chose for you.** CUBIC ships as
   the kernel's congestion control, it is the wrong choice on a lossy radio, and
   changing it costs no hardware, no plan change and no subscription. Every phone
   in this survey was carrying that cost silently until it was measured.
3. **The method is published, not just the conclusion.** The rubric, the record
   format, all 40 records and the reasoning behind them are in the repository,
   against a fixed endpoint and transfer size so a stranger's numbers compare to
   these. A conclusion you cannot check is a thing you have to take on trust; a
   method is a thing you can own.

The most useful thing I can give someone whose connection is their phone is not
my numbers. It is a way to get their own, at no cost, and a fix that was already
paid for before they arrived.

## Prize Categories

None. This entry does not use Snowflake, Solana, ElevenLabs or Google AI, so it
is submitted to the overall category only.

## Summary

The goal of this article was to make a slow USB tether diagnosable without
spending metered data to diagnose it. The key to the solution was separating what
the kernel already knows from what has to be paid for in bytes, and putting the
entire rubric on the free side. The measured results were:

- Worst single-stream run moved from **15 Mbps to 106 Mbps** on one free setting
- Single-stream spread collapsed from **7.73x to 1.44x**
- Round-trip time was unchanged at **29.6 against 29.7 ms**, ruling out queue depth
- **40 records, 14 handsets, 0 that negotiated USB 3.0**

Measured on one host across two US carriers in a single location on 2026-09-05,
three single-stream runs plus a four-stream parallel pass per record, against a
fixed endpoint and transfer size; the congestion-control comparison rests on two
CUBIC records against 38 BBR ones.

The strategy for using a fixed rubric for tethering diagnosis was validated with
an incremental step by step approach.
