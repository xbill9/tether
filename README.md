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

3. **Record `tcp.congestion_control`.** It changes results by 7x. A record
   without it is uninterpretable. If you re-test after changing it, keep both
   records rather than overwriting.

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

The diagnostic that matters is the relationship between three numbers:

- **single spread wide, RTT flat** - congestion control collapsing on radio
  loss. Fixable on this machine (BBR).
- **single ~= parallel aggregate** - genuinely WAN-limited. Nothing to tune.
- **aggregate near 300 Mbps on a 480 Mbps bus** - you are hitting the USB 2.0
  ceiling. Cable problem, not software.
