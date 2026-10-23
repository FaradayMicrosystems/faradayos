#!/usr/bin/env bash
# Downloads the FaradayOS test ISO from the iso-test branch and joins it into one verified file.
#   curl -fsSL https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.sh | bash
set -euo pipefail
BASE="${BASE:-https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test}"
ISO=FaradayOSv0.0.1-test.iso
N=69
mkdir -p faradayos-iso-parts && cd faradayos-iso-parts
curl -fsSLO "$BASE/$ISO.sha256"
for i in $(seq -f %02g 0 $((N-1))); do
  f="$ISO.p$i"
  echo "Downloading part $((10#$i+1)) of $N"
  curl -fsSL --retry 5 -o "$f" "$BASE/$f"
done
echo "Joining..."
cat "$ISO".p[0-9][0-9] > "../$ISO"
cd .. && cp faradayos-iso-parts/$ISO.sha256 . 
if command -v sha256sum >/dev/null; then sha256sum -c "$ISO.sha256"; else shasum -a 256 -c "$ISO.sha256"; fi
rm -rf faradayos-iso-parts
echo "Done: $(pwd)/$ISO"
