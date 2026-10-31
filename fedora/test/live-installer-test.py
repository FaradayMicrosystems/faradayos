#!/usr/bin/env python3
"""Boots a FaradayOS live ISO in QEMU and starts the installer the way the desktop icon does.

Checks that the live desktop survives the installer starting, and saves screenshots and logs.
Usage: live-installer-test.py ISO OUTDIR [--mem MiB] [--minutes N]
Needs: qemu-system-x86_64, 7z, python3-pil. Uses KVM when /dev/kvm is usable.
"""
import argparse, base64, json, lzma, os, re, socket, subprocess, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("iso")
ap.add_argument("out")
ap.add_argument("--mem", type=int, default=4096)
ap.add_argument("--minutes", type=int, default=6, help="how long to watch after the installer starts")
ap.add_argument("--boot-timeout", type=int, default=1500)
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
    return out.split("\n", 1)[1] if "\n" in out else out


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


def fetch(cmd, name, timeout=600):
    """Copies a command's output to OUTDIR/name over the serial console (xz + base64)."""
    out = run(f"{cmd} 2>&1 | xz -T0 -6 | base64 -w0; echo", timeout)
    try:
        data = lzma.decompress(base64.b64decode(re.sub(r"[^A-Za-z0-9+/=]", "", out)))
        open(f"{W}/{name}", "wb").write(data)
    except Exception as e:  # noqa: BLE001
        say(f"could not fetch {name}:", e)


def report(title, text):
    open(f"{W}/{title.split()[0]}.txt", "w").write(text)
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

    # Start the installer the way the desktop icon and the Welcome app do (Exec=liveinst, in the Plasma session)
    say("starting installer")
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
    fetch("journalctl -b --no-pager -o short-monotonic", "journal.txt")
    fetch("cat /tmp/anaconda.log /tmp/storage.log /tmp/program.log /tmp/packaging.log", "anaconda-logs.txt")
    fetch("cat /tmp/webui-desktop.log /tmp/*.log 2>/dev/null; ls -la /tmp", "tmp-logs.txt")
    # The job log is the only output some readers can see, so print the important parts there too
    rx = re.compile(r"kwin|plasmashell|KCrash|dumped core|segfault|SIG(SEGV|ABRT|KILL)|oom|Out of memory|liveinst|pkexec|"
                    r"anaconda|webui|slitherer|polkit|Wayland connection|Removed session|session closed|plasmalogin|"
                    r"drm|nvidia|gpu|Failed to start|Traceback|Error", re.I)
    try:
        lines = [l for l in open(f"{W}/journal.txt", errors="replace") if rx.search(l) and "audit" not in l]
        report("journal (filtered, last 250)", "".join(l[:260] + "\n" if len(l) > 260 else l for l in lines[-250:]))
        report("anaconda.log (last 60)", "".join(open(f"{W}/anaconda-logs.txt", errors="replace").readlines()[-60:]))
    except OSError as e:
        say("no logs:", e)
except Exception as e:  # noqa: BLE001
    say("test error:", repr(e))
    shot("error")
finally:
    json.dump(result, open(f"{W}/result.json", "w"), indent=1)
    say("result:", result)
    qemu.kill()

sys.exit(0 if all(result.values()) else 1)
