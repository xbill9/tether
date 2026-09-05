# Codex project guidance

## Project and sources of truth

This repository records USB tethering measurements across phones, carriers,
cables, and host configurations. It is a Markdown database: `tests/` contains
measurement records, not automated tests. There is no application, build system,
package installation step, or test framework.

- Read `README.md` for the authoritative format, methodology, and field reference.
- Start new records from `TEMPLATE.md`.
- Maintain `INDEX.md` by hand, with one linked row per record, newest first.
- Consult `.claude/skills/new-test/SKILL.md` for detailed collection commands and
  device-specific experience when running a tether test. Its Claude-specific
  invocation syntax is not needed in Codex.
- `.claude/validate-record.sh` is an existing validation helper. Run it manually
  as described below; do not rely on the Claude hook configuration in Codex.

## Record integrity

- Name records `tests/YYYY-MM-DD-<phone-slug>[-<carrier-slug>].md`. Add a
  descriptive suffix for distinct sessions, such as `-cubic` or `-cable2`.
  The YAML `id` must exactly match the filename stem.
- Retests get new files. Preserve earlier measurements and link to the earlier
  record, explaining what changed.
- Backfill known metadata, correct transcription errors, and add context only
  with an explanation in the body of what changed and when. Never replace a
  historical measurement with a later result.
- Never invent measurements or copy values from another session. Leave unknown
  fields blank with `# TODO <reason>`; explain incomplete runs in the body.
  Template defaults, including zero errors and drops, are not observations.
- Omit the `ntb` block for `rndis_host` and `ipheth`; it applies only to NCM.
- Use the body sections Setup, Observations, Issues, and Follow-ups. Separate
  measured facts, operator-supplied information, and diagnostic hypotheses.
- Use `good`, `usable`, `poor`, or `failed` for `verdict`.
- Add or update the matching index row in the same change. Preserve its column
  order, show all three single-stream results, and use `—` for missing results.
  Mark a To test item complete only when the measurement actually covers it.

## Never record device identifiers

This is a **public GitHub repo**. Two Samsung serials reached it once and
purging them cost a full history rewrite and a force-push.

- **Never write a device serial into a record.** `adb devices -l` prints it and
  `ro.serialno` returns it. Use it in the session to tell two handsets apart if
  you must, but the record says "a second, physically distinct unit" - never the
  value.
- Same for IMEI and any full global IPv6 address. Carrier prefixes
  (`2607:fb90::`), private IPv4 and the `enx<mac>` interface name are fine - the
  RNDIS MAC is regenerated per session.
- If two units must be told apart in prose, say so qualitatively and move on.

## Running measurements

When the user requests a tether test, proceed with the standard measurement
pass without asking for redundant confirmation. A pass transfers roughly 56 MB
of cellular data. Documentation-only work does not require live measurements.

1. Identify the actual tether interface and verify the traffic route. Resolve
   ambiguous device/interface selection before measuring. Avoid silently
   measuring Wi-Fi or another fallback connection.
2. Collect device metadata before transfers. USB debugging authorization can
   recreate the interface or change the USB product ID; recheck the interface,
   route, and descriptors afterward. Do not change the configuration mid-pass.
3. Check USB bus speed first. Record 480 Mbps as USB 2.0; it alone does not
   establish a cable fault or invalidate a test. Use available device capability
   evidence to distinguish a device limit from a cable or port limitation;
   unreadable descriptors are not proof that SuperSpeed is unsupported.
4. Record the active TCP congestion control and other template settings. Read
   `/proc/sys/net/ipv4/` directly if `sysctl` is unavailable on PATH.
5. Use exactly `https://speed.cloudflare.com/__down?bytes=8000000`: three
   sequential single-stream transfers, then four concurrent transfers whose
   speeds are summed. Convert curl's bytes/second to Mbps with `value * 8 / 1e6`.
   Check transfer success before treating reported speeds as valid measurements.
6. Run `ping -c5 speed.cloudflare.com` and record min/avg/max/mdev. State whether
   latency was measured under load or idle. Read interface errors and drops
   after transfers and identify whether they are cumulative counters or deltas.
7. For Android, check the active SIM's radio type before and after the pass;
   if readings disagree, leave the network field unknown and explain. Do not
   infer installed OS versions from product specifications or radio type solely
   from a status-bar label. Label operator-supplied metadata.

Use the README diagnostic rubric while keeping conclusions proportional to the
evidence. Compare single-stream spread, parallel aggregate, RTT average, and
RTT mdev. Describe unexplained behavior explicitly rather than forcing a cause.

## Validation and completion

For each added or edited record, run from the repository root:

```bash
bash .claude/validate-record.sh ./tests/<record-name>.md
```

The `./tests/` prefix matters: the script's path filter skips bare `tests/...`
paths. The helper uses `jq` to report problems as JSON and can exit successfully
even when it reports validation problems, so inspect its output. It checks only
some invariants; also review YAML structure, missing-field explanations, index
links and values, units, and measurement completeness manually.

For documentation-only edits, review the changed text and whitespace; do not
install a test framework or run a cellular benchmark. Preserve unrelated working
tree changes. Finish with a concise description of what changed, what was
checked, and any remaining unknowns.
