#!/usr/bin/env bash
# Boot splash (Plymouth) theme. Run as root via install.sh / uninstall.sh.
#   plymouth.sh install    Install the theme, make it the default, rebuild the initramfs
#   plymouth.sh uninstall  Restore the distribution default splash
# Env for install: FONT, FONT_FILES (space-separated), WALLPAPER, EARLY_KMS (all optional).
# Handles both dracut (Ubuntu 26.04+, Fedora) and initramfs-tools (older Ubuntu/Debian).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/../lib/common.sh
. "$HERE/../lib/common.sh"

THEME_DIR=/usr/share/plymouth/themes/$NAME
THEME_FILE=$THEME_DIR/$NAME.plymouth
SPINNER=/usr/share/plymouth/themes/spinner
FONT_DIR=/usr/local/share/fonts/$NAME
DRACUT_CONF=/etc/dracut.conf.d/90-$NAME.conf
ITOOLS_HOOK=/etc/initramfs-tools/hooks/$NAME
ITOOLS_MODULES=/etc/initramfs-tools/modules

[ "$(id -u)" -eq 0 ] || die "plymouth.sh must run as root"
have plymouthd || die "Plymouth is not installed"

uses_dracut() {
    have dracut || return 1
    # Debian/Ubuntu can have both installed; dpkg says which one is in charge
    if have dpkg; then dpkg -s dracut 2>/dev/null | grep -q '^Status: install ok installed'; else return 0; fi
}

rebuild_initramfs() {
    local initrd
    initrd=/boot/initrd.img-$(uname -r)
    if [ -f "$initrd" ] && [ ! -f "$initrd.$NAME.bak" ]; then
        cp -a "$initrd" "$initrd.$NAME.bak"
        info "Previous initramfs kept at $initrd.$NAME.bak"
    fi
    if have update-initramfs; then update-initramfs -u; else dracut -f; fi
}

install_plymouth() {
    [ -d "$SPINNER" ] || die "needs the stock spinner theme at $SPINNER for its images"
    local font=${FONT:-Sans} bgcolor=0x1C1A1C f
    mkdir -p "$THEME_DIR"
    rm -f "$THEME_DIR/background.png"
    if [ -n "${WALLPAPER:-}" ]; then
        bgcolor=0x000000
        python3 - "$WALLPAPER" "$THEME_DIR/background.png" <<'EOF'
import sys, gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
GdkPixbuf.Pixbuf.new_from_file(sys.argv[1]).savev(sys.argv[2], "png", [], [])
EOF
    fi
    sed -e "s|@FONT@|$font|g" -e "s|@BGCOLOR@|$bgcolor|g" "$HERE/lenovo.plymouth" > "$THEME_FILE"
    # Spinner and prompt images, without the distro watermark and fallback logo
    for f in "$SPINNER"/*.png; do
        case $(basename "$f") in watermark.png|bgrt-fallback.png) continue ;; esac
        install -m 644 "$f" "$THEME_DIR/"
    done

    # Fonts outside /usr need a system copy so the initramfs can include them
    local files=""
    for f in ${FONT_FILES:-}; do
        case $f in
            /usr/*) files="$files $f" ;;
            *) install -D -m 644 "$f" "$FONT_DIR/$(basename "$f")"; files="$files $FONT_DIR/$(basename "$f")" ;;
        esac
    done

    if uses_dracut; then
        {
            echo "# $NAME: fonts for the Plymouth theme${EARLY_KMS:+, early KMS driver}"
            echo "install_items+=\" /etc/fonts/fonts.conf$files \""
            [ -z "${EARLY_KMS:-}" ] || echo "add_drivers+=\" $EARLY_KMS \""
        } > "$DRACUT_CONF"
    else
        cat > "$ITOOLS_HOOK" <<EOF
#!/bin/sh
# $NAME: copy the Plymouth theme's fonts into the initramfs
PREREQ="plymouth"
prereqs() { echo "\$PREREQ"; }
case "\$1" in prereqs) prereqs; exit 0 ;; esac
for f in$files; do
    mkdir -p "\${DESTDIR}\$(dirname "\$f")"
    cp -a "\$f" "\${DESTDIR}\$f"
done
fc-cache -s -y "\${DESTDIR}" > /dev/null 2>&1 || true
EOF
        chmod 755 "$ITOOLS_HOOK"
        remove_block "$ITOOLS_MODULES"
        [ -z "${EARLY_KMS:-}" ] || add_block "$ITOOLS_MODULES" BOTTOM "# " "" "$EARLY_KMS"
    fi

    if update-alternatives --query default.plymouth >/dev/null 2>&1; then
        update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$THEME_FILE" 0
        update-alternatives --set default.plymouth "$THEME_FILE"
    else
        plymouth-set-default-theme "$NAME"
    fi
    rebuild_initramfs
    info "Boot splash installed; it shows on next boot"
}

uninstall_plymouth() {
    if update-alternatives --query default.plymouth >/dev/null 2>&1; then
        update-alternatives --remove default.plymouth "$THEME_FILE" 2>/dev/null || true
    else
        plymouth-set-default-theme --reset || true
    fi
    rm -rf "$THEME_DIR" "$DRACUT_CONF" "$ITOOLS_HOOK"
    remove_block "$ITOOLS_MODULES"
    # Shared with the login screen: only remove when that is gone too
    [ -e /usr/local/share/gnome-shell/theme/"$NAME" ] || rm -rf "$FONT_DIR"
    rebuild_initramfs
    info "Boot splash back to the distribution default"
}

case ${1:-} in
    install) install_plymouth ;;
    uninstall) uninstall_plymouth ;;
    *) die "usage: plymouth.sh install|uninstall" ;;
esac
