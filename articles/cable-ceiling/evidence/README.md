# Tethering test log

Markdown-as-database for USB tethering results across phones, carriers and
connection modes. One file per test in `tests/`, named
`YYYY-MM-DD-<phone-slug>[-<carrier-slug>].md`.

Each file is YAML frontmatter (the data) plus a prose body (the story). The
frontmatter is greppable and parseable; the body is where the useful detail
actually lives.

## Layout

    README.md      this file - format spec and field reference
    TEMPLATE.md    copy for each new test
    INDEX.md       one row per test, updated by hand
    tests/         the records

## Methodology - read before adding a record

Results are only comparable if collected the same way. Three rules, all learned
the hard way on 2026-09-05:

1. **Record three single-stream runs, never one.** A single measurement is
   meaningless here. The Pixel 9a produced 15, 44 and 116 Mbps on three
   consecutive identical transfers. The *spread* is the finding, not the peak.

2. **Always run the parallel test too.** Single-stream vs 4-stream aggregate is
   the one measurement that separates "the carrier is slow" from "congestion
   control is collapsing". If aggregate >> single, the WAN has headroom and the
   problem is on this machine. That distinction drove every fix worth making.

3. **Record `tcp.congestion_control`.** It is the largest single lever here, but
   *what* it changes depends on the radio, and a record without it is
   uninterpretable. Two measured cases, both on 2026-09-05:

   - **On a lossy radio, it changes throughput by 7x.** The Pixel 9a under CUBIC
     ran 15 / 44 / 116 Mbps, a 7.7x spread; under BBR, 125 / 153 / 106, a 1.4x
     spread. CUBIC was reading random radio loss as congestion and halving the
     window.
   - **On a clean radio, it barely changes throughput and transforms latency.**
     The razr 2024 under CUBIC ran *faster* than under BBR - mean 140 against
     120 Mbps, identical 1.34x spread - while RTT `mdev` went from 2.1 ms to
     16.5 ms. Average RTT was unchanged at 37.6 vs 37.7 ms.

   So **"BBR is faster" is not the finding. BBR is more robust to radio loss.**
   Where there is no loss to misread, CUBIC wins on throughput and pays for it
   in queue depth. Which of the two matters is a decision about the workload,
   not a fact about the tether.

   If you re-test after changing it, keep both records rather than overwriting.

Use the same endpoint and transfer size every time, or the numbers do not
compare. The baseline used so far:

    single:   curl https://speed.cloudflare.com/__down?bytes=8000000   (x3, sequential)
    parallel: same URL, 4 concurrent, sum the four speeds
    rtt:      ping -c5 speed.cloudflare.com

Note this burns real cellular data - roughly 56 MB for a full pass. On a metered
plan that is worth knowing before you test six phones.

## Field reference

| Field | Meaning |
|---|---|
| `id` | Must match the filename stem. |
| `date` | ISO date of the test. |
| `phone.*` | Make, model, OS version. OS version matters: iOS 17+ can switch an iPhone from `ipheth` to `cdc_ncm`. |
| `carrier.name` | Carrier the SIM is on. |
| `carrier.network` | Radio actually in use at test time (5G / LTE / etc), not what the plan advertises. |
| `usb.vendor_id` / `product_id` | From `lsusb`. Identifies the tether function, which can differ from the phone's normal USB identity. |
| `usb.driver` | `cdc_ncm`, `rndis_host`, or `ipheth`. Read via `basename $(readlink -f /sys/class/net/<if>/device/driver)`. |
| `usb.bus_speed_mbps` | From `/sys/bus/usb/devices/<dev>/speed`. 480 = USB 2.0, 5000 = USB 3.0. **Check this first** - a charge-only cable silently caps you at 480. |
| `usb.negotiated_link_mbps` | From `/sys/class/net/<if>/speed`. |
| `link.*` | Interface name, addressing, MTU. `mtu_max` from `ip -d link` - if it equals 1500 there are no jumbo frames to be had. |
| `ntb.*` | NCM aggregation buffers. `rx_max`/`tx_max` vs the device-advertised `dwNtbInMaxSize`/`dwNtbOutMaxSize`. If they are already equal, the common "raise these to 32768" advice is a no-op. Omit for RNDIS/ipheth. |
| `tcp.congestion_control` | See rule 3 above. |
| `results.single_stream_mbps` | List of three. |
| `results.parallel_4_aggregate_mbps` | Sum of four concurrent streams. |
| `results.rtt_ms` | min/avg/max/mdev. Rising `mdev` under load means bufferbloat. |
| `results.errors` / `drops` | From `ip -s link`. Non-zero points at cable or power, not config. |
| `verdict` | `good` / `usable` / `poor` / `failed`. |

