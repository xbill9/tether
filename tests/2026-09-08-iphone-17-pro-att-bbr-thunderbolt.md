---
id: 2026-09-08-iphone-17-pro-att-bbr-thunderbolt
date: 2026-09-08
phone:
  make: Apple
  model: iPhone 17 Pro (iPhone18,1)   # read over usbmuxd (ideviceinfo); corroborated by bcdDevice=18.01
  os: iOS 27.0                        # read over usbmuxd (ideviceinfo -k ProductVersion)
carrier:
  name: AT&T         # not re-confirmed this session; delegation is 2600:381::/32, matching this handset's earlier records
  network:           # TODO not obtainable - iOS exposes no adb equivalent for cellular radio type
usb:
  vendor_id: "05ac"
  product_id: "12a8"
  driver: ipheth
  bus_speed_mbps: 10000
  negotiated_link_mbps:   # ipheth does not report one - /sys/class/net/<if>/speed returns EINVAL
  cable:                  # TODO operator not asked; the port move was made by the operator mid-session
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
  single_stream_mbps: [115.395, 125.698, 129.642]
  parallel_4_aggregate_mbps: 282.496
  rtt_ms:
    min: 22.241
    avg: 36.516
    max: 44.817
    mdev: 8.159
  errors: 0   # RX+TX delta across the pass; all cumulative counters 0 -> 0
  drops: 0    # RX+TX delta across the pass; all cumulative counters 0 -> 0
verdict: good
---

# iPhone 17 Pro on AT&T - Thunderbolt under BBR, and a link that decayed

The fourth variable-isolating pass on this handset and the cleanest control in
the log: same phone, same session, same DHCP lease, **only the host port
changed** from the
[BBR pass an hour earlier](2026-09-08-iphone-17-pro-att-bbr.md). It is also
the direct BBR counterpart of the
[2026-09-06 Thunderbolt record](2026-09-06-iphone-17-pro-att-thunderbolt.md),
which ran the same port and bus under CUBIC.

The measurements are good. **The most useful thing in this record is that the
link degraded while it was being measured**, which is documented below rather
than smoothed over.

## Setup

Measured 2026-09-08, immediately after the BBR pass on the other port. The
operator moved the phone to the Thunderbolt receptacle and it re-enumerated at
`2-1` on **`0000:00:0d.0` / `usb2` - the Thunderbolt 4 controller** - at
**10000**, the log's second 10000 reading and the highest bus available on this
machine.

`ipheth` re-bound as `enxb65575abcda3`. The name and MAC are unchanged from the
previous pass, but **the netdev is a new one**: the interface counters reset to
zero at the move, which is how the re-attach was confirmed. The DHCP lease
survived at `172.20.10.5/28`, so the phone did not restart its tether session -
only the host-side link was recreated. `ideviceinfo` returned `iPhone18,1` and
`27.0` before and after, with the bus still reading 10000 afterwards, so the
same device carried the whole pass.

TCP settings were unchanged from the earlier pass: `bbr`,
`slow_start_after_idle=0`, `mtu_probing=1`.

**Wi-Fi was disabled at the radio this time** (`nmcli radio wifi off`), not just
downed, after NetworkManager restored the link mid-pass on the previous run.
`ip route show default` named only the tether for the whole pass and `wlo1`
stayed `DOWN`. RX on the tether grew **170.7 MB** against roughly 160 MB of
requested payload, accounting for every transfer.

## Observations

Single-stream ran **115.4 / 125.7 / 129.6 Mbps**, a 1.12x spread around a
123.6 Mbps mean. Parallel-4 aggregated **282.5 Mbps**. RTT averaged 36.5 ms
with `mdev` 8.16.

**Doubling the bus made things worse, not better.** Against the pass an hour
earlier on the 5000 Mbps port, with every other variable held:

| | usb4, 5000 | usb2 TB4, 10000 |
|---|---|---|
| single mean | 123.9 Mbps | 123.6 Mbps |
| single spread | 1.19x | 1.12x |
| parallel-4 | **365.2 Mbps** | **282.5 Mbps** |
| RTT avg | 36.7 ms | 36.5 ms |
| RTT `mdev` | 5.60 ms | 8.16 ms |

