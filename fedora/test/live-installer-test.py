#!/usr/bin/env python3
"""Boots a FaradayOS live ISO in QEMU and starts the installer the way the desktop icon does.

Checks that the live desktop survives the installer starting, and saves screenshots and logs.
Usage: live-installer-test.py ISO OUTDIR [--mem MiB] [--minutes N]
Needs: qemu-system-x86_64, 7z, python3-pil. Uses KVM when /dev/kvm is usable.
"""
import argparse, json, os, re, socket, subprocess, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("iso")
ap.add_argument("out")
ap.add_argument("--mem", type=int, default=4096)
ap.add_argument("--minutes", type=int, default=6, help="how long to watch after the installer starts")
ap.add_argument("--boot-timeout", type=int, default=1500)
ap.add_argument("--prep", default="", help="shell command to run as root in the live system before the installer starts")
a = ap.parse_args()

os.makedirs(a.out, exist_ok=True)
W = os.path.abspath(a.out)
LOG = open(os.path.join(W, "serial.log"), "wb")
kvm = os.access("/dev/kvm", os.R_OK | os.W_OK)
mult = 1 if kvm else 6  # software emulation is much slower


def say(*m):
    print(time.strftime("%H:%M:%S"), *m, flush=True)


# Kernel, initrd and boot options from the ISO itself
subprocess.run(["7z", "x", "-y", f"-o{W}/boot", a.iso, "images/pxeboot/vmlinuz", "images/pxeboot/initrd.img",
                "EFI/BOOT/grub.cfg"], check=True, stdout=subprocess.DEVNULL)
cfg = open(f"{W}/boot/EFI/BOOT/grub.cfg").read()
cmdline = re.search(r"^\s*linux\s+/images/pxeboot/vmlinuz\s+(.*)$", cfg, re.M).group(1)
cmdline = re.sub(r"\b(quiet|rhgb|rd\.live\.check)\b", "", cmdline)
cmdline = " ".join(cmdline.split()) + " console=tty0 console=ttyS0,115200"
say("boot options:", cmdline)

disk = f"{W}/disk.qcow2"
subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", disk, "64G"], check=True)
for s in ("serial.sock", "qmp.sock"):
    if os.path.exists(f"{W}/{s}"):
        os.unlink(f"{W}/{s}")
qemu = subprocess.Popen([
    "qemu-system-x86_64", "-machine", "q35", "-accel", "kvm" if kvm else "tcg",
    "-cpu", "host" if kvm else "max", "-smp", "4", "-m", str(a.mem),
    "-device", "virtio-vga", "-display", "none",
    "-device", "qemu-xhci", "-device", "usb-tablet", "-device", "usb-kbd",
    "-drive", f"file={a.iso},media=cdrom,readonly=on,if=none,id=cd", "-device", "ide-cd,drive=cd",
    "-drive", f"file={disk},if=virtio",
    "-netdev", "user,id=n0", "-device", "virtio-net-pci,netdev=n0",
    "-kernel", f"{W}/boot/images/pxeboot/vmlinuz", "-initrd", f"{W}/boot/images/pxeboot/initrd.img",
    "-append", cmdline,
    "-serial", f"unix:{W}/serial.sock,server=on,wait=off",
    "-qmp", f"unix:{W}/qmp.sock,server=on,wait=off",
], stdout=open(f"{W}/qemu.log", "w"), stderr=subprocess.STDOUT)
say("QEMU started, KVM" if kvm else "QEMU started, software emulation (slow)")


def connect(path):
    for _ in range(100):
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(path)
            return s
        except OSError:
            time.sleep(0.2)
    sys.exit("cannot connect to " + path)


ser = connect(f"{W}/serial.sock")
ser.settimeout(1)
qmp = connect(f"{W}/qmp.sock")
qf = qmp.makefile("rw")
qf.readline()
qf.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); qf.flush(); qf.readline()
buf = b""


def read_until(pattern, timeout, want_hit=False):
    """Reads serial output until regex `pattern` matches; returns the text before the match."""
    global buf
    end = time.time() + timeout * mult
    rx = re.compile(pattern.encode())
    while time.time() < end:
        m = rx.search(buf)
        if m:
            out, hit, buf = buf[:m.start()], m.group(0), buf[m.end():]
            return out.decode(errors="replace") + ("\0" + hit.decode(errors="replace") if want_hit else "")
        if qemu.poll() is not None:
            raise RuntimeError("QEMU exited")
        try:
            d = ser.recv(65536)
        except socket.timeout:
            continue
        LOG.write(d); LOG.flush()
        buf += d
    raise TimeoutError(pattern)


def send(text):
    ser.sendall(text.encode())


n = 0


