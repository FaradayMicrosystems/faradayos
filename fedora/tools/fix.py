#!/usr/bin/python3
# FaradayOS: stop "ghost" notification cards (the empty box with an X at the top right).
# A popup card can outlive its notification: the card then draws an empty frame with no app
# name, text or time, and its X does nothing because there is nothing left to dismiss.
# This patches Ryoku's NotificationPopups.qml so a card is dropped as soon as its notification
# is gone (or never got an arrival time), and re-checks every 2 s while cards are up.
# Safe to run again: a patched file is left alone. Usage: no-ghost-popups.py [--check]
import glob, os, sys

MARK = "// FaradayOS: no ghost cards"
FILES = sorted(set(glob.glob("/usr/share/ryoku/**/modules/notifications/NotificationPopups.qml", recursive=True)
                   + glob.glob("/home/*/.config/quickshell/**/modules/notifications/NotificationPopups.qml", recursive=True)
                   + glob.glob(os.path.expanduser("~/.config/quickshell/**/modules/notifications/NotificationPopups.qml"), recursive=True)))

EDITS = [
    # one place that decides whether a popup still has a real notification behind it
    ("    readonly property var popups: Notifs.popups\n",
     "    readonly property var popups: Notifs.popups\n"
     "    " + MARK + "\n"
     "    function live(p) { return !!p && p.id !== undefined && p.id !== null && !!Notifs.arrivalMs[p.id]; }\n"
     "    function liveCount() { var c = 0; for (var i = 0; i < (win.popups || []).length; i++) if (win.live(win.popups[i])) c++; return c; }\n"
     "    Timer { interval: 2000; repeat: true; running: win.mapped; onTriggered: { win.sync(); if (win.liveCount() === 0) unmapTimer.restart(); } }\n"),
    ("        var incoming = win.popups;\n",
     "        var incoming = (win.popups || []).filter(function(p) { return win.live(p); });\n"),
    ("            if (!keep) {\n",
     "            if (!keep || !cards.get(i).entry) {\n"),
    ("        if (popups.length > 0) {\n",
     "        if (win.liveCount() > 0) {\n"),
    ("        mapped = popups.length > 0;\n",
     "        mapped = win.liveCount() > 0;\n"),
    ("        onTriggered: if (win.popups.length === 0) win.mapped = false\n",
     "        onTriggered: if (win.liveCount() === 0) win.mapped = false\n"),
]


def patch(path):
    old = open(path).read()
    if MARK in old:
        return "already patched"
    new = old
    for a, b in EDITS:
        if new.count(a) != 1:
            return "SKIPPED (Ryoku changed this file; needs a new patch)"
        new = new.replace(a, b)
    if os.environ.get("DRY_RUN"):
        return "would patch"
    st = os.stat(path)
    tmp = path + ".faraday-tmp"
    with open(tmp, "w") as f:
        f.write(new)
    os.chown(tmp, st.st_uid, st.st_gid)
    os.chmod(tmp, st.st_mode & 0o7777)
    os.replace(tmp, path)
    return "patched"


def main():
    if not FILES:
        print("no-ghost-popups: NotificationPopups.qml not found")
        return 1
    bad = 0
    for path in FILES:
        if "--check" in sys.argv:
            ok = MARK in open(path).read()
            print(("ok       " if ok else "UNPATCHED"), path)
            bad += not ok
            continue
        try:
            res = patch(path)
        except PermissionError:
            res = "SKIPPED (no permission, run with sudo)"
        print("no-ghost-popups: %s: %s" % (path, res))
        bad += res.startswith("SKIPPED")
    return 1 if bad else 0


sys.exit(main())