Single-stream is identical to three significant figures and the aggregate fell
**23%**. **This is the strongest statement the log has yet made that bus speed
above 480 is irrelevant here**: the bus doubled, and at 282 Mbps this pass used
**2.8% of it**. The aggregate difference is not attributable to the port - see
below - but the point stands either way, because a link using 3% of its bus
cannot be relieved by doubling it. That is now the fourth pass to say so.

**The BBR-vs-CUBIC comparison on this port is not clean.** Against the
2026-09-06 Thunderbolt record - same port, same bus, CUBIC - the aggregate ran
361.3 there against 282.5 here and the single mean 139.5 against 123.6. Taken
at face value that says CUBIC wins, which would agree with the razr's
clean-radio finding. **It should not be taken at face value**, because the link
was measurably deteriorating during this pass, and the previous BBR pass an
hour ago reached 365.2 - within 2% of the CUBIC Thunderbolt figure - under the
same congestion control. Congestion control is not what moved these numbers.

**The transfer-size effect did not reproduce here, and the reason is the link,
not the effect.** The 1.12x spread with a 2.29x aggregate ratio is the README's
fifth shape again, so the mandated interleaved check was run - 8 and 32 MB
alternating, the whole run spanning 5.07 s:

| transfer | result |
|---|---|
| 8 MB | 118.5 Mbps |
| 32 MB | 148.9 Mbps |
| 8 MB | 132.2 Mbps |
| 32 MB | **113.8 Mbps** |

8 MB mean 125.4, 32 MB mean 131.4 - a **1.05x ratio with the sets fully
overlapping**, where the same test an hour earlier gave 2.14x with no overlap
at all. But the two 32 MB transfers, two seconds apart and identical, differ
from each other by **1.31x**, and the second one is slower than both 8 MB runs.
**An experiment whose control condition disagrees with itself by 31% cannot
measure a 2x effect.**

A follow-up probe confirms what was wrong. Three more 8 MB singles taken
immediately after the interleaved run gave **77.2 / 110.3 / 118.1 Mbps** - a
1.53x spread, and every one of them below the three that opened the pass. The
link was slower at the end of the pass than at the start, and increasingly
erratic:

| point in pass | 8 MB result |
|---|---|
| opening singles | 115.4 / 125.7 / 129.6 |
| interleaved, mid | 118.5 / 132.2 |
| closing probe | **77.2 / 110.3 / 118.1** |

This is precisely the failure the README warns about - *"an uncontrolled 20 MB
sample earlier the same evening returned 73 Mbps against a fitted prediction of
287, because this link can collapse by 4.8x on its own."* **So this pass is not
evidence against the transfer-size effect. It is an uncontrolled measurement**,
and the three prior confirmations - two CUBIC, one BBR - stand unaffected.

**The decay is itself the finding.** The log's open "Pixel 9a decay hypothesis"
item describes a link fast at the start of a pass and slow from partway
through, staying slow, with the parallel test penalised simply for being last.
That shape is visible here on a *different phone and a different verdict class*:
a 23% lower aggregate than an hour ago, closing singles well below opening
singles, and `mdev` up from 5.60 to 8.16 while the average RTT did not move.
It also means **the 282.5 Mbps aggregate is probably an underestimate of what
this port can do**, since it was measured last.

## Issues

**The link degraded across the pass**, as detailed above. The frontmatter
measurements are a correct, methodology-compliant pass and are left exactly as
taken, but the parallel figure in particular should not be compared with the
earlier passes as though conditions were equal. Errors and drops were zero
throughout, so this is not cable, power or host - it is upstream.

`carrier.network` is blank for the usual structural reason on iOS.
`carrier.name` is carried forward on the matching `2600:381::/32` delegation
and was **not** operator-confirmed this session. `usb.cable` is blank - the
operator made the port move and was not asked which cable went with it, and
whether the Thunderbolt cable from 2026-09-06 was reused is unknown.

## Follow-ups

- **Re-run this port when the link is stable.** The port comparison above is
  contaminated and the Thunderbolt aggregate is very likely understated. A
  repeat that opens with the parallel test would settle both at once.
- **Run the parallel test first, once** - already open in `INDEX.md`, and this
  pass is the clearest argument yet for it. Every aggregate in this log is
  measured last, so decay and genuine multi-flow behaviour remain
  indistinguishable in all of them.
- Confirm the cable and the carrier with the operator and backfill both fields.
- Bus speed above 480 still has no measured consequence anywhere in this log,
  now including the only two 10000 Mbps records in it.
