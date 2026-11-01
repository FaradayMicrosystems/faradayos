#!/bin/sh
# Names every GRUB boot entry "FaradayOS". Fedora's kernel packages write "Fedora Linux (...)" titles.
# Runs from the kernel-install hook (new kernels), the rebrand service (each boot) and the dnf hook (after updates).
E=/boot/loader/entries
[ -d $E ] || exit 0
MID=$(cat /etc/machine-id 2>/dev/null)
echo "$MID" | grep -qxE '[0-9a-f]{32}' || MID=""
for F in $E/*.conf; do
  [ -f "$F" ] || continue
  B=$(basename "$F" .conf)
  KV=$(sed -n 's/^version[[:space:]]*//p' "$F" | head -1)
  # Drop a stale copy left from the live image (other machine-id, same kernel or rescue): it shows up as a duplicate.
  if [ -n "$MID" ] && [ "${B#"$MID"-}" = "$B" ] && [ -f "$E/$MID-${B#*-}.conf" ]; then rm -f "$F"; continue; fi
  case "$B" in
    *rescue*) T="FaradayOS (rescue mode)" ;;
    *) T="FaradayOS (kernel ${KV%%.fc*})" ;;
  esac
  grep -qxF "title $T" "$F" || sed -i "s|^title.*|title $T|" "$F"
done
# Name used by grub2-mkconfig (Fedora sets it from /etc/system-release, which says "Fedora")
G=/etc/default/grub
if [ -f $G ]; then
  if grep -q '^GRUB_DISTRIBUTOR=' $G; then sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="FaradayOS"|' $G
  else echo 'GRUB_DISTRIBUTOR="FaradayOS"' >> $G; fi
fi
# If the default entry was a removed duplicate, make the newest FaradayOS kernel the default
if [ -n "$MID" ] && command -v grub2-editenv >/dev/null; then
  S=$(grub2-editenv list 2>/dev/null | sed -n 's/^saved_entry=//p')
  if [ -n "$S" ] && [ ! -f "$E/$S.conf" ]; then
    N=$(ls $E/"$MID"-*.conf 2>/dev/null | grep -v rescue | sort -V | tail -1)
    [ -n "$N" ] && grub2-editenv - set saved_entry="$(basename "$N" .conf)"
  fi
fi
true
