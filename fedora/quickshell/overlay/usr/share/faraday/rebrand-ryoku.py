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
# Ryoku's app store, shown as "Ryostore" (the command "ryostore" is lower case).
STORE = re.compile(r"(?<![A-Za-z0-9_@/.-])Ryostore(?![A-Za-z0-9_])")
STORE_NAME = NAME + " Store"
# Upper-case labels ("RYOKU", "RYOKU DEFAULT"). Catalog values only: in QML an
# upper-case "RYOKU" is also an option value code compares against.
WORD_UP = re.compile(r"(?<![A-Za-z0-9_@/.$-])RYOKU(?![A-Za-z0-9_])")

# The first-run tour. Its window title is a catalog string ("Welcome to Ryoku"),
# and Ryoku's niri config floats it by that exact title. Once the title says
# FaradayOS that rule no longer matches and niri tiles the tour into a column
# instead (off-centre, next to empty black space). This rule floats it again.
WELCOME_TITLE = "Welcome to " + NAME
NIRI_MARK = "// faradayos: first-run tour"
NIRI_RULE = NIRI_MARK + """ (managed by /usr/share/faraday/rebrand-ryoku.py)
window-rule {
    match title="^%s$"
    open-floating true
    default-column-width { fixed 1180; }
    default-window-height { fixed 760; }
}
""" % WELCOME_TITLE

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
    return STORE.sub(STORE_NAME, WORD.sub(NAME, s))


def brand_label(s):
    return WORD_UP.sub(NAME.upper(), brand_text(s))


# 1. Translation catalogs: change the shown text (values), keep the lookup keys.
def catalogs():
    for d in CATALOG_DIRS:
        for path in glob.glob(d + "/*.json"):
            if path.endswith("/langs.json"):
                continue
            old = read(path)
            if old is None or ("Ryoku" not in old and "RYOKU" not in old and "Ryostore" not in old):
                continue
            try:
                data = json.loads(old)
            except ValueError:
                continue
            if not isinstance(data, dict):
                continue
            new = {k: brand_label(v) if isinstance(v, str) else v for k, v in data.items()}
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
    if ("Ryoku" not in s and "Ryostore" not in s) or SKIP_LITERAL.search(s):
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
                if old is None or ("Ryoku" not in old and "Ryostore" not in old
                                   and "markImage" not in old and "launcherLogoTextLabel" not in old):
                    continue
                new = LITERAL.sub(lambda m: qml_literal(m, old), old)
                new = re.sub(r'(property string name:\s*)"Ryoku"', r'\1"%s"' % NAME, new)
                new = re.sub(r'(property string markImage:\s*)""', r'\1"%s"' % MARK_PNG, new)
                # QS Bar's launcher button spells the logo id in capitals: "ryoku" -> RYOKU.
                new = re.sub(r'(function launcherLogoTextLabel\(id\) \{\s*return )String\(id\)\.toUpperCase\(\)',
                             r'\1id === "ryoku" ? "%s" : String(id).toUpperCase()' % NAME.upper(), new)
                write_if_changed(path, new, old)


# 3. Launcher entries.
def desktop_files():
    for path in glob.glob("/usr/share/applications/*.desktop"):
        old = read(path)
        if old is None or ("Ryoku" not in old and "Ryostore" not in old):
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


# 6. niri: float the first-run tour under its FaradayOS title. user.kdl is the
#    file niri reads last; Ryoku seeds it once per account from SHARE/config.
def niri_user_files():
    return glob.glob(SHARE + "/config/niri/user.kdl") + glob.glob("/home/*/.config/niri/user.kdl")


def niri():
    for path in niri_user_files():
        old = read(path)
        if old is None or NIRI_MARK in old:
            continue
        write_if_changed(path, old.rstrip("\n") + "\n\n" + NIRI_RULE, old)


# 7. KDE-only helpers that autostart in niri. niri-session starts systemd's
#    xdg-desktop-autostart.target, so /etc/xdg/autostart entries run in niri too.
#    KDE's "Wayland to X11 Video Bridge" (xwaylandvideobridge) has no OnlyShowIn;
#    KWin hides its window, niri cannot, so it shows as an empty black window.
KDE_ONLY_AUTOSTART = ["/etc/xdg/autostart/*xwaylandvideobridge*.desktop"]


def kde_only_files():
    return [p for g in KDE_ONLY_AUTOSTART for p in glob.glob(g)]


def kde_only():
    for path in kde_only_files():
        old = read(path)
        if old is None or re.search(r"^OnlyShowIn=", old, flags=re.M):
            continue
        new = re.sub(r"^\[Desktop Entry\]\n", "[Desktop Entry]\nOnlyShowIn=KDE;\n", old, count=1, flags=re.M)
        write_if_changed(path, new, old)


# 7a. Quiet first sign-in. Ryoku's wallpaper daemon (Ryogami) sends a "Wallpaper changed" notification
#     whenever it applies a wallpaper, also when the first sign-in sets the default one, so a fresh
#     desktop opened with a toast at the top right. Default it off (the seed every new user gets, and
#     users who still have Ryogami's default); a user can turn it on in the wallpaper picker.
RYOGAMI_KEY = ("general", "notifyOnWallpaperChange")


def ryogami_files():
    return [SHARE + "/config/ryoku/ryogami.json"] + glob.glob("/home/*/.config/ryoku/ryogami.json")


