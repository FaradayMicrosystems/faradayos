"""Small QEMU driver for FaradayOS VM tests: boot the live ISO or an installed disk, run commands as root on the
serial console, take screenshots, press keys, type text and click with the mouse (QMP input events).

Used by the scenario scripts in this folder (scenario_*.py). Uses KVM when /dev/kvm is usable, UEFI (OVMF).
Screen coordinates are in pixels of the guest screen (default 1920x1080, virtio-vga).
"""
import json, os, re, shutil, socket, subprocess, sys, time

OVMF_CODE = next((p for p in ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_CODE.fd",
                             "/usr/share/edk2/ovmf/OVMF_CODE.fd") if os.path.exists(p)), None)
OVMF_VARS = next((p for p in ("/usr/share/OVMF/OVMF_VARS_4M.fd", "/usr/share/OVMF/OVMF_VARS.fd",
                             "/usr/share/edk2/ovmf/OVMF_VARS.fd") if os.path.exists(p)), None)


def say(*m):
    print(time.strftime("%H:%M:%S"), *m, flush=True)


class VM:
    def __init__(self, out, iso=None, disk=None, mem=8192, smp=4, width=1920, height=1080, disk_size="64G",
                 gpu=None):
        os.makedirs(out, exist_ok=True)
        self.W = os.path.abspath(out)
        self.iso = iso
        self.disk = disk or f"{self.W}/disk.qcow2"
        self.mem, self.smp, self.width, self.height = mem, smp, width, height
        # "std" = QEMU standard VGA (bochs-drm in the guest): Mesa renders in software (llvmpipe), so niri can draw.
        # "virtio" = virtio-vga without 3D: niri cannot render there ("no allocator available"), screen stays black.
        self.gpu = gpu or os.environ.get("VM_GPU", "virgl")
        self.kvm = os.access("/dev/kvm", os.R_OK | os.W_OK)
        self.mult = 1 if self.kvm else 6
        self.vars = f"{self.W}/OVMF_VARS.fd"
        if not os.path.exists(self.disk):
            subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", self.disk, disk_size], check=True)
        if OVMF_VARS and not os.path.exists(self.vars):
            shutil.copy(OVMF_VARS, self.vars)
        self.qemu = None
        self.shot_n = 0
        self.cmd_n = 0
        self.buf = b""
        self.log = open(f"{self.W}/serial.log", "ab")
        self.findings = []

    def _gpu_args(self):
        if self.gpu == "virgl":
            # 3D virtio GPU, rendered on the host with Mesa llvmpipe through a vgem render node (no real GPU needed)
            node = next((f"/dev/dri/{n}" for n in sorted(os.listdir("/dev/dri")) if n.startswith("renderD")), None) \
                if os.path.isdir("/dev/dri") else None
            return ["-device", f"virtio-vga-gl,xres={self.width},yres={self.height}",
                    "-display", "egl-headless" + (f",rendernode={node}" if node else "")]
        if self.gpu == "std":
            return ["-device", f"VGA,xres={self.width},yres={self.height},vgamem_mb=64", "-display", "none"]
        return ["-device", f"virtio-vga,xres={self.width},yres={self.height}", "-display", "none"]

    # ---------------------------------------------------------------- start / stop
    def start(self, live=True, extra_append=""):
        """live=True: boot the ISO's kernel directly with a serial console (like the release test).
        live=False: boot the installed disk through its own bootloader (UEFI)."""
        args = ["qemu-system-x86_64", "-machine", "q35", "-accel", "kvm" if self.kvm else "tcg",
                "-cpu", "host" if self.kvm else "max", "-smp", str(self.smp), "-m", str(self.mem),
                *self._gpu_args(),
                "-device", "qemu-xhci", "-device", "usb-tablet", "-device", "usb-kbd",
                "-audiodev", "none,id=snd0", "-device", "intel-hda", "-device", "hda-duplex,audiodev=snd0",  # a sound card, so audio can be checked
                "-drive", f"file={self.disk},if=virtio",
                "-netdev", "user,id=n0", "-device", "virtio-net-pci,netdev=n0",
                "-serial", f"unix:{self.W}/serial.sock,server=on,wait=off",
                "-qmp", f"unix:{self.W}/qmp.sock,server=on,wait=off"]
        if OVMF_CODE:
            args += ["-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
                     "-drive", f"if=pflash,format=raw,file={self.vars}"]
        if live:
            b = f"{self.W}/boot"
            if not os.path.exists(f"{b}/images/pxeboot/vmlinuz"):
                subprocess.run(["7z", "x", "-y", f"-o{b}", self.iso, "images/pxeboot/vmlinuz",
                                "images/pxeboot/initrd.img", "EFI/BOOT/grub.cfg"], check=True, stdout=subprocess.DEVNULL)
            cfg = open(f"{b}/EFI/BOOT/grub.cfg").read()
            cmdline = re.search(r"^\s*linux\s+/images/pxeboot/vmlinuz\s+(.*)$", cfg, re.M).group(1)
            cmdline = re.sub(r"\b(rd\.live\.check)\b", "", cmdline)  # keep quiet/rhgb: what a person sees
            cmdline = " ".join(cmdline.split()) + " console=tty0 console=ttyS0,115200 " + extra_append
            say("live boot options:", cmdline)
            args += ["-drive", f"file={self.iso},media=cdrom,readonly=on,if=none,id=cd", "-device", "ide-cd,drive=cd",
                     "-kernel", f"{b}/images/pxeboot/vmlinuz", "-initrd", f"{b}/images/pxeboot/initrd.img",
                     "-append", cmdline.strip()]
        for s in ("serial.sock", "qmp.sock"):
            if os.path.exists(f"{self.W}/{s}"):
                os.unlink(f"{self.W}/{s}")
        self.qemu = subprocess.Popen(args, stdout=open(f"{self.W}/qemu.log", "a"), stderr=subprocess.STDOUT)
        time.sleep(2)
        if self.qemu.poll() is not None:
            print(open(f"{self.W}/qemu.log").read()[-3000:], flush=True)
            raise RuntimeError("QEMU did not start: " + " ".join(args))
        say("QEMU started", "(KVM)" if self.kvm else "(software emulation, slow)", "live" if live else "installed disk")
        self.ser = self._connect(f"{self.W}/serial.sock")
        self.ser.settimeout(1)
        q = self._connect(f"{self.W}/qmp.sock")
        self.qf = q.makefile("rw")
        self.qf.readline()
        self.qmp("qmp_capabilities")
        self.buf = b""

    def stop(self):
        if self.qemu and self.qemu.poll() is None:
            self.qemu.kill()
            self.qemu.wait()

    def shutdown(self, timeout=180):
        """Clean power-off from inside (serial root shell), waits for QEMU to exit."""
        try:
            self.send("systemctl poweroff\r")
        except OSError:
            pass
        end = time.time() + timeout
        while time.time() < end and self.qemu.poll() is None:
            self._drain()
        self.stop()

    def _connect(self, path):
        for _ in range(100):
            try:
                s = socket.socket(socket.AF_UNIX)
                s.connect(path)
                return s
            except OSError:
                time.sleep(0.2)
        sys.exit("cannot connect to " + path)

    def qmp(self, cmd, **arguments):
        msg = {"execute": cmd}
        if arguments:
            msg["arguments"] = arguments
        self.qf.write(json.dumps(msg) + "\n"); self.qf.flush()
        while True:
            r = json.loads(self.qf.readline())
            if "return" in r or "error" in r:
                return r

    # ---------------------------------------------------------------- serial console
    def _drain(self):
        try:
            d = self.ser.recv(65536)
        except socket.timeout:
            return
        except OSError:
            time.sleep(1); return
        self.log.write(d); self.log.flush()
        self.buf += d

    def read_until(self, pattern, timeout, want_hit=False):
        end = time.time() + timeout * self.mult
        rx = re.compile(pattern.encode())
        while time.time() < end:
            m = rx.search(self.buf)
            if m:
                out, hit, self.buf = self.buf[:m.start()], m.group(0), self.buf[m.end():]
                return out.decode(errors="replace") + ("\0" + hit.decode(errors="replace") if want_hit else "")
            if self.qemu.poll() is not None:
                raise RuntimeError("QEMU exited")
            self._drain()
        raise TimeoutError(pattern)

    def send(self, text):
        # Small pieces: the emulated serial port drops characters when a long command arrives at once
        b = text.encode()
        for i in range(0, len(b), 32):
            self.ser.sendall(b[i:i + 32])
            time.sleep(0.01)

    def login_root(self, timeout=1500, user="root", password=""):
        """Waits for the serial login prompt and logs in (live root has no password). Then commands can be run."""
        self.read_until(r"login: ", timeout)
        time.sleep(3)
        self.send(user + "\r")
        if self.read_until(r"(Password: |# |\$ )", 120, want_hit=True).endswith("Password: "):
            self.send(password + "\r")
            self.read_until(r"(# |\$ )", 60)
        if user != "root":
            self.send(f"sudo -S -i <<<'{password}'\r" if password else "sudo -i\r")
            time.sleep(3)
        self.send("export PS1='$ ' TERM=dumb SYSTEMD_PAGER= PAGER=cat; bind 'set enable-bracketed-paste off'; "
                  "stty -echo cols 250; dmesg -n 1\r")
        self.read_until(r"\$ ", 30)
        say("logged in on serial console as", user)

    def run(self, cmd, timeout=120):
        """Runs a shell command as root on the serial console and returns its output."""
        self.cmd_n += 1
        mark = f"__END{self.cmd_n}__"
        self.send(f"{cmd}; echo {mark[:5]}''{mark[5:]}\r")
        out = self.read_until(re.escape(mark) + r"\r?\n", timeout)
        out = re.sub(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b\[[0-9;?]*[a-zA-Z]|\r", "", out)
        out = "\n".join(l for l in out.split("\n") if "__END" not in l).strip("\n")
        return re.sub(r"^(\$ )+", "", out)

    def write_file(self, path, content):
        """Writes a file inside the VM (as root)."""
        import base64
        b = base64.b64encode(content.encode()).decode()
        self.run(f": > {path}.b64")
        for i in range(0, len(b), 1000):
            self.run(f"echo {b[i:i + 1000]} >> {path}.b64")
        self.run(f"base64 -d {path}.b64 > {path} && rm {path}.b64")

    def as_user(self, cmd, user="liveuser", uid=1000, timeout=120):
        """Runs a command as the desktop user inside the graphical session (niri socket + Wayland env)."""
        env = (f"XDG_RUNTIME_DIR=/run/user/{uid} WAYLAND_DISPLAY=$(ls /run/user/{uid}/ | grep -E '^wayland-[0-9]+$' | head -1) "
               f"NIRI_SOCKET=$(ls /run/user/{uid}/niri.*.sock 2>/dev/null | head -1) "
               f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus")
        return self.run(f"runuser -u {user} -- env {env} sh -c {json.dumps(cmd)} 2>&1", timeout)

    def wait_desktop(self, user="liveuser", tries=120):
        for _ in range(tries):
            p = self.run(f"pgrep -u {user} -f '^qs.-c.shell$' >/dev/null && pgrep -x niri >/dev/null && echo UP || echo DOWN")
            if "UP" in p:
                time.sleep(15)
                return True
            time.sleep(5)
        return False

    # ---------------------------------------------------------------- screen
    def shot(self, name):
        """Saves NN-name.png in the output folder. Returns the average brightness (0 = black)."""
        self.shot_n += 1
        ppm = f"{self.W}/shot.ppm"
        self.qmp("screendump", filename=ppm)
        try:
            from PIL import Image, ImageStat
            im = Image.open(ppm)
            path = f"{self.W}/{self.shot_n:02d}-{re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')}.png"
            im.save(path, optimize=True)
            b = round(ImageStat.Stat(im.convert("L")).mean[0])
            say(f"screenshot {os.path.basename(path)} brightness {b}")
            return b
        except Exception as e:  # noqa: BLE001
            say("screenshot failed:", e)

    # ---------------------------------------------------------------- input
    KEYS = {"enter": "ret", "return": "ret", "esc": "esc", "escape": "esc", "tab": "tab", "space": "spc",
            "backspace": "backspace", "up": "up", "down": "down", "left": "left", "right": "right",
            "super": "meta_l", "meta": "meta_l", "win": "meta_l", "ctrl": "ctrl", "alt": "alt", "shift": "shift",
            "delete": "delete", "home": "home", "end": "end", "pgup": "pgup", "pgdn": "pgdn", "print": "print"}

    def key(self, combo, hold=0.08):
        """Presses a key combination like 'super+space', 'ctrl+alt+f2', 'enter', 'a'."""
        names = [self.KEYS.get(k.lower(), k.lower()) for k in combo.split("+")]
        ev = lambda n, down: {"type": "key", "data": {"down": down, "key": {"type": "qcode", "data": n}}}
        self.qmp("input-send-event", events=[ev(n, True) for n in names])
        time.sleep(hold)
        self.qmp("input-send-event", events=[ev(n, False) for n in reversed(names)])
        time.sleep(0.15)

    SHIFTED = {'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8', '(': '9', ')': '0',
               '_': 'minus', '+': 'equal', '{': 'bracket_left', '}': 'bracket_right', '|': 'backslash', ':': 'semicolon',
               '"': 'apostrophe', '<': 'comma', '>': 'dot', '?': 'slash', '~': 'grave_accent'}
    PLAIN = {' ': 'spc', '-': 'minus', '=': 'equal', '[': 'bracket_left', ']': 'bracket_right', '\\': 'backslash',
             ';': 'semicolon', "'": 'apostrophe', ',': 'comma', '.': 'dot', '/': 'slash', '`': 'grave_accent',
             '\n': 'ret'}

    def type(self, text, delay=0.04):
        """Types text on the US keyboard layout."""
        for ch in text:
            if ch in self.PLAIN:
                self.key(self.PLAIN[ch], 0.03)
            elif ch in self.SHIFTED:
                self.key("shift+" + self.SHIFTED[ch], 0.03)
            elif ch.isupper():
                self.key("shift+" + ch.lower(), 0.03)
            else:
                self.key(ch, 0.03)
            time.sleep(delay)

    def move(self, x, y):
        X = int(x * 32767 / (self.width - 1)); Y = int(y * 32767 / (self.height - 1))
        self.qmp("input-send-event", events=[{"type": "abs", "data": {"axis": "x", "value": X}},
                                             {"type": "abs", "data": {"axis": "y", "value": Y}}])
        time.sleep(0.2)

    def click(self, x, y, button="left", double=False):
        self.move(x, y)
        for _ in range(2 if double else 1):
            for down in (True, False):
                self.qmp("input-send-event", events=[{"type": "btn", "data": {"down": down, "button": button}}])
                time.sleep(0.08)
        time.sleep(0.3)

    def scroll(self, x, y, down=True, steps=3):
        self.move(x, y)
        b = "wheel-down" if down else "wheel-up"
        for _ in range(steps):
            for d in (True, False):
                self.qmp("input-send-event", events=[{"type": "btn", "data": {"down": d, "button": b}}])
            time.sleep(0.1)

    # ---------------------------------------------------------------- reporting
    def report(self, title, text):
        open(f"{self.W}/{re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')}.txt", "w").write(text)
        print(f"::group::{title}\n{text}\n::endgroup::", flush=True)

    def note(self, text):
        """A finding (something broken or off) for the summary."""
        say("FINDING:", text)
        self.findings.append(text)
        open(f"{self.W}/findings.txt", "a").write(text + "\n")


KS_INSTALL = """# Unattended install used by the VM tests (same live image the installer copies)
cmdline
lang en_US.UTF-8
keyboard us
timezone Australia/Brisbane --utc
network --bootproto=dhcp --hostname=faradayos
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart
bootloader --append="console=tty0 console=ttyS0,115200"
rootpw --plaintext faraday
user --name=tester --password=faraday --plaintext --groups=wheel --gecos="Test User"
poweroff
"""


def install_unattended(vm, timeout=2400):
    """From the live system's root shell: installs to the VM disk with Anaconda (live image copy, kickstart),
    then powers off. Afterwards vm.start(live=False) boots the installed system (root and tester: password faraday)."""
    vm.write_file("/root/vmtest.ks", KS_INSTALL)
    say("unattended install started")
    vm.run("nohup sh -c 'anaconda --liveinst --cmdline --kickstart /root/vmtest.ks >/root/anaconda-run.txt 2>&1; "
           "echo rc=$? >/root/anaconda-rc' >/dev/null 2>&1 &")
    end = time.time() + timeout
    last = ""
    try:
        while time.time() < end:
            time.sleep(30)
            last = vm.run("cat /root/anaconda-rc 2>/dev/null; tail -n 3 /root/anaconda-run.txt | cut -c1-200", 60)
            say("install:", last.replace("\n", " | ")[-300:])
            if "rc=" in last:
                vm.report("unattended install (anaconda exited)", vm.run(
                    "tail -n 60 /root/anaconda-run.txt; tail -n 80 /tmp/anaconda.log; "
                    "grep -iE 'error|traceback' /tmp/packaging.log /tmp/storage.log 2>/dev/null | tail -30", 120))
                break
    except (RuntimeError, OSError, TimeoutError):
        say("VM powered off (kickstart 'poweroff' = install finished)")
    if vm.qemu.poll() is None:
        vm.shot("after-install")
    vm.stop()
    ok = "rc=" not in last or "rc=0" in last
    say("install finished:", ok)
    return ok
