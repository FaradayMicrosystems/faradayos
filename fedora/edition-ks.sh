#!/bin/bash
# Prints fedora/faradayos.ks for one FaradayOS edition (editions are listed in fedora/editions.list).
# Usage: fedora/edition-ks.sh <edition> [kickstart]   ->  kickstart on stdout
# In faradayos.ks:
#   #@if workplace              lines until "#@end" are kept only for the editions named
#   #@if performance workplace  (several names = any of them)
#   #@end
# Lines outside such blocks are in every edition. Blocks do not nest.
set -euo pipefail
ED=${1:?edition}
DIR=$(cd "$(dirname "$0")" && pwd)
KS=${2:-$DIR/faradayos.ks}
grep -qE "^${ED}[[:space:]]*\|" "$DIR/editions.list" || { echo "Unknown edition '$ED'. Editions: $(grep -oE '^[a-z0-9-]+' "$DIR/editions.list" | xargs)" >&2; exit 2; }
awk -v ed="$ED" '
  /^#@if[[:space:]]/ { if (inblk) { print "edition-ks: nested #@if at line " NR > "/dev/stderr"; exit 3 }
                       inblk=1; keep=0; for (i=2; i<=NF; i++) if ($i == ed) keep=1; next }
  /^#@end[[:space:]]*$/ { if (!inblk) { print "edition-ks: #@end without #@if at line " NR > "/dev/stderr"; exit 3 }
                       inblk=0; next }
  !inblk || keep
  END { if (inblk) { print "edition-ks: #@if not closed" > "/dev/stderr"; exit 3 } }
' "$KS"
