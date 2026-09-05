---
id: YYYY-MM-DD-phone-slug
date: YYYY-MM-DD
phone:
  make:
  model:
  os:
carrier:
  name:
  network:          # 5G / LTE / etc - what the radio actually used
usb:
  vendor_id:
  product_id:
  driver:           # cdc_ncm | rndis_host | ipheth
  bus_speed_mbps:   # 480 = USB 2.0, 5000 = USB 3.0
  negotiated_link_mbps:
  cable:            # e.g. "USB-C to USB-C, phone supplied"
link:
  interface:
  ipv4:
  gateway:
  ipv6:             # true | false
  mtu:
  mtu_max:
ntb:                # NCM only - delete this block for rndis/ipheth
  rx_max:
  tx_max:
  device_max_in:
  device_max_out:
  tx_timer_usecs:
tcp:
  congestion_control:
  slow_start_after_idle:
  mtu_probing:
results:
  single_stream_mbps: []      # three runs
  parallel_4_aggregate_mbps:
  rtt_ms:
    min:
    avg:
    max:
    mdev:
  errors: 0
  drops: 0
verdict:            # good | usable | poor | failed
---

# <Phone> on <Carrier>

## Setup

How it was connected, what had to be done to bring it up, anything that did not
just work.

## Observations

What the numbers mean. Was the spread wide? Did parallel beat single? Where was
the bottleneck - radio, USB bus, or congestion control?

## Issues

Problems hit and how they were resolved. Leave empty if none.

## Follow-ups

Anything untested or worth retrying.
