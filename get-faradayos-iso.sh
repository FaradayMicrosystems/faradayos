#!/usr/bin/env bash
# Downloads the FaradayOS test ISO from the iso-test branch and joins it into one verified file.
#   curl -fsSL https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.sh | bash
# Needs about 13 GB free while it runs (pieces + ISO); the pieces are deleted at the end.
set -euo pipefail
BASE=https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test
ISO=FaradayOSv0.0.1-test.iso
N=69
mkdir -p faradayos-iso-parts
curl -fsSL "$BASE/$ISO.sha256" -o "$ISO.sha256"
for i in $(seq 0 $((N-1))); do
  p=$(printf '%s.p%02d' "$ISO" "$i")
  [ -s "faradayos-iso-parts/$p" ] && continue
  echo "Downloading piece $((i+1)) of $N"
  curl -fL --retry 5 -C - "$BASE/$p" -o "faradayos-iso-parts/$p"
done
echo "Joining..."
cat faradayos-iso-parts/"$ISO".p[0-9][0-9] > "$ISO"
echo "Verifying..."
sha256sum -c "$ISO.sha256"
rm -rf faradayos-iso-parts
echo "Done: $PWD/$ISO"
