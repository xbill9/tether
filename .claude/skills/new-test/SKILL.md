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
for f in tcp_congestion_control tcp_slow_start_after_idle tcp_mtu_probing; do
  echo "$f=$(cat /proc/sys/net/ipv4/$f)"
done
```

`sysctl` is **not on PATH** on this host — read `/proc/sys` directly as above.

Two things are specific to `rndis_host`, and both look like failed readings when
they are not:

- `/sys/class/net/$IF/speed` reads **`-1`**. RNDIS does not report a link speed.
  Leave `negotiated_link_mbps` blank with that as the stated reason.
- The interface sits at operstate `UNKNOWN` rather than `UP`. Normal; check for
  `UP,LOWER_UP` in the flags instead.

**Check the bus speed before spending any data** — a charge-only cable caps the
bus at 480 Mbps and makes the whole pass misleading:

```bash
for d in /sys/bus/usb/devices/*/; do
  [ -e "$d/idVendor" ] && echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) speed=$(cat $d/speed) $(cat $d/product 2>/dev/null)"
done
```

**If it enumerated at 480, find out whether the phone could have done better.**
This is the check that separates "chase the cable" from "this is the device's
ceiling", and without it a 480 reading is uninterpretable:

```bash
sudo -n lsusb -v -d <vid>:<pid> 2>/dev/null | grep -iE 'bcdUSB|SuperSpeed USB Device|operate at SuperSpeed'
```

A BOS descriptor advertising SuperSpeed means the phone can do 5 Gbps and
something *else* — cable or host port — is holding it at 480, so `usb.cable` is
worth chasing. No BOS block means 480 is the device's own ceiling and no cable
will ever move it, which makes `usb.cable` moot rather than merely unverified.
Record which, in the body. Needs root: without it `lsusb` truncates the
descriptors and you will simply see nothing.

If the driver is `cdc_ncm`, also collect the NTB block (omit it entirely for
`rndis_host` / `ipheth`):

```bash
for f in rx_max tx_max tx_timer_usecs; do echo "$f=$(cat /sys/class/net/$IF/cdc_ncm/$f)"; done
```

Record `errors` and `drops` from `ip -s link show "$IF"` — read them *after*
the transfers, so they cover the test.

## 2b. Device metadata over adb

`phone.os`, `carrier.network` and — on Samsung — the real model are **not**
readable over a tether-only USB function. `adb` (installed 2026-09-05) gets all
three:

```bash
adb devices -l
adb shell getprop ro.product.manufacturer   # phone.make
adb shell getprop ro.product.model          # phone.model
adb shell getprop ro.build.version.release  # phone.os, e.g. "16"
adb shell getprop gsm.network.type          # carrier.network, e.g. "NR" (5G), "LTE"
adb shell getprop gsm.operator.alpha        # what the radio reports as the operator
```

- **Do this before step 3, never during.** Enabling USB debugging renegotiates
  the USB configuration on some phones and can bounce the tether interface
  mid-transfer, silently invalidating the run.
- **Read `gsm.network.type` again immediately after the transfers**, and record
  it only if both readings agree. The radio can switch mid-session, and a
  post-hoc reading cannot establish what was in use during the pass. If they
  disagree, leave `carrier.network` blank and say so - a wrong radio type
  silently poisons every carrier comparison drawn from the record.
- **Do not accept a status-bar reading as the radio type.** AT&T brands
  LTE-Advanced as "5G E", so a handset showing "5G" on that carrier may be on
  LTE. `gsm.network.type` distinguishes them: `NR_SA` / `NR_NSA` are real 5G,
  `LTE` is not.
- `unauthorized` in `adb devices` means the handset has not accepted the RSA
  prompt. Ask the operator to accept it before falling back — do not treat it
  as "adb unavailable".
- **Accepting that prompt can bounce the tether, and has.** On a Galaxy S24 the
  interface was recreated with a new MAC, so it got a new name and a new DHCP
  lease (`enx6e6e82944d55` → `enx763dd1c95175`) mid-session. Get the phone
  authorised *before* starting a pass, then **re-read the interface name** and
  confirm the default route still points at it. Record the interface that
  actually carried the traffic.
- **Confirm WiFi is down before trusting any number.** If the tether drops and
  another route takes over, `curl` still succeeds and the result looks like a
  tethering measurement. `ip route show default` must name the tether interface,
  and `ip -br link` should show no other route-capable link up.
- `gsm.operator.alpha` may report the MVNO brand or the underlying host network
  depending on the device — a Google Fi SIM on a Galaxy Z Flip6 reported
  `Google Fi`, while the same carrier's IPv6 delegation is indistinguishable
  from T-Mobile's. Treat it as strong corroboration, but confirm with the
  operator before writing `carrier.name`.
- Both `gsm.*` properties are **comma-separated per SIM slot** on dual-SIM
  phones: `Unknown,NR_SA` means slot 1 is idle and slot 2 is on 5G standalone.
  Read the populated slot, not the whole string.
- If adb is genuinely unavailable — not installed, debugging off, prompt
  declined — ask the operator to read the values off the phone, and leave the
  fields blank with `# TODO` if they are not supplied. **Never take an OS
  version from a spec site**: those give the OS the phone *shipped* with, not
  what is installed now.
- Mark operator-supplied values in the frontmatter comment, so they are never
  mistaken for host observations.
- **Enabling USB debugging can change the device's product ID.** The razr moved
  from `22b8:2e24` (tether only) to `22b8:2e25` (RNDIS+ADB composite) - a
  different USB configuration with its own descriptors. So read
  `usb.vendor_id` / `usb.product_id` and the BOS descriptor **in the same state
  the transfers will run in**, and say in the body which state that was.
  Descriptors collected with adb on do not necessarily describe the device that
  was measured with adb off.

USB product strings are vendor-dependent: Google and Motorola put the marketing
name in the descriptor, Samsung reports only `SAMSUNG_Android`. On Samsung the
model must come from adb or the operator.

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
- **Observations** — what the numbers *mean*. Apply the README's rubric, which
  now has five cases and is authoritative — read it rather than working from
  this summary. In outline: wide spread with flat RTT is congestion control
  collapsing on radio loss; single ≈ aggregate is WAN-limited; aggregate near
  300 Mbps on a 480 Mbps bus is the USB 2.0 ceiling (cable *or host port*);
  high `mdev` with an unchanged average is bufferbloat; near-flat spread with
  aggregate far above it is a per-flow limit. **Read `mdev`, not just the
  average** — the razr's CUBIC pass moved jitter eightfold while the average RTT
  did not budge. If the shape fits none of the five, **say so explicitly**
  rather than forcing it into the nearest one.
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
