# FaradayOS: signing in on TTY2 starts the FaradayOS (Hyprland) desktop, on TTY4 KDE Plasma (see /etc/profile.d/faraday-tty-session.sh)
if status is-login; and test -z "$WAYLAND_DISPLAY$DISPLAY$SSH_TTY"; and test (id -u) -ne 0
    switch (tty 2>/dev/null)
        case /dev/tty2
            exec /usr/libexec/faraday/tty-session
        case /dev/tty4
            # only where KDE Plasma is installed (performance edition)
            if test -x /usr/bin/startplasma-wayland
                exec /usr/libexec/faraday/tty-session
            end
    end
end
