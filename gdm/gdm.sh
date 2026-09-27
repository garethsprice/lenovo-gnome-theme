#!/usr/bin/env bash
# Login screen (GDM) theme for Ubuntu/Debian with Yaru. Run as root via install.sh / uninstall.sh.
#   gdm.sh install    Build Yaru's shell theme + lenovo-gdm.css and select it for GDM
#   gdm.sh uninstall  Return GDM to the distribution default
# Env for install: FONT, FONT_SIZE, FONT_FILES (space-separated), WALLPAPER (all optional).
# Re-run install after Yaru / GNOME Shell upgrades so the base stylesheet stays current.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/../lib/common.sh
. "$HERE/../lib/common.sh"

YARU=/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
LINK=/usr/share/gnome-shell/gdm-theme.gresource
DEST=/usr/local/share/gnome-shell/theme/$NAME/gnome-shell-theme.gresource
BG_DIR=/usr/share/backgrounds/$NAME
FONT_DIR=/usr/local/share/fonts/$NAME
GREETER=/etc/gdm3/greeter.dconf-defaults

[ "$(id -u)" -eq 0 ] || die "gdm.sh must run as root"
if [ ! -f "$YARU" ] || [ ! -f "$GREETER" ] || ! have update-alternatives; then
    die "login screen theming needs Ubuntu/Debian with GDM and the Yaru shell theme"
fi

regen_greeter() { dpkg-reconfigure gdm3 >/dev/null 2>&1 || warn "dpkg-reconfigure gdm3 failed; settings apply after reboot"; }

install_gdm() {
    have glib-compile-resources || { info "Installing libglib2.0-dev-bin (glib-compile-resources)"; apt-get install -y -q libglib2.0-dev-bin; }
    local work bg r
    work=$(mktemp -d); trap 'rm -rf "$work"' RETURN

    # Background rule: wallpaper if given, else plain dark grey
    if [ -n "${WALLPAPER:-}" ]; then
        rm -rf "$BG_DIR"
        install -D -m 644 "$WALLPAPER" "$BG_DIR/login.${WALLPAPER##*.}"
        bg="background: #1C1A1C url(\"file://$BG_DIR/login.${WALLPAPER##*.}\"); background-size: cover; background-position: center;"
    else
        bg="background-color: #1C1A1C;"
    fi

    # Unpack Yaru, append our overrides to the GDM stylesheet, repack
    for r in $(gresource list "$YARU"); do
        mkdir -p "$work/src$(dirname "$r")"
        gresource extract "$YARU" "$r" > "$work/src$r"
    done
    sed "s|@BACKGROUND@|$bg|" "$HERE/lenovo-gdm.css" >> "$work/src/org/gnome/shell/theme/gdm.css"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?><gresources><gresource prefix="/">'
        for r in $(gresource list "$YARU"); do echo "  <file>${r#/}</file>"; done
        echo '</gresource></gresources>'
    } > "$work/theme.xml"
    glib-compile-resources --sourcedir="$work/src" --target="$work/theme.gresource" "$work/theme.xml"
    gresource list "$work/theme.gresource" | grep -q '/gdm.css$' || die "built theme has no gdm.css; not installing"
    install -D -m 644 "$work/theme.gresource" "$DEST"

    update-alternatives --install "$LINK" gdm-theme.gresource "$DEST" 0
    update-alternatives --set gdm-theme.gresource "$DEST"

    # Fonts that live outside /usr (e.g. a user-installed Gotham) must be readable by the gdm user
    local f
    for f in ${FONT_FILES:-}; do
        case $f in /usr/*) ;; *) install -D -m 644 "$f" "$FONT_DIR/$(basename "$f")" ;; esac
    done
    [ ! -d "$FONT_DIR" ] || fc-cache -f "$FONT_DIR"

    # Greeter settings: marked block right after the [org/gnome/desktop/interface] header
    local block
    block="# $MARK_BEGIN
accent-color='red'
color-scheme='prefer-dark'"
    [ -z "${FONT:-}" ] || block="$block
font-name='$FONT ${FONT_SIZE:-10}'"
    block="$block
# $MARK_END"
    remove_block "$GREETER"
    grep -q '^\[org/gnome/desktop/interface\]' "$GREETER" || printf '\n[org/gnome/desktop/interface]\n' >> "$GREETER"
    python3 - "$GREETER" "$block" <<'EOF'
import sys
path, block = sys.argv[1], sys.argv[2]
s = open(path).read()
hdr = "[org/gnome/desktop/interface]\n"
open(path, "w").write(s.replace(hdr, hdr + block + "\n", 1))
EOF
    regen_greeter
    info "Login screen themed; it shows at next logout or reboot"
}

uninstall_gdm() {
    update-alternatives --remove gdm-theme.gresource "$DEST" 2>/dev/null || true
    rm -rf "$(dirname "$DEST")" "$BG_DIR"
    remove_block "$GREETER"
    regen_greeter
    # Shared with the boot splash: only remove when that is gone too
    [ -e /usr/share/plymouth/themes/"$NAME" ] || rm -rf "$FONT_DIR"
    info "Login screen back to the distribution default"
}

case ${1:-} in
    install) install_gdm ;;
    uninstall) uninstall_gdm ;;
    *) die "usage: gdm.sh install|uninstall" ;;
esac
