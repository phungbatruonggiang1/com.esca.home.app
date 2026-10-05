#!/bin/sh
# Start the ESCA Home dashboard inside the image's Weston session. Runs on the
# Pi, not on the development host.
#
# The bundle is a GTK application, so it talks to Weston as an ordinary Wayland
# client. Weston has to be running already -- weston-init starts it at boot.

set -e

APP_DIR="${APP_DIR:-/home/weston/data/esca-home}"

# weston-init runs Weston as root, which puts its socket in /run/user/0.
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
export XDG_RUNTIME_DIR

# Pick whichever socket Weston actually created rather than guessing the name:
# it is wayland-0 on some images and wayland-1 on others.
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
        case "$sock" in *.lock) continue ;; esac
        [ -S "$sock" ] || continue
        WAYLAND_DISPLAY="$(basename "$sock")"
        break
    done
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "no Wayland socket in $XDG_RUNTIME_DIR -- is Weston running?" >&2
    echo "check with: systemctl status weston" >&2
    exit 1
fi
export WAYLAND_DISPLAY

# Force the Wayland backend: GTK tries X11 first and fails on this image.
export GDK_BACKEND=wayland

# A library the image does not ship is the most likely reason the app refuses to
# start, and ldd names it outright, so check before launching.
missing="$(ldd "$APP_DIR/esca_home" 2>/dev/null | grep 'not found' || true)"
if [ -n "$missing" ]; then
    echo "missing libraries -- the image does not ship these:" >&2
    echo "$missing" >&2
    exit 1
fi

echo "running on $WAYLAND_DISPLAY"
exec "$APP_DIR/esca_home"
