# Tether report - 2026-09-05T17:56:58-04:00

## Connection

| | |
|---|---|
| Interface | `enxce1d58e89c0f` |
| Driver | `cdc_ncm` |
| Operstate | `up` |
| IPv4 | `10.244.144.215/24` |
| Gateway | `10.244.144.214` |
| IPv6 | no |
| MTU / max | 1500 / 1500 |
| Negotiated link | 425 Mbps |
| Holds default route | yes |

## Device

| | |
|---|---|
| Make | Google |
| Model | Pixel 9a |
| OS | 17 |
| Radio | `IWLAN,NR_SA` -> **IWLAN** |
| Operator | radio `Google Fi`, SIM `Google Fi` (agree) |

Read over `adb`. Radio type is only trustworthy if read before *and* after the transfers with both readings agreeing - a mid-session switch poisons any carrier comparison drawn from it.

## USB

| | |
|---|---|
| Device | `3-2` 18d1:4eec - Pixel 9a |
| bcdUSB | `2.10` |
| Bus speed | **480 Mbps** (USB 2.0) |
| BOS capability | SuperSpeed |
| Type-C connector | `port1` |

### Host Type-C topology

The kernel binds each connector to both its USB 2.0 and SuperSpeed ports at boot. A connector with no SuperSpeed half cannot exceed 480 Mbps whatever the cable.

| Connector | Halves | SuperSpeed wired | Attached |
|---|---|---|---|
| `port0` | `usb3-port1` 480M, `usb4-port1` 10000M | yes | partner present |
| `port1` | `usb2-port1` 20000M, `usb3-port2` 480M | yes | partner present **<- this device** |

### NCM aggregation (cdc_ncm)

- `rx_max` = 16384
- `tx_max` = 16384
- `tx_timer_usecs` = 400
- `ndp_to_end` = None

## TCP

| | |
|---|---|
| Congestion control | **`bbr`** (available: reno, cubic, bbr) |
| slow_start_after_idle | 0 |
| mtu_probing | 1 |
| tcp_rmem (min/default/**max**) | 4096 / 131072 / **6,291,456** |
| tcp_wmem (min/default/max) | 4,096 / 16,384 / 4,194,304 |
| net.core.rmem_max | 212,992 (caps explicit SO_RCVBUF only) |
| qdisc | `fq_codel` |

## Counters

| | bytes | packets | errors | dropped |
|---|---|---|---|---|
| RX | 27,559,605 | 30,779 | 0 | 0 |
| TX | 8,711,824 | 19,633 | 0 | 0 |

Cumulative since the interface appeared, not since this report. Re-plug for a clean per-pass reading.

## Findings and recommendations

### BLOCKER: Another route-capable link is up

`wlo1` is up alongside the tether. If the tether drops mid-run, curl still succeeds and the result looks like a tethering measurement. Take these down first.

### Problem: Device can do better than 480 Mbps

The device advertises SuperSpeed in its BOS descriptor but enumerated at 480 Mbps. Connector `port1` has an enumerated SuperSpeed half, so the host is declared capable and **the cable is the leading suspect** - an unmarked C-to-C cable is very often USB 2.0. Try a cable explicitly rated 5 or 10 Gbps. If a known-good USB 3 storage device also fails to train SuperSpeed here, the fault is physical, behind the connector.

### Note: No jumbo frames available

`mtu_max` is 1500, so there is no MTU headroom to find here. Raising MTU is not an option on this tether.

### Note: NCM aggregation buffers

`rx_max=16384`, `tx_max=16384`. Compare these against the device-advertised `dwNtbInMaxSize`/`dwNtbOutMaxSize`: **if they already match, the common "raise these to 32768" advice is a no-op** and changing them will do nothing.

### Note: No measurements taken

Run again with `--measure` for the throughput and latency half of the rubric. That costs roughly 56 MB of metered cellular data.

---

Rubric and field definitions come from `README.md`, which is authoritative. If an observation fits none of the cases above, say so in the record rather than forcing it into the nearest one.