def run(cmd, timeout=120):
    """Runs a shell command on the serial console and returns its output."""
    global n
    n += 1
    mark = f"__END{n}__"
    send(f"{cmd}; echo {mark[:5]}''{mark[5:]}\r")
    out = read_until(re.escape(mark) + r"\r?\n", timeout)
    out = re.sub(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b\[[0-9;?]*[a-zA-Z]|\r", "", out)  # terminal escapes
    return "\n".join(l for l in out.split("\n") if "__END" not in l).strip("\n")


shot_n = 0


def shot(name):
    global shot_n
    shot_n += 1
    ppm = f"{W}/shot.ppm"
    qf.write(json.dumps({"execute": "screendump", "arguments": {"filename": ppm}}) + "\n"); qf.flush()
    while True:
        r = json.loads(qf.readline())
        if "return" in r or "error" in r:
            break
    try:
        from PIL import Image
        from PIL import ImageStat
        im = Image.open(ppm)
        im.save(f"{W}/{shot_n:02d}-{name}.png")
        return round(ImageStat.Stat(im.convert("L")).mean[0])  # 0 = black screen
    except Exception as e:  # noqa: BLE001
        say("screenshot failed:", e)


def report(title, text):
    open(f"{W}/{re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')}.txt", "w").write(text)
    print(f"::group::{title}\n{text}\n::endgroup::", flush=True)


result = {"booted": False, "desktop": False, "installer_window": False, "session_survived": False}
try:
    read_until(r"login: ", a.boot_timeout)
    say("serial login prompt")
    time.sleep(3)
    send("root\r")  # the live system's root account has no password
    if read_until(r"(Password: |# )", 120, want_hit=True).endswith("Password: "):
        send("\r")
        read_until(r"# ", 60)
    send("export PS1='$ ' TERM=dumb; bind 'set enable-bracketed-paste off'; stty -echo cols 250; dmesg -n 1\r")
    read_until(r"\$ ", 30)
    result["booted"] = True
    say("logged in as root on serial console")

    # Wait for the live desktop (Plasma) to be up
    for _ in range(120):
        p = run("pgrep -u liveuser -x plasmashell >/dev/null && pgrep -x kwin_wayland >/dev/null && echo UP || echo DOWN")
        if "UP" in p:
            break
        time.sleep(5)
    time.sleep(20 * mult)
    result["desktop"] = "UP" in p
    say("desktop up:", result["desktop"], "screen brightness:", shot("desktop"))
    report("before", run(
        "uname -r; free -m; cat /proc/cmdline; loginctl list-sessions; systemctl --failed --no-pager; "
        "ps -eo pid,user,rss,cmd --sort=-rss | head -25; "
        "ls -la ~liveuser/Desktop; head -3 /etc/sudoers.d/*; ls /etc/polkit-1/rules.d"))
    kwin_before = run("pgrep -x kwin_wayland").strip()
    shell_before = run("pgrep -u liveuser -x plasmashell").strip()

    if a.prep:
        report("prep", run(a.prep + " 2>&1 | tail -n 30", 900))

    # Start the installer the way the desktop icon and the Welcome app do (Exec=liveinst, in the Plasma session)
    say("starting installer")
    run("date +%s > /tmp/faraday-t0")
    run("systemd-run --user -M liveuser@.host --unit=faraday-test-liveinst --collect liveinst")
    t0 = time.time()
    while time.time() - t0 < a.minutes * 60 * mult:
        time.sleep(15)
        st = run("echo kwin=$(pgrep -x kwin_wayland) shell=$(pgrep -u liveuser -x plasmashell) "
                 "anaconda=$(pgrep -f -c 'bin/anaconda') win=$(pgrep -c -f 'slitherer|firefox') "
                 "mem=$(free -m | awk '/Mem:/{print $7}')MB")
        say(st.strip(), "screen brightness:", shot("installer"))
        if "win=0" not in st:
            result["installer_window"] = True
    st = run("echo kwin=$(pgrep -x kwin_wayland) shell=$(pgrep -u liveuser -x plasmashell)")
    result["session_survived"] = (f"kwin={kwin_before}" in st and f"shell={shell_before}" in st)
    say("session survived:", result["session_survived"])

    report("after", run(
        "free -m; loginctl list-sessions; systemctl --failed --no-pager; coredumpctl list --no-pager; "
        "ps -eo pid,user,rss,cmd --sort=-rss | head -30; systemctl --user -M liveuser@.host status faraday-test-liveinst --no-pager -l; "
        "coredumpctl info --no-pager 2>/dev/null | grep -E 'Executable:|Signal:|Timestamp:|Stack trace|^ +#([0-9]|1[0-9]) ' | head -150", 300))
    # The job log is the only output some readers can see, so print the important parts there (filtered in the VM:
    # the serial line is too slow for the whole journal)
    pat = ("kwin|plasmashell|KCrash|dumped core|segfault|oom|Out of memory|Killed process|liveinst|pkexec|anaconda|"
           "webui|slitherer|Wayland connection|Removed session|session closed|plasmalogin|startplasma|nvidia|"
           "Failed to start|Traceback|memory pressure")
    report("journal", run(f"journalctl -b --no-pager -o short-monotonic | grep -iE '{pat}' | grep -v audit | "
                          "cut -c1-260 | tail -300", 300))
    report("oom", run("journalctl -b --no-pager -o short-monotonic -u systemd-oomd | tail -40; "
                      "dmesg | grep -iE 'oom|killed process' | tail -20", 120))
    report("anaconda.log", run("tail -n 30 /tmp/anaconda.log; ls -la /tmp", 120))
    report("dbus.log + webui log", run("cat /tmp/dbus.log; tail -n 80 /tmp/anaconda-webui.log", 120))
    report("journal: first events after the installer started", run(
        "journalctl -b --no-pager -o short-monotonic --since=@$(cat /tmp/faraday-t0) | grep -v audit | "
        "grep -viE 'slitherer.*(Uncaught|ErrorBoundary)|^ +(Traceback|File|#)' | cut -c1-260 | head -250", 300))
    report("journal: keyboard and session", run(
        "journalctl -b --no-pager -o short-monotonic --since=@$(cat /tmp/faraday-t0) | "
        "grep -iE 'locale|kxkb|keyboard|layout|logout|ksmserver|Stopping|startplasma|plasmalogin|logind' | "
        "grep -v audit | cut -c1-260 | head -150", 300))
except Exception as e:  # noqa: BLE001
    say("test error:", repr(e))
    shot("error")
finally:
    json.dump(result, open(f"{W}/result.json", "w"), indent=1)
    say("result:", result)
    qemu.kill()

sys.exit(0 if all(result.values()) else 1)
