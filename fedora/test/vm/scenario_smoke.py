#!/usr/bin/env python3
"""Checks the VM rig itself: live boot, desktop, screenshot, keyboard, unattended install, boot of the installed disk."""
import sys, time
from vmlib import VM, say, install_unattended

iso, out = sys.argv[1], sys.argv[2]
vm = VM(out, iso=iso)
try:
    vm.start(live=True)
    vm.login_root()
    say("desktop:", vm.wait_desktop())
    vm.shot("live-desktop")
    vm.report("display", vm.run("fgconsole; cat /sys/class/tty/tty0/active; ls -l /dev/dri; cat /sys/class/drm/*/status; "
                                "lspci -k | grep -A3 -i vga; journalctl -b --no-pager -o cat _COMM=niri | head -80"))
    vm.report("niri", vm.as_user("niri msg outputs; niri msg layers; niri msg windows"))
    time.sleep(30); vm.shot("live-desktop-45s")
    vm.key("super+space"); time.sleep(3); vm.shot("super-space")
    vm.key("esc"); time.sleep(1)
    ok = install_unattended(vm)
    vm.start(live=False)
    time.sleep(90); vm.shot("installed-boot-90s")
    vm.login_root(user="root", password="faraday")
    vm.report("installed", vm.run("cat /etc/os-release; systemctl --failed --no-pager; id tester; systemctl is-active sddm"))
    vm.shot("installed-login-screen")
finally:
    vm.stop()
