# FaradayOS: signing in on TTY2 starts the FaradayOS (Hyprland) desktop, on TTY4 KDE Plasma (see /etc/profile.d/faraday-tty-session.sh)
if status is-login; and test -z "$WAYLAND_DISPLAY$DISPLAY$SSH_TTY"; and test (id -u) -ne 0
    switch (tty 2>/dev/null)
        case /dev/tty2 /dev/tty4
            exec /usr/libexec/faraday/tty-session
    end
end
