#!/bin/bash
# Finds which app sends the empty notification box at the top right.
# Listens for notifications, replays the sign-in apps, then prints who sent what.
out=$(mktemp)
dbus-monitor --session "type='method_call',member='Notify'" > "$out" 2>&1 &
mon=$!
sleep 1
echo "Replaying sign-in apps (a box may pop up, that's expected)..."
systemctl --user restart 'app-*@autostart.service' 2>/dev/null
sleep 15
kill $mon 2>/dev/null
echo
echo "== Notifications caught"
awk '/member=Notify/{n++; split($0,a,"sender="); split(a[2],b," "); print "\n-- #" n " from " b[1]; c=9; next}
     c>0 && /^ +(string|int32|uint32)/{print; c--}' "$out"
echo
echo "== Urgency (2 = critical, stays until closed)"
grep -A1 '"urgency"' "$out" | grep -o 'byte [0-9]' || echo "none given"
echo
echo "== Senders still running"
for s in $(grep -o 'sender=[^ ]*' "$out" | cut -d= -f2 | sort -u); do
  busctl --user status "$s" 2>/dev/null | grep -E '^(Comm|CommandLine)=' | sed "s/^/$s /"
done
echo
echo "== Wallpaper toast setting"
grep -o '"notifyOnWallpaperChange"[^,}]*' ~/.config/ryoku/ryogami.json 2>/dev/null || echo "not set (on by default)"
