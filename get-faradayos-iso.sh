#!/usr/bin/env bash
# Downloads the FaradayOS test ISO from the iso-test branch and joins it into one verified file.
#   curl -fsSL https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.sh | bash
# Every piece is checked against its own checksum, so damaged or half-finished pieces from an
# earlier run are re-downloaded automatically. Safe to run again any time.
# Needs about 13 GB free while it runs; the pieces are deleted at the end.
set -euo pipefail
BASE=https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test
ISO=FaradayOSv0.0.1-test.iso
D=faradayos-iso-parts
mkdir -p "$D"
curl -fsSL "$BASE/$ISO.sha256" -o "$ISO.sha256"
curl -fsSL "$BASE/pieces.sha256" -o "$D/pieces.sha256"
N=$(wc -l < "$D/pieces.sha256"); i=0
while read -r sum p; do
  i=$((i+1)); f="$D/$p"
  if [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$sum" ]; then continue; fi
  for try in 1 2 3; do
    echo "Downloading piece $i of $N${try:+ (attempt $try)}"
    rm -f "$f"
    curl -fL --retry 5 --retry-delay 3 -s -S "$BASE/$p" -o "$f" || true
    [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$sum" ] && break
    echo "  piece $p was damaged, retrying"
    [ "$try" = 3 ] && { echo "Piece $p failed 3 times. Check your connection and run the script again."; exit 1; }
  done
done < "$D/pieces.sha256"
echo "All $N pieces verified. Joining..."
cat "$D"/"$ISO".p[0-9][0-9] > "$ISO"
echo "Verifying ISO..."
sha256sum -c "$ISO.sha256"
rm -rf "$D"
echo "Done: $PWD/$ISO"
