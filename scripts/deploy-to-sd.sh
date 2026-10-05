#!/bin/bash
# Install the ESCA Home bundle onto the Pi's SD card and unlock the root
# account. Use this when ssh is not an option -- the image flashed on that card
# was built before the login image features were added, so every account in it
# is locked (root:* in /etc/shadow) and dropbear rejects an empty password.
#
# Run on the development host, with the card in the reader and the Pi off:
#
#     sudo bash scripts/deploy-to-sd.sh [/dev/mmcblk0]

set -euo pipefail

DEV="${1:-/dev/mmcblk0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="$(cd "$HERE/.." && pwd)/build/linux/arm64/release/bundle"
LAUNCHER="$HERE/run-esca-home.sh"
MNT="$(mktemp -d)"

if [ "$(id -u)" -ne 0 ]; then
    echo "needs root: sudo bash $0 $DEV" >&2
    exit 1
fi

[ -d "$BUNDLE" ] || { echo "no bundle at $BUNDLE -- run flutter build linux --release first" >&2; exit 1; }

# The wic image lays the card out as p1=boot (vfat), p2=root (ext4).
ROOTPART="${DEV}p2"
[ -b "$ROOTPART" ] || ROOTPART="${DEV}2"
[ -b "$ROOTPART" ] || { echo "no second partition on $DEV -- is this the right device?" >&2; exit 1; }

echo "== $DEV layout"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEV"
echo
read -r -p "Install into $ROOTPART? [y/N] " answer
[ "$answer" = "y" ] || { echo "aborted"; exit 1; }

mount "$ROOTPART" "$MNT"
trap 'umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true' EXIT

# Make sure this is the Yocto rootfs and not the boot partition.
[ -f "$MNT/etc/shadow" ] || { echo "$ROOTPART does not look like the rootfs" >&2; exit 1; }

echo
echo "== libraries the app needs and the image does not have"
missing=0
for lib in $(ldd "$BUNDLE/esca_home" | awk '{print $1}' | grep -E '^lib'); do
    # Skip the engine's own library: it ships inside the bundle.
    case "$lib" in libflutter_linux_gtk.so) continue ;; esac
    if ! find "$MNT/usr/lib" "$MNT/lib" -maxdepth 2 -name "$lib" 2>/dev/null | grep -q .; then
        echo "  MISSING: $lib"
        missing=$((missing + 1))
    fi
done
[ "$missing" -eq 0 ] && echo "  (none -- every library is present)"
echo

echo "== installing the bundle to /home/root/esca-home"
install -d "$MNT/home/root"
rm -rf "$MNT/home/root/esca-home"
cp -a "$BUNDLE" "$MNT/home/root/esca-home"
install -m 0755 "$LAUNCHER" "$MNT/home/root/run-esca-home.sh"

echo "== root account"
cp -a "$MNT/etc/shadow" "$MNT/etc/shadow.backup"
# The image locks every account (root:*), so there is no password that works --
# that is what "Permission denied (publickey,password)" over ssh means. An empty
# password gets you in on the console but not past dropbear, which refuses one,
# so set a real one here if ssh is wanted.
read -r -s -p "New root password (empty = console login only): " pw
echo
if [ -n "$pw" ]; then
    hash="$(openssl passwd -6 "$pw")"
    # The hash contains / and $, so use a different delimiter and escape nothing.
    awk -v h="$hash" 'BEGIN{FS=OFS=":"} $1=="root"{$2=h} {print}' \
        "$MNT/etc/shadow" > "$MNT/etc/shadow.new"
    mv "$MNT/etc/shadow.new" "$MNT/etc/shadow"
    chmod 640 "$MNT/etc/shadow"
    echo "   root password set -- ssh and scp will work"
else
    sed -i 's/^root:[^:]*:/root::/' "$MNT/etc/shadow"
    echo "   root unlocked with an empty password -- console only, not ssh"
fi
cut -d: -f1,2 "$MNT/etc/shadow" | grep '^root:' | cut -c1-30

echo
echo "== done"
echo "Boot the Pi, log in as root on the console (no password), then run:"
echo "    /home/root/run-esca-home.sh"
echo
echo "The original /etc/shadow is kept as /etc/shadow.backup."
echo "If you set a password, ssh root@<ip> works once the board is up, so the"
echo "app can be updated with scp from then on."
if [ "$missing" -gt 0 ]; then
    echo
    echo "$missing library/libraries are missing, so the app will not start until"
    echo "the image ships them. Add them to esca-image and rebuild."
fi
