#!/bin/bash

_notify(){ command -v notify-send >/dev/null && notify-send -a "FaradayOS" -i /usr/share/faraday/logo.png "FaradayOS installer" "$1" 2>/dev/null || true; }

# Run once at a time: this script reinstalls the installer before starting it, so a second launch
# would replace the installer's plugin files while the first one is loading them, making most
# modules fail with "Calamares Initialization Failed".
exec 9>"/tmp/faradayos-installer.lock"
if ! flock -n 9 || pgrep -x calamares >/dev/null; then
    _notify "The installer is already starting or open."
    exit 0
fi

# At boot the live system sets up its package-signing keys (pacman-init); this script resets
# them, so wait for that to finish first. Then wait for any other package operation to finish.
_wait_for_system(){
    local i=0
    while [ "$(systemctl show -p ActiveState --value pacman-init.service 2>/dev/null)" = "activating" ] && [ $i -lt 300 ]; do
        sleep 2; i=$((i + 2))
    done
    local lck=/var/lib/pacman/db.lck; i=0
    while [ -e $lck ] && [ $i -lt 600 ]; do
        if sudo fuser -s $lck 2>/dev/null || pgrep -x 'pacman|pamac|pamac-daemon|octopi|packagekitd' >/dev/null; then
            sleep 2; i=$((i + 2))
        else
            sudo rm -f $lck   # left behind by an interrupted operation
        fi
    done
}

main() {
    _notify "Preparing the installer. This can take a minute or two."
    _wait_for_system
    # Remove current keyring first, to complete initiate it
    sudo rm -rf /etc/pacman.d/gnupg
    # We are using this, because archlinux is signing the keyring often with a newly created keyring
    # This results into a failed installation for the user.
    # Installing archlinux-keyring fails due not being correctly signed
    # Mitigate this by installing the latest archlinux-keyring on the ISO, before starting the installation
    # The issue could also happen, when the installation does rank the mirrors and then a "faulty" mirror gets used
    sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
    # Also populate the keys, before starting the Installer, to avoid above issue
    sudo pacman-key --init
    sudo pacman-key --populate archlinux cachyos
    # Also use timedatectl to sync the time with the hardware clock
    # There has been a bunch of reports, that the keyring was created in the future
    # Syncing appears to fix it
    timedatectl set-ntp true

    local progname="$(basename "$0")"
    local log="/home/liveuser/cachy-install.log"
    local mode="offline"  # FaradayOS: copy the live system so all FaradayOS packages and settings are installed

    local SYSTEM=""

    if [ -d /sys/firmware/efi ]; then
        SYSTEM="UEFI SYSTEM"
    else
        SYSTEM="BIOS/MBR SYSTEM"
    fi

    local ISO_VERSION="$(cat /etc/version-tag)"
    echo "USING ISO VERSION: ${ISO_VERSION}"

    sudo pacman -Sy --noconfirm cachyos-calamares-next
    sudo /usr/local/bin/faraday-calamares-compat >> "$log" 2>&1 || true

    # Get Hardware Informations
    inxi -F > "$log"

    cat <<EOF >> "$log"
########## $log by $progname
########## Started (UTC): $(date -u "+%x %X")
########## ISO version: $ISO_VERSION
########## System: $SYSTEM
EOF

    sudo cp "/usr/share/calamares/settings_${mode}.conf" /etc/calamares/settings.conf
    # FaradayOS installer overrides, applied after the installer update above so they always win
    sudo cp /usr/share/faraday/calamares/*.conf /usr/share/faraday/calamares/*.yaml /etc/calamares/modules/
    sudo sed -i 's/^branding:.*/branding: faraday/' /etc/calamares/settings.conf
    grep -q 'netinstall-faraday.conf' /etc/calamares/settings.conf || \
      sudo sed -i 's/^instances:$/instances:\n- id:       faraday\n  module:   netinstall\n  config:   netinstall-faraday.conf/' /etc/calamares/settings.conf
    grep -q 'netinstall@faraday' /etc/calamares/settings.conf || \
      sudo sed -i '0,/^  - users$/s//  - users\n  - netinstall@faraday/' /etc/calamares/settings.conf
    grep -q 'shellprocess-faraday-kernels.conf' /etc/calamares/settings.conf || \
      sudo sed -i 's/^instances:$/instances:\n- id:       faraday_kernels\n  module:   shellprocess\n  config:   shellprocess-faraday-kernels.conf/' /etc/calamares/settings.conf
    grep -q 'shellprocess@faraday_kernels' /etc/calamares/settings.conf || \
      sudo sed -i '0,/^  - initcpio$/s//  - shellprocess@faraday_kernels\n  - initcpio/' /etc/calamares/settings.conf
    exec pkexec-wrapper calamares -D6 >> $log
}

main "$@"
