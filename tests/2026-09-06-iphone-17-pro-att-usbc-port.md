---
id: 2026-09-06-iphone-17-pro-att-usbc-port
date: 2026-09-06
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)   # read over usbmuxd (ideviceinfo); corroborated by bcdDevice=18.01
  os: iOS 27.0                        # read over usbmuxd (ideviceinfo -k ProductVersion)
carrier:
  name: AT&T         # operator-supplied earlier this session; delegation unchanged from the Thunderbolt pass
  network:           # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 5000
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable:              # TODO not re-confirmed after the port move - see Issues
link:
  interface: enxb65575abcda3
  ipv4: 172.20.10.5/28
  gateway: 172.20.10.1
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: cubic
  slow_start_after_idle: 1
  mtu_probing: 0
results:
  single_stream_mbps: [134.856, 143.749, 129.250]
  parallel_4_aggregate_mbps: 370.695
  rtt_ms:
    min: 15.308
    avg: 29.601
    max: 33.787
    mdev: 7.171
  errors: 0   # RX+TX delta across the pass; all cumulative counters 0 -> 0
  drops: 0    # RX+TX delta across the pass; all cumulative counters 0 -> 0
verdict: good
---

# iPhone 17 Pro on AT&T - the USB-C receptacle, as a bus control

The operator moved the phone from the Thunderbolt port to the USB-C receptacle
to see whether it changed anything. It did not, and that is the point of the
record: it turns "the bus was never the constraint" from an argument about
headroom into a measured control.

Companion to the
[Thunderbolt pass](2026-09-06-iphone-17-pro-att-thunderbolt.md) taken about
twenty minutes earlier. Same handset, same cable so far as is known, same
session.

## Setup

Measured 2026-09-06, ~23:15 EDT. The phone moved from `0000:00:0d.0` / `usb2`
(the Thunderbolt controller, bus 10000) to `0000:00:14.0` / `usb4` as device
`4-1`, bus **5000**. `usb4-port1` reports `peer=usb3-port1` at
`location=0x80000101`, so this is the USB-C receptacle on the main controller.

The interface name and DHCP lease survived the move - still `enxb65575abcda3`
on `172.20.10.5/28` - so no re-identification was needed. `ideviceinfo` returned
`iPhone18,1` before and after, the bus still read 5000 afterwards, `wlo1` was
`DOWN` with `NO-CARRIER`, and `ip route show default` named the tether
throughout.

**This receptacle settles the iPhone 16e's ceiling by direct comparison.** The
[16e record](2026-09-06-iphone-16e-google-fi-cubic.md) argued that its 480 Mbps
was the device's own limit rather than the port, from a BOS descriptor with no
SuperSpeed capability. The 17 Pro on that same receptacle - same
`location=0x80000101` - trains SuperSpeed and enumerates at 5000. The port was
never the problem, and that is now measured rather than inferred.

## Observations

Single-stream **134.9 / 143.7 / 129.3 Mbps**, a 1.11x spread. Parallel-4
aggregated **370.7 Mbps**. RTT averaged 29.6 ms with `mdev` 7.17.

**Halving the bus changed nothing.** Against the Thunderbolt pass the aggregate
moved from 361.3 to 370.7 Mbps, +2.6%, while the bus ceiling went from 10000 to
5000. The earlier record predicted exactly this on the grounds that 361 Mbps is
3.6% of a 10 Gbps bus, and the prediction held. A 2x change in the ceiling
producing a 1.026x change in throughput is as clean a null as this log has.

The RTT is the one number that moved: `mdev` 2.27 -> 7.17 ms and `min` 23.8 ->
15.3 ms. Both passes are on the same carrier minutes apart, so this is more
likely radio variation than anything about the port - see below, because that
variation turned out to matter a great deal.

### The transfer-size diagnostic, and what it did to the earlier conclusion

The Thunderbolt record concluded that the single-vs-aggregate gap was an
artifact of the fixed 8 MB transfer size. Testing that further here **weakened
it rather than confirming it.** Same port, same session:

| transfer | throughput |
|---|---|
| 8 MB x3 | 134.9 / 143.7 / 129.3 Mbps |
| 20 MB x1 | **73.0 Mbps** |
| 32 MB x1 | 351.1 Mbps |

A fixed-overhead model fitted to the 8 MB and 32 MB points (asymptote 743 Mbps,
fixed cost 0.385 s) predicts **266.7 Mbps** at 20 MB. A model with no
size dependence at all predicts ~136 Mbps. **The measurement came in at 73.0
Mbps, below both.** The prediction was stated before the transfer was run.

So throughput here is not a monotonic function of transfer size, and **the link
varies by at least 4.8x at a fixed size within minutes** (73.0 against 351.1).
That variation is larger than the 8-vs-32 MB effect it was invoked to explain,
which means the earlier comparison was not controlled for time. The
transfer-size hypothesis is not refuted, but it is no longer established.

**What does survive is narrower and still solid:** a single flow reached 351.1
Mbps here and 327-332 Mbps on the Thunderbolt port, against 4-stream aggregates
of 370.7 and 361.3. One flow has repeatedly matched the aggregate. **A per-flow
cap near 140 Mbps is inconsistent with that**, whatever the reason the 8 MB
transfers sit there.

### Sender-side congestion window - obtained, and it does ramp

