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
     ran 15 / 44 / 116 Mbps, a 7.8x spread; under BBR, 125 / 153 / 106, a 1.4x
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
  together go much faster points at a per-flow limit - carrier shaping, or one
  flow unable to fill the bandwidth-delay product. Seen once, on the AT&T Pixel
  9a at 1.06x spread with aggregate 2.6x the best single.

If an observation fits none of these, say so in the record rather than forcing
it into the nearest one.