## Reading the results

The diagnostic that matters is the relationship between four numbers: the
single-stream spread, the parallel aggregate, the RTT average, and the RTT
`mdev`. **Read `mdev`, not just the average** - the two can move independently,
and the case below where they do is the one most easily missed.

- **single spread wide, RTT flat** - congestion control collapsing on radio
  loss. Fixable on this machine (BBR).
- **single ~= parallel aggregate** - genuinely WAN-limited. Nothing to tune.
- **aggregate near 300 Mbps on a 480 Mbps bus** - you are hitting the USB 2.0
  ceiling. Cable or host port, not software. Check whether the phone's BOS
  descriptor advertises SuperSpeed before chasing it: if it does not, 480 is the
  device's own ceiling and no cable will help.
- **RTT `mdev` high while the average is unchanged** - bufferbloat. The queue is
  being filled to find the limit, which is normal CUBIC behaviour on a link that
  is not dropping packets. Costs nothing for bulk transfer and a great deal for
  anything interactive.
- **single spread near flat, but aggregate far above single** - neither of the
  first two cases. A flow that reproducibly stops at the same figure while four
  together go much faster looks like a per-flow limit - carrier shaping, or one
  flow unable to fill the bandwidth-delay product. Seen on the AT&T Pixel 9a at
  1.06x spread with aggregate 2.6x the best single, the Google Fi razr plus 2023
  at 1.25x / 2.47x, and the AT&T iPhone 17 Pro at 1.26x / 2.59x.

  **Do not read this case on a fast link without checking whether one long
  transfer beats the short one.** Measured 2026-09-06 on the iPhone 17 Pro
  ([Thunderbolt](tests/2026-09-06-iphone-17-pro-att-thunderbolt.md),
  [USB-C port](tests/2026-09-06-iphone-17-pro-att-usbc-port.md)): the standard
  8 MB transfer produced 120-177 Mbps single-stream against 4-stream aggregates
  of 361 and 371 Mbps - textbook per-flow limit - while single 32 MB transfers
  on the same connections ran 327-366 Mbps, matching the aggregate. One flow
  repeatedly reached what four flows reached, so **a per-flow cap near 150 Mbps
  is inconsistent with the evidence.**

  **The cause is the transfer size, established by an interleaved test.** Six
  transfers alternating 8 and 32 MB, the whole run spanning 3.89 seconds so
  that link variation could not fall differently on the two sizes: 8 MB mean
  158.75 Mbps, 32 MB mean 361.96 Mbps, a 2.28x ratio, every 32 MB run beating
  the 8 MB run beside it, and **no overlap at all** between the two sets (best
  8 MB 176.9, worst 32 MB 354.6). Interleaving matters: an uncontrolled 20 MB
  sample earlier the same evening returned 73 Mbps against a fitted prediction
  of 287, because this link can collapse by 4.8x on its own.

  **Why short transfers pay so much is still open.** Fitting a fixed cost to
  the interleaved durations (8 MB in 0.406 s, 32 MB in 0.707 s - four times the
  bytes in 1.74x the time) gives an asymptote of 637 Mbps and a startup cost of
  0.305 s, about **10 RTTs** at this link's 29.6 ms, where slow-start to the
  ~503 KB BDP should need roughly 6. Something beyond textbook slow-start is in
  there. Related observations, neither of them an explanation: the server's
  window grew 53 -> 702 packets across one transfer with zero loss and zero
  retransmission, and Cloudflare reports `cwnd=53` at the start of every fresh
  connection rather than the Linux default of 10. Both come from the
  `server-timing: cfL4` response header - `ss` on this host shows only our own
  send window, which for a download carries just ACKs and stays at 10.

  Practical rule: **a flat-spread, high-aggregate reading on a fast link is not
  a per-flow limit.** Run one long single transfer before writing anything
  down, and interleave sizes if the answer matters. The 8 MB size stays fixed
  for records regardless, because changing it breaks comparability with
  everything already collected.

  All three earlier sightings of this shape - AT&T Pixel 9a 1.06x/2.6x, Google
  Fi razr plus 2023 1.25x/2.47x, AT&T iPhone 17 Pro 1.26x/2.59x - were on links
  fast enough for this to apply, so **none of them is established as a per-flow
  limit.**

If an observation fits none of these, say so in the record rather than forcing
it into the nearest one.
