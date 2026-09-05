---
name: new-test
description: Run a full USB tethering measurement pass and write the resulting record into tests/ plus its INDEX.md row. Use when adding a new tethering test result for a phone, re-testing after a congestion-control or cable change, or when asked to "run a tether test".
---

# Run a tethering test and record it

`$ARGUMENTS` is the phone (and optionally carrier), e.g. `pixel-9a` or
`iphone-15 verizon`. Ask for it if it is empty.

Read `@README.md` for the field reference and `@TEMPLATE.md` for the skeleton
before writing anything. Follow the record rules in `CLAUDE.md` — in
particular, a re-test after a config change is a **new file**, never an edit to
an existing one.

## 1. Identify the interface

```bash
ip -br link | grep -v -E '^(lo|wl|docker|virbr)' 
```

Pick the tether interface (typically `enx<mac>` or `usb0`). Call it `$IF` for
the rest of this run. If several candidates exist, or none appears, stop and
ask rather than guessing.

## 2. Collect the static facts

Gather every frontmatter field that is not a measurement:

```bash
IF=<interface>
basename "$(readlink -f /sys/class/net/$IF/device/driver)"   # usb.driver
cat /sys/class/net/$IF/speed                                  # negotiated_link_mbps
ip -d link show "$IF" | grep -o 'maxmtu [0-9]*'               # link.mtu_max
ip -br addr show "$IF"                                        # ipv4 / ipv6
ip route show dev "$IF" | grep default                        # link.gateway
lsusb                                                         # vendor_id / product_id
sysctl net.ipv4.tcp_congestion_control net.ipv4.tcp_slow_start_after_idle net.ipv4.tcp_mtu_probing
```

**Check the bus speed before spending any data** — a charge-only cable caps the
bus at 480 Mbps and makes the whole pass misleading:

```bash
for d in /sys/bus/usb/devices/*/; do
  [ -e "$d/idVendor" ] && echo "$d $(cat $d/idVendor):$(cat $d/idProduct) speed=$(cat $d/speed)"
done
```

If the driver is `cdc_ncm`, also collect the NTB block (omit it entirely for
`rndis_host` / `ipheth`):

```bash
for f in rx_max tx_max tx_timer_usecs; do echo "$f=$(cat /sys/class/net/$IF/cdc_ncm/$f)"; done
```

Record `errors` and `drops` from `ip -s link show "$IF"` — read them *after*
the transfers, so they cover the test.

## 3. Measure

The endpoint and transfer size are fixed by the README. Do not substitute
either — the numbers stop being comparable to every existing record.

Three sequential single-stream runs (`speed_download` is bytes/s; multiply by 8
and divide by 1e6 for Mbps):

```bash
for i in 1 2 3; do
  curl -s -o /dev/null -w '%{speed_download}\n' \
    'https://speed.cloudflare.com/__down?bytes=8000000'
done
```

Four concurrent streams, summed:

```bash
for i in 1 2 3 4; do
  curl -s -o /dev/null -w '%{speed_download}\n' \
    'https://speed.cloudflare.com/__down?bytes=8000000' &
done; wait
```

RTT:

```bash
ping -c5 speed.cloudflare.com
```

Run all three. A record without the parallel test cannot distinguish a slow
carrier from collapsing congestion control; a record without
`tcp.congestion_control` is uninterpretable.

## 4. Write the record

Create `tests/YYYY-MM-DD-<phone-slug>[-<carrier-slug>].md` from `TEMPLATE.md`,
with `id` equal to the filename stem. Leave anything you could not observe
blank with an inline `# TODO <reason>` comment — do not guess, and do not copy
a value from another record.

Fill the four body sections as analysis, not a transcript:

- **Setup** — how it connected and what had to be done to bring it up.
- **Observations** — what the numbers *mean*. Apply the README's rubric: wide
  single-stream spread with flat RTT is congestion control collapsing on radio
  loss; single ≈ parallel aggregate is genuinely WAN-limited; aggregate near
  300 Mbps on a 480 Mbps bus is the USB 2.0 ceiling, i.e. a cable problem.
- **Issues** — problems hit and how they were resolved. Leave empty if none.
- **Follow-ups** — anything untested or worth retrying.

Set `verdict` to one of `good` / `usable` / `poor` / `failed`.

If this supersedes an earlier record, link to it from the body and say what
differs, the way `tests/2026-09-05-pixel-9a-cubic.md` does — do not delete the
old one.

## 5. Update INDEX.md

Add the row to the top of the table (newest first), matching the existing
column order: Date, Phone (linked to the record), Carrier, Driver, Bus, CC,
Single (all three runs, `a / b / c`), Par-4, RTT avg, Verdict. Use `—` for any
measurement that was not run.

Tick off the matching entry in the "To test" list if this run covers it.
