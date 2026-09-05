# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A markdown-as-database of USB tethering performance tests. There is no source
code, build system, formatter, linter or test runner — nothing here is
executable and there is nothing to compile or run.

`tests/` holds test *records* (one markdown file per measurement session), not
test code. Do not go looking for a test framework.

The format spec, full field reference and diagnostic rubric are in the README
and are authoritative:

@README.md

## Adding a record

- Copy `TEMPLATE.md`. Name it `tests/YYYY-MM-DD-<phone-slug>[-<carrier-slug>].md`;
  the frontmatter `id` must equal the filename stem.
- **Add the matching `INDEX.md` row in the same change** (newest first). Nothing
  generates that table, so it drifts silently if skipped.
- A re-test after a config change gets a **new file**, never a rewrite of an
  existing one (README methodology rule 3).
- Editing an existing record is otherwise fine: backfill a `# TODO` field once
  the answer is known, correct a wrong value, add a cross-link. The one thing
  that must not change is a **recorded measurement** — if the numbers would
  move, that is a new record, not an edit. Say in the body what was backfilled
  and when, so a filled-in field is never mistaken for one measured at test
  time.
- Leave unknown fields blank with an inline `# TODO <reason>` comment rather
  than guessing or dropping the key.
- Never carry a number over from another record. If a run was not performed,
  leave it blank and say so in the body.

## Measuring

Run the measurement commands directly — no need to ask first. Use the exact
endpoint and transfer size given in the README; changing either makes the
result incomparable with every existing record. A full pass is three sequential
single-stream transfers, the 4-concurrent parallel test and `ping -c5`, and
costs roughly 56 MB of metered cellular data.

Check `usb.bus_speed_mbps` first: a charge-only cable silently caps the bus at
480 Mbps and invalidates the run.
