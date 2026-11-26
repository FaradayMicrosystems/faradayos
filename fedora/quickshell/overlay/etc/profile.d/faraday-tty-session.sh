# FaradayOS: signing in on TTY2 starts the FaradayOS (Hyprland) desktop, on TTY4 KDE Plasma.
# Only for a login on the console itself, never inside a desktop, SSH or su.
if [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}${SSH_TTY:-}" ] && [ "$(id -u)" -ne 0 ]; then
  case "$(tty 2>/dev/null)" in
    /dev/tty2|/dev/tty4) exec /usr/libexec/faraday/tty-session ;;
  esac
fi