The Thunderbolt record said the cwnd evidence could not be gathered. That was
wrong in its reasoning: `ss -ti` on this host reports *our* send window, which
for a download carries only ACKs and sits at 10 the whole time. It is the
server's window that governs, and Cloudflare publishes it - the `server-timing:
cfL4` response header carries `cwnd`, `rtt`, `retrans`, `lost` and
`delivery_rate` for the server's socket.

Read on a keep-alive connection immediately before and after the 20 MB
transfer:

| | cwnd | retrans | lost |
|---|---|---|---|
| before | 53 | 0 | 0 |
| after | **702** | 0 | 0 |

The sender's window grew 13x across one transfer **with no loss and no
retransmission at all**, and the server's own `delivery_rate` estimate came out
at 95,387,019 B/s (763 Mbps) against the 73.0 Mbps actually achieved. So the
sender was neither congestion-limited nor loss-limited; it believed it could go
an order of magnitude faster than the transfer managed. That points the
bottleneck downstream of the server - the radio, the tether, or this host - and
is consistent with delivery arriving in bursts separated by stalls.

This is direct evidence that a window ramp exists and is large. It does **not**
establish that the ramp explains the 8-vs-32 MB gap, because the 20 MB transfer
in which it was measured was the slow one.

### Interleaved 8/32 MB - the size effect is real after all

The follow-up above was run the same evening on this port, and it settles the
question the 20 MB sample had reopened. Six transfers on fresh connections,
alternating 8 and 32 MB, **the whole experiment spanning 3.89 seconds** so that
link variation cannot fall differently on the two sizes:

| # | size | t+ | duration | throughput |
|---|---|---|---|---|
| 1 | 8 MB | 0.51 s | 0.418 s | 153.3 Mbps |
| 2 | 32 MB | 1.32 s | 0.722 s | 354.6 Mbps |
| 3 | 8 MB | 1.87 s | 0.438 s | 146.1 Mbps |
| 4 | 32 MB | 2.66 s | 0.701 s | 365.1 Mbps |
| 5 | 8 MB | 3.09 s | 0.362 s | 176.9 Mbps |
| 6 | 32 MB | 3.89 s | 0.699 s | 366.3 Mbps |

8 MB mean **158.75** Mbps (1.21x spread); 32 MB mean **361.96** Mbps (1.03x
spread); ratio **2.28x**. Every 32 MB transfer beat the 8 MB transfer next to it
- 3 of 3 pairs - and **the distributions do not overlap at all**: the fastest
8 MB run (176.9) is below the slowest 32 MB run (354.6).

**Transfer size determines the result here. That is now established**, and the
retraction in the [Thunderbolt
record](2026-09-06-iphone-17-pro-att-thunderbolt.md) went one step too far. The
earlier uncontrolled comparison happened to reach the right conclusion for
inadequate reasons; this design reaches it for adequate ones.

It also puts the 20 MB sample in its place. A fixed-overhead fit to these
durations - 8 MB in 0.4058 s, 32 MB in 0.7074 s, four times the bytes in 1.74x
the time - gives an asymptote of **637 Mbps** and a fixed cost of **0.305 s**,
which predicts 287 Mbps at 20 MB. The 20 MB run measured 73.0. So that sample
was a genuine collapse of the link at that moment, not evidence about size; the
link can fall by 4.8x on its own, which is exactly why the interleaving was
necessary.

**The mechanism is still not pinned.** A 0.305 s fixed cost is about **10 RTTs**
at this link's 29.6 ms, where slow-start from the server's observed initial
window to the ~503 KB BDP should need roughly 6. Something beyond textbook
slow-start contributes to the startup cost, and these six transfers cannot say
what. Note also that Cloudflare's `cfL4` header reported `cwnd=53` at the start
of all six connections, not the Linux default of 10, so the server's initial
window is not the textbook one either.

## Issues

None affecting the recorded pass: zero errors, zero drops, no interface bounce,
no route change, device identity confirmed before and after.

Three diagnostic obstacles, all outside the standard pass:

- **`speed.cloudflare.com/__down` refuses some sizes.** 12, 15, 16, 16.78 and
  17 MB all return `403 Forbidden` with a 1-byte body, while 8, 20, 24 and 32 MB
  return 200. Reproduced with the sizes interleaved, so it is neither rate
  limiting nor transient. The reason is unknown. The intended third data point
  was 16 MB; 20 MB was substituted for this reason.
- **Receiver-side `ss` cannot see the download's congestion window**, as above.
  The earlier record attributed this to a sampling failure on a short transfer;
  the real cause is structural.
- **`cfL4` reports the server's socket at header time**, so the "before" and
  "after" readings come from separate requests on a keep-alive connection rather
  than a trace through one transfer.

`usb.cable` is left blank: the phone moved receptacles and the cable was not
re-confirmed afterwards. It is presumably the same Thunderbolt cable, but the
last time a cable was assumed in this log it was assumed wrongly, so it stays a
`# TODO`.

## Follow-ups

- **Interleaved A/B on transfer size is now the only way to settle it.**
  Alternate 8 MB and 32 MB transfers - 8/32/8/32/8/32 - so that link variation
  hits both sizes equally. Roughly 120 MB metered. Nothing short of this
  separates the two, given a link that moved 4.8x at fixed size tonight.
- Re-read `cfL4` on a *fast* transfer. Every cwnd figure here comes from the
  slow 20 MB run; the same before/after on a 32 MB run that achieves 350 Mbps
  would say whether the window behaves differently when the link cooperates.
- The size-dependent 403 is worth a note wherever the endpoint is documented, so
  the next person choosing a diagnostic size does not lose a transfer to it.