def quiet_wallpaper():
    for path in ryogami_files():
        if not os.path.isdir(os.path.dirname(path)):
            continue
        old = read(path)
        try:
            data = json.loads(old) if old else {}
        except ValueError:
            continue
        if not isinstance(data, dict):
            continue
        section = data.setdefault(RYOGAMI_KEY[0], {})
        if not isinstance(section, dict) or RYOGAMI_KEY[1] in section:
            continue                # the user's own choice stays
        section[RYOGAMI_KEY[1]] = False
        write_if_changed(path, json.dumps(data, indent=2) + "\n", old or "")
        if path.startswith("/home/"):
            st = os.stat(os.path.dirname(path))
            os.chown(path, st.st_uid, st.st_gid)


# 7b. Login screen: offer only "FaradayOS" and "KDE Plasma" (faradayos*.desktop, both through
#     /usr/libexec/faraday/desktop-session). The packages' own entries (niri, Hyprland, Plasma,
#     Plasma X11) start the same desktops without FaradayOS's setup, so the login screen hides them.
SESSION_GLOBS = ["/usr/share/wayland-sessions/*.desktop", "/usr/share/xsessions/*.desktop"]


def other_sessions():
    return [p for g in SESSION_GLOBS for p in sorted(glob.glob(g))
            if not os.path.basename(p).startswith("faradayos")]


def login_sessions():
    for path in other_sessions():
        old = read(path)
        if old is None or re.search(r"^NoDisplay=true", old, flags=re.M):
            continue
        new = re.sub(r"^NoDisplay=.*\n", "", old, flags=re.M)
        new = re.sub(r"^\[Desktop Entry\]\n", "[Desktop Entry]\nNoDisplay=true\n", new, count=1, flags=re.M)
        write_if_changed(path, new, old)


# 8. Boot: keep the FaradayOS splash and a GRUB menu with only FaradayOS entries.
#    ryoku-desktop's update script re-themes both; undo that.
# 7c. No "ghost" notification cards: a popup card that outlived its notification stayed at the top
#     right as an empty box with an X (v0.89e-v0.91e). no-ghost-popups.py patches Ryoku's popup list.
GHOST = "/usr/share/faraday/no-ghost-popups.py"


def ghost_popups():
    if os.path.exists(GHOST):
        r = subprocess.run([sys.executable, GHOST], capture_output=True, text=True)
        if r.returncode:
            print("rebrand-ryoku: " + (r.stdout + r.stderr).strip(), file=sys.stderr)


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
            n = sum(1 for v in data.values() if isinstance(v, str) and
                    (WORD.search(v) or WORD_UP.search(v) or STORE.search(v)))
            if n:
                left.append("%s: %d translated strings" % (path, n))
    for path in glob.glob("/usr/share/applications/*.desktop"):
        for line in (read(path) or "").splitlines():
            if re.match(r"(Name|GenericName|Comment)(\[[^]]*\])?=", line) and \
                    (WORD.search(line) or STORE.search(line)):
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
                    if re.search(r'function launcherLogoTextLabel\(id\) \{\s*return String\(id\)', t):
                        left.append("%s: bar launcher label" % os.path.join(dirpath, fn))
    seeds = glob.glob(SHARE + "/config/niri/user.kdl")
    if os.path.isdir(SHARE) and glob.glob(SHARE + "/config/niri/*.kdl") and not seeds:
        left.append(SHARE + "/config/niri/user.kdl: missing, first-run tour would tile")
    for path in seeds:
        if NIRI_MARK not in (read(path) or ""):
            left.append("%s: first-run tour float rule" % path)
    for path in kde_only_files():
        if not re.search(r"^OnlyShowIn=", read(path) or "", flags=re.M):
            left.append("%s: autostarts outside KDE (black window in niri)" % path)
    seed = SHARE + "/config/ryoku/ryogami.json"
    if os.path.isdir(os.path.dirname(seed)):
        try:
            on = json.loads(read(seed) or "{}").get(RYOGAMI_KEY[0], {}).get(RYOGAMI_KEY[1], True)
        except (ValueError, AttributeError):
            on = True
        if on is not False:
            left.append("%s: wallpaper-change notification on (toast at first sign-in)" % seed)
    for path in other_sessions():
        if not re.search(r"^NoDisplay=true", read(path) or "", flags=re.M):
            left.append("%s: shown on the login screen" % path)
    if os.path.exists(GHOST) and subprocess.run([sys.executable, GHOST, "--check"], capture_output=True).returncode:
        left.append("NotificationPopups.qml: ghost-card fix not applied")
    for line in left:
        print("still Ryoku:", line)
    return 1 if left else 0


def main():
    if "--check" in sys.argv:
        sys.exit(check())
    if not os.path.isdir(SHARE):
        return                      # Ryoku is not installed: nothing to do
    for step in (catalogs, qml, desktop_files, logos, rices, niri, kde_only, quiet_wallpaper, login_sessions, ghost_popups, boot):
        try:
            step()
        except Exception as e:      # one failed step must not stop the others or dnf
            print("rebrand-ryoku: %s: %s" % (step.__name__, e), file=sys.stderr)
    if "--verbose" in sys.argv:
        print("\n".join(changed))
    print("rebrand-ryoku: %d files updated" % len(changed))


main()
