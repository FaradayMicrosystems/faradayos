#!/usr/bin/python3
"""FaradayOS Quickshell edition: put FaradayOS branding over the Ryoku desktop.

Ryoku (https://ryoku.dev, GPL-3.0) provides the shell. This script changes only
what a person sees: names in menus, settings and messages, logos, the default
wallpaper, the bar mark and fastfetch. Commands, file names, package names and
QML module names stay "ryoku", so Ryoku updates and tools keep working.

Runs at ISO build (kickstart %post) and after every dnf transaction
(zz-faraday-rebrand-ryoku.actions), because Ryoku updates put their files back.
Safe to run any number of times.

  rebrand-ryoku.py          apply
  rebrand-ryoku.py --check  list user-visible "Ryoku" left over; exit 1 if any
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys

NAME = "FaradayOS"
BRAND = "/usr/share/faraday/brand"
MARK_PNG = BRAND + "/mark.png"
MARK_SVG = BRAND + "/mark.svg"
WORDMARK = BRAND + "/wordmark.png"
WALL = BRAND + "/wall.webp"

SHARE = "/usr/share/ryoku"
QML_ROOTS = [SHARE + "/config", SHARE + "/lockscreen", SHARE + "/reload-cover",
             SHARE + "/nomarchy"] + glob.glob("/usr/lib*/qt6/qml/Ryoku")
CATALOG_DIRS = [SHARE + "/i18n"] + glob.glob("/home/*/.local/share/ryoku/i18n")

# "Ryoku" as a word (also with a suffix: Ryoku's, Finnish Ryokun), but never a
# QML module path such as Ryoku.Ui, an identifier (RyokuPower) or a URL/owner
# (github.com/Ryoku-dev; ryoku.dev is lower case and never matches).
WORD = re.compile(r"(?<![A-Za-z0-9_@/.-])Ryoku(?![.][A-Za-z]|[A-Z0-9_]|-dev)")

# String literals that are not shown as text: notification app ids, a virtual
# camera/mic/hotspot name other code matches on, log messages, paths.
SKIP_LITERAL = re.compile(r"notify-send|app-name|Phone|Hotspot|Equalizer|did not load|"
                          r"://|~/|/usr/|Ryoku[.][A-Za-z]|Ryoku_|^Ryoku$")

changed = []


def write_if_changed(path, new, old):
    if new != old:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
        changed.append(path)


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (OSError, UnicodeDecodeError):
        return None


def brand_text(s):
    return WORD.sub(NAME, s)


# 1. Translation catalogs: change the shown text (values), keep the lookup keys.
def catalogs():
    for d in CATALOG_DIRS:
        for path in glob.glob(d + "/*.json"):
            if path.endswith("/langs.json"):
                continue
            old = read(path)
            if old is None or "Ryoku" not in old:
                continue
            try:
                data = json.loads(old)
            except ValueError:
                continue
            if not isinstance(data, dict):
                continue
            new = {k: brand_text(v) if isinstance(v, str) else v for k, v in data.items()}
            if new != data:
                write_if_changed(path, json.dumps(new, ensure_ascii=False, indent=2) + "\n", old)


# 2. QML/JS: user-visible string literals that are not looked up in a catalog,
#    and the brand defaults (name and bar mark).
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def qml_literal(m, text):
    s = m.group(1)
    before = text[max(0, m.start() - 9):m.start()]
    if s == "Ryoku" and before.endswith(("? ", "author: ")):
        return '"%s"' % NAME       # shown values: style ? "Ryoku" : ..., author: "Ryoku"
    if "Ryoku" not in s or SKIP_LITERAL.search(s):
        return m.group(0)
    if before.endswith("tr(") or before.endswith(".t("):
        return m.group(0)          # catalog key: translated through step 1
    return '"' + brand_text(s) + '"'


def qml():
    for root in QML_ROOTS:
        for dirpath, _, files in os.walk(root):
            for fn in files:
                if not fn.endswith((".qml", ".js", ".mjs")) or ".test." in fn:
                    continue
                path = os.path.join(dirpath, fn)
                old = read(path)
                if old is None or ("Ryoku" not in old and "markImage" not in old):
                    continue
                new = LITERAL.sub(lambda m: qml_literal(m, old), old)
                new = re.sub(r'(property string name:\s*)"Ryoku"', r'\1"%s"' % NAME, new)
                new = re.sub(r'(property string markImage:\s*)""', r'\1"%s"' % MARK_PNG, new)
                write_if_changed(path, new, old)


# 3. Launcher entries.
def desktop_files():
    for path in glob.glob("/usr/share/applications/*.desktop"):
        old = read(path)
        if old is None or "Ryoku" not in old:
            continue
        new = re.sub(r"^((?:Name|GenericName|Comment|Keywords)(?:\[[^]]*\])?=.*)$",
                     lambda m: brand_text(m.group(1)), old, flags=re.M)
        write_if_changed(path, new, old)


# 4. Logos: any Ryoku logo file gets the FaradayOS one, same file name.
def same(a, b):
    try:
        with open(a, "rb") as x, open(b, "rb") as y:
            return x.read() == y.read()
    except OSError:
        return False


def put(src, dst):
    if os.path.exists(src) and not same(src, dst):
        shutil.copyfile(src, dst)
        changed.append(dst)


def logos():
    roots = [SHARE] + glob.glob("/usr/lib*/qt6/qml/Ryoku")
    for root in roots:
        for dirpath, _, files in os.walk(root):
            for fn in files:
                path = os.path.join(dirpath, fn)
                if fn in ("logo-mark.png", "logo-mark-v2.png", "fastfetch-emblem.png") or \
                        (fn == "icon.png" and dirpath.endswith("/brand")):
                    put(MARK_PNG, path)
                elif fn == "logo.png" and "reload-cover" in dirpath:
                    put(WORDMARK, path)
                elif fn.endswith(".svg") and fn.startswith("logo"):
                    if "Ryoku logo" in (read(path) or "") or fn == "logo-mark.svg":
                        put(MARK_SVG, path)
    # app icons: Ryoku installs its logo as the icon of its own apps (Hub and others)
    for path in glob.glob("/usr/share/icons/hicolor/*/apps/*.svg"):
        head = (read(path) or "")[:600]
        if "Ryoku logo" in head or os.path.basename(path) == "ryoku-hub.svg":
            put(MARK_SVG, path)
    if os.path.isdir("/usr/share/icons/hicolor"):
        subprocess.run(["gtk-update-icon-cache", "-qtf", "/usr/share/icons/hicolor"],
                       stderr=subprocess.DEVNULL, check=False)


# 5. Looks ("rices"): FaradayOS wallpaper on the default look, FaradayOS name and
#    mark in every look's brand layer, fastfetch text and logo.
def rices():
    put(WALL, SHARE + "/rices/default/wall.webp")
    for path in glob.glob(SHARE + "/rices/*/rice.json"):
        old = read(path)
        try:
            data = json.loads(old)
        except (TypeError, ValueError):
            continue
        brand = (data.get("layers") or {}).get("brand")
        if isinstance(brand, dict):
            if brand.get("name") in (None, "", "Ryoku"):
                brand["name"] = NAME
            if not brand.get("markImage"):
                brand["markImage"] = MARK_PNG
            write_if_changed(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n", old)
    # brand.json files: Ryoku's defaults only, a person's own choice is kept
    for path in glob.glob(SHARE + "/config/ryoku/brand.json") + glob.glob("/home/*/.config/ryoku/brand.json"):
        old = read(path)
        try:
            data = json.loads(old)
        except (TypeError, ValueError):
            continue
        if data.get("name") in (None, "", "Ryoku") and not data.get("markImage"):
            data["name"] = NAME
            data["markImage"] = MARK_PNG
            write_if_changed(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n", old)
    ff = glob.glob(SHARE + "/rices/*/fastfetch.jsonc") + glob.glob(SHARE + "/config/fastfetch/*.jsonc")
    for path in ff:
        old = read(path)
        if old is None:
            continue
        new = re.sub(r'"source":\s*"[^"]*fastfetch-emblem\.png"', '"source": "%s"' % MARK_PNG, old)
        # "RYOKU · 力 · a hand-built ... desktop" -> "FARADAYOS · a hand-built ... desktop"
        new = re.sub(r"RYOKU (\\u00b7|·) (\\u529b|力) (\\u00b7|·) ", r"FARADAYOS \1 ", new)
        new = re.sub(r"Ryoku \$\(ryoku version --pretty[^)]*\)",
                     r"FaradayOS v$(cat /usr/share/faraday/version 2>/dev/null)", new)
        write_if_changed(path, new, old)


# 6. Boot: keep the FaradayOS splash and a GRUB menu with only FaradayOS entries.
#    ryoku-desktop's update script re-themes both; undo that.
def boot():
    stamp = "/var/lib/ryoku/plymouth-theme.stamp"
    if not os.path.exists(stamp):
        # ryoku-plymouth-apply leaves a theme alone once this exists and the
        # default theme is not "ryoku" (the FaradayOS one is set elsewhere).
        os.makedirs(os.path.dirname(stamp), exist_ok=True)
        with open(stamp, "w") as f:
            f.write("faradayos\n")
    grub_default = read("/etc/default/grub") or ""
    if "themes/ryoku/" in grub_default and os.access("/usr/bin/ryoku-grub-menu", os.X_OK):
        subprocess.run(["/usr/bin/ryoku-grub-menu", "purge"], check=False)
        if os.path.exists("/boot/grub2/grub.cfg") and not os.environ.get("FARADAY_NO_MKCONFIG"):
            subprocess.run(["grub2-mkconfig", "-o", "/boot/grub2/grub.cfg"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        changed.append("/etc/default/grub")
    snap = "/etc/grub.d/15_ryoku_snapshots"     # a "Ryoku snapshots" GRUB submenu
    if os.path.exists(snap) and os.stat(snap).st_mode & 0o111:
        os.chmod(snap, 0o644)
        changed.append(snap)


# --check: what a person could still read as "Ryoku".
def check():
    left = []
    for d in CATALOG_DIRS[:1]:
        for path in glob.glob(d + "/*.json"):
            if path.endswith("/langs.json"):
                continue
            try:
                data = json.load(open(path, encoding="utf-8"))
            except (OSError, ValueError):
                continue
            n = sum(1 for v in data.values() if isinstance(v, str) and WORD.search(v))
            if n:
                left.append("%s: %d translated strings" % (path, n))
    for path in glob.glob("/usr/share/applications/*.desktop"):
        for line in (read(path) or "").splitlines():
            if re.match(r"(Name|GenericName|Comment)(\[[^]]*\])?=", line) and WORD.search(line):
                left.append("%s: %s" % (path, line))
    for path in glob.glob(SHARE + "/rices/*/rice.json"):
        brand = ((json.load(open(path)).get("layers") or {}).get("brand")) or {}
        if brand.get("name") == "Ryoku":
            left.append("%s: brand name" % path)
    for root in QML_ROOTS:
        for dirpath, _, files in os.walk(root):
            for fn in files:
                if fn.endswith(".qml"):
                    t = read(os.path.join(dirpath, fn)) or ""
                    if re.search(r'property string name:\s*"Ryoku"', t):
                        left.append("%s: default brand name" % os.path.join(dirpath, fn))
    for line in left:
        print("still Ryoku:", line)
    return 1 if left else 0


def main():
    if "--check" in sys.argv:
        sys.exit(check())
    if not os.path.isdir(SHARE):
        return                      # Ryoku is not installed: nothing to do
    for step in (catalogs, qml, desktop_files, logos, rices, boot):
        try:
            step()
        except Exception as e:      # one failed step must not stop the others or dnf
            print("rebrand-ryoku: %s: %s" % (step.__name__, e), file=sys.stderr)
    if "--verbose" in sys.argv:
        print("\n".join(changed))
    print("rebrand-ryoku: %d files updated" % len(changed))


main()
