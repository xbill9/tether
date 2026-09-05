#!/usr/bin/env bash
# Validate a tethering test record's frontmatter against the invariants in
# README.md. Called by the PostToolUse hook; also runnable by hand:
#   .claude/validate-record.sh tests/2026-09-05-pixel-9a-bbr.md
set -u

f="${1:-}"
[ -n "$f" ] || exit 0
[ -f "$f" ] || exit 0

case "$f" in
  */tests/*.md) ;;
  *) exit 0 ;;
esac

stem="$(basename "$f" .md)"

# Pull the YAML frontmatter (between the first two --- lines) and strip comments.
fm="$(awk 'NR==1 && $0=="---"{inb=1;next} inb && $0=="---"{exit} inb{print}' "$f" \
      | sed 's/[[:space:]]*#.*$//')"

val() { printf '%s\n' "$fm" | sed -n "s/^[[:space:]]*$1:[[:space:]]*\(.*\)[[:space:]]*$/\1/p" | head -1; }

problems=()

id="$(val id)"
if [ -z "$id" ]; then
  problems+=("frontmatter has no 'id'")
elif [ "$id" != "$stem" ]; then
  problems+=("id '$id' does not match filename stem '$stem'")
fi

single="$(val single_stream_mbps)"
inner="$(printf '%s' "$single" | tr -d '[] ')"
if [ -z "$inner" ]; then
  problems+=("results.single_stream_mbps is empty - README rule 1 requires three runs")
else
  n=$(printf '%s' "$inner" | awk -F, '{print NF}')
  [ "$n" -eq 3 ] || problems+=("results.single_stream_mbps has $n value(s), expected 3 (README rule 1)")
fi

cc="$(val congestion_control)"
[ -n "$cc" ] || problems+=("tcp.congestion_control is empty - a record without it is uninterpretable (README rule 3)")

verdict="$(val verdict)"
case "$verdict" in
  good|usable|poor|failed) ;;
  "") problems+=("verdict is empty - must be good|usable|poor|failed") ;;
  *)  problems+=("verdict '$verdict' is not one of good|usable|poor|failed") ;;
esac

# INDEX.md must carry a row linking to this record.
idx="$(dirname "$(dirname "$f")")/INDEX.md"
if [ -f "$idx" ] && ! grep -q "$stem" "$idx"; then
  problems+=("INDEX.md has no row for $stem - add it in the same change")
fi

[ ${#problems[@]} -eq 0 ] && exit 0

msg="Record check failed for $f:"
for p in "${problems[@]}"; do msg="$msg"$'\n'"  - $p"; done

jq -nc --arg m "$msg" '{
  systemMessage: $m,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $m
  }
}'
