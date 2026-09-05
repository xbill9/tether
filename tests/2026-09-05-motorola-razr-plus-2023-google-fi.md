---
id: 2026-09-05-motorola-razr-plus-2023-google-fi
date: 2026-09-05
phone:
  make: Motorola
  model: razr plus 2023
  os: "15"            # ro.build.version.release over adb
carrier:
  name: Google Fi     # gsm.operator.alpha and gsm.sim.operator.alpha both "Google Fi"; not operator-confirmed
  network: NR_SA      # 5G standalone - read before and after the pass, both agree
usb:
  vendor_id: "22b8"
  product_id: "2e25"  # RNDIS+ADB composite - adb was enabled for the whole pass
  driver: rndis_host
  bus_speed_mbps: 480
  negotiated_link_mbps:   # rndis_host does not report one - /sys/class/net/<if>/speed returns -1
  cable:              # moot - no SuperSpeed in the BOS descriptor, see body
link:
  interface: enx16a0353b8b25
  ipv4: 172.23.152.214/24
  gateway: 172.23.152.59
  ipv6: true
  mtu: 1500
  mtu_max: 1500
tcp:
  congestion_control: bbr
  slow_start_after_idle: 0
  mtu_probing: 1
results:
  single_stream_mbps: [71, 84, 89]
  parallel_4_aggregate_mbps: 221
  rtt_ms:
    min: 26.1
    avg: 38.3
    max: 53.4
    mdev: 8.8
  errors: 0
  drops: 0
verdict: good
---

# Motorola razr plus 2023 on Google Fi

First record for this handset - not the same device as the
[razr 2024](2026-09-05-motorola-razr-2024-google-fi.md), though it lands in much
the same place. Third `rndis_host` phone in the log and the first to have
`carrier.network` confirmed on both sides of the transfers.

## Setup

Enumerated as `22b8:2e25`, motorola's RNDIS+ADB composite configuration, so USB
debugging was already on when it was attached and **stayed on for the whole
pass**. The descriptors below were therefore read in the same USB configuration
that carried the traffic, which is the state that matters - the razr 2024 record
notes that motorola presents a different product ID (`2e24`) when tethering
without adb.

Two things about `rndis_host`, both of which look like failed readings and are
not: `/sys/class/net/<if>/speed` returns `-1`, so `negotiated_link_mbps` is
blank, and the interface sits at operstate `UNKNOWN` rather than `UP`. Flags
showed `UP,LOWER_UP` throughout.

**Accepting the adb RSA prompt bounced the tether**, exactly as the Galaxy S24
did. The interface was recreated with a new MAC and a new DHCP lease:

    before   enx224f40f08d10   22:4f:40:f0:8d:10   172.23.152.62
    after    enx16a0353b8b25   16:a0:35:3b:8b:25   172.23.152.214

**`enx16a0353b8b25` is the interface that carried every measurement below.** The
device also read on port `3-2` before authorisation and `3-1` after; the host
cannot say whether that was a physical move or re-enumeration, and it does not
affect anything here - both connectors are 480-capable and this device has no
SuperSpeed to negotiate either way.

WiFi (`wlo1`) was `DOWN` and the tether was the sole default route throughout.
The IPv6 delegation is in 2607:fb90::/32, T-Mobile space, which is what Google
Fi rides.

Radio type was read before the transfers and again immediately after, and both
returned `NR_SA,Unknown` - dual-SIM, slot 1 on 5G standalone and slot 2 idle. It
is recorded because the two readings agree. Both operator properties returned
`Google Fi` and agreed with each other, unlike the Galaxy S24, which returned the
retired `Project Fi` from `gsm.operator.alpha`. Carrier is adb-derived and
corroborated by the delegation, but was not confirmed with the operator.

## Observations

### This handset cannot help the SuperSpeed question

    bcdUSB               2.01
    (no BOS block - no SuperSpeed or SuperSpeedPlus capability)

`bcdUSB 2.01` and no device capability descriptor. **480 is this device's own
ceiling**, so `usb.cable` is moot here rather than merely unverified, and no
cable will ever move it. That puts it with the razr 2024 and the iPhone 16e, and
against the iPhone 17 Pro, which advertises 10 Gb/s and still enumerates at 480 -
see [that investigation](2026-09-05-iphone-17-pro-att-cable3.md), which this
record does not advance.

### Per-flow limit, not a slow carrier

Single-stream ran 71 / 84 / 89 Mbps - a **1.25x spread**, rising steadily.
Aggregate was **221 Mbps, or 2.47x the best single**, with RTT averaging 38.3 ms
at 8.8 ms `mdev`.

That is the README's fifth case: **near-flat single-stream spread with aggregate
far above it, pointing at a per-flow limit** rather than at the carrier or the
tether. It is the same shape as the AT&T Pixel 9a, the only previous instance,
which ran 1.06x spread with aggregate 2.6x its best single. The WAN plainly has
headroom - four flows found more than twice what one could - so nothing here is
worth tuning on the carrier side.

The bandwidth-delay product is consistent with that reading: 89 Mbps at 38.3 ms
is about 428 KB in flight, which one flow will only sustain with a large window.
Whether the limit is carrier shaping per flow or a window ceiling, this record
cannot separate - the same ambiguity the README names for this case.

At 221 Mbps the aggregate sits at roughly 74% of the realistic bulk ceiling of a
480 Mbps bus, just below the 228-273 band every other BBR-era record occupies, so
the USB 2.0 bus is close to relevant but not yet binding.

RTT is unremarkable and healthy - 8.8 ms `mdev` on a 38.3 ms average, no sign of
bufferbloat. The four parallel streams shared at 1.38x max:min
(61 / 59 / 57 / 44 Mbps); the 44 is the outlier and the other three are within
4 Mbps of each other.

Zero errors and zero drops across roughly 43k RX / 22k TX packets.

### Against the razr 2024

Same carrier, same driver, same congestion control, one year apart:

| | razr 2024 | razr plus 2023 |
|---|---|---|
| Single (Mbps) | 104 / 117 / 140 | 71 / 84 / 89 |
| Spread | 1.35x | 1.25x |
| Par-4 | 234 | 221 |
| RTT avg | 37.6 ms | 38.3 ms |
| RTT mdev | 2.1 ms | 8.8 ms |

Aggregate and average RTT are close enough to be the same result. Single-stream
is visibly lower on the plus, which is what makes its aggregate ratio 2.47x
against the 2024's 1.67x - the per-flow ceiling is lower here while total
capacity is not. **The 2024's `carrier.network` is blank**, so this is not a
radio-controlled comparison and should not be read as one.

## Issues

The adb authorisation bounce cost one interface identity mid-session. It was
caught before the transfers started, which is the only reason the record names
the right interface - the skill's instruction to authorise adb *before* a pass
rather than during it earned its place again here.

## Follow-ups

- The per-flow limit is now seen twice, on two carriers (AT&T Pixel 9a, Google Fi
  razr plus). Worth testing directly: a single stream with an enlarged socket
  buffer would separate "carrier shapes per flow" from "one flow cannot fill the
  BDP". That is a host-side change and costs one 8 MB transfer, not a full pass.
- `carrier.network` is blank on the razr 2024 record, so the comparison above is
  not radio-controlled. Both razrs are on hand; re-running the 2024 with
  `gsm.network.type` captured would fix that.
