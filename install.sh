#!/usr/bin/env bash
# Install the unofficial Lenovo GNOME theme. Run ./install.sh -h for options.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$REPO/lib/common.sh"

usage() {
    cat <<EOF
Usage: ./install.sh [options]

User-level components (no sudo), all installed by default:
  terminal   Ghostty theme, tmux colours, btop theme
  gtk        GTK3 / GTK4 (libadwaita) colour overrides
  shell      GNOME Shell extension: top bar, popups, lock screen
  desktop    Brand font, red accent, dark mode, wallpaper (--wallpaper)
  dock       Ubuntu Dock / Dash to Dock colours

Options:
  --only LIST          Comma-separated subset of the components above
  --wallpaper PATH     Image for the desktop, login screen and boot splash (none is bundled)
  --font NAME          Font family (default: GothamSSm, then Gotham, then Montserrat)
  --font-size N        Interface font size (default: 10)
  --install-deps       apt install fonts-montserrat if no brand font is found
  --gdm                Also theme the login screen (Ubuntu/Debian with Yaru; uses sudo)
  --plymouth           Also theme the boot splash (uses sudo, rebuilds the initramfs)
  --early-kms MODULE   With --plymouth: load this GPU driver (e.g. amdgpu, i915) in the
                       initramfs so the splash appears early; only needed on some machines
  -h, --help           Show this help
EOF
}

ONLY="terminal,gtk,shell,desktop,dock"
WALLPAPER="" FONT="" FONT_SIZE=10 INSTALL_DEPS=0 DO_GDM=0 DO_PLYMOUTH=0 EARLY_KMS=""
while [ $# -gt 0 ]; do
    case $1 in
        --only) ONLY=$2; shift ;;
        --wallpaper) WALLPAPER=$(realpath "$2"); shift ;;
        --font) FONT=$2; shift ;;
        --font-size) FONT_SIZE=$2; shift ;;
        --install-deps) INSTALL_DEPS=1 ;;
        --gdm) DO_GDM=1 ;;
        --plymouth) DO_PLYMOUTH=1 ;;
        --early-kms) EARLY_KMS=$2; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
done
wants() { [[ ",$ONLY," == *",$1,"* ]]; }

[ "$(id -u)" -ne 0 ] || die "run as your normal user; it asks for sudo when needed"
[ -z "$WALLPAPER" ] || [ -r "$WALLPAPER" ] || die "can't read wallpaper: $WALLPAPER"
[ -z "$EARLY_KMS" ] || [ "$DO_PLYMOUTH" = 1 ] || die "--early-kms only applies with --plymouth"
mkdir -p "$STATE_DIR" "$DATA_DIR"

# ---- font -------------------------------------------------------------------
if wants desktop || [ "$DO_GDM" = 1 ] || [ "$DO_PLYMOUTH" = 1 ]; then
    [ -n "$FONT" ] || FONT=$(pick_font)
    if [ -z "$FONT" ] && [ "$INSTALL_DEPS" = 1 ] && have apt-get; then
        info "Installing fonts-montserrat"
        sudo apt-get install -y -q fonts-montserrat
        FONT=$(pick_font)
    fi
    if [ -z "$FONT" ]; then
        warn "no brand font found; keeping current fonts (install Gotham, or use --install-deps for Montserrat)"
    else
        info "Font: $FONT"
    fi
fi

# ---- terminal ---------------------------------------------------------------
if wants terminal; then
    info "Terminal: Ghostty, tmux, btop"
    install -D -m 644 "$REPO/terminal/ghostty/Lenovo" "$CONFIG_HOME/ghostty/themes/Lenovo"
    if have ghostty || [ -d "$CONFIG_HOME/ghostty" ]; then
        ghostty_cfg=$CONFIG_HOME/ghostty/config.ghostty
        [ -f "$ghostty_cfg" ] || [ ! -f "$CONFIG_HOME/ghostty/config" ] || ghostty_cfg=$CONFIG_HOME/ghostty/config
        # Appended last so it overrides any earlier theme line
        add_block "$ghostty_cfg" BOTTOM "# " "" "theme = Lenovo"
    fi

    install -D -m 644 "$REPO/terminal/tmux/lenovo.tmux.conf" "$DATA_DIR/tmux/lenovo.tmux.conf"
    if have tmux; then
        tmux_cfg=$HOME/.tmux.conf
        [ -f "$tmux_cfg" ] || [ ! -f "$CONFIG_HOME/tmux/tmux.conf" ] || tmux_cfg=$CONFIG_HOME/tmux/tmux.conf
        add_block "$tmux_cfg" BOTTOM "# " "" "source-file \"$DATA_DIR/tmux/lenovo.tmux.conf\""
        tmux source-file "$tmux_cfg" 2>/dev/null || true
    fi

    install -D -m 644 "$REPO/terminal/btop/lenovo.theme" "$CONFIG_HOME/btop/themes/lenovo.theme"
    btop_cfg=$CONFIG_HOME/btop/btop.conf
    if [ -f "$btop_cfg" ]; then
        save_value btop_color_theme "$(sed -n 's/^color_theme = //p' "$btop_cfg")"
        if grep -q '^color_theme = ' "$btop_cfg"; then
            sed -i 's/^color_theme = .*/color_theme = "lenovo"/' "$btop_cfg"
        else
            echo 'color_theme = "lenovo"' >> "$btop_cfg"
        fi
        pgrep -x btop >/dev/null && warn "btop is running: quit and restart it to load the theme"
    fi
fi

# ---- gtk --------------------------------------------------------------------
if wants gtk; then
    info "GTK: colour overrides for GTK3 and GTK4 apps"
    for v in 3.0 4.0; do
        install -D -m 644 "$REPO/gtk/gtk-$v.css" "$CONFIG_HOME/gtk-$v/$NAME.css"
        # @import must precede other rules, so the block goes at the top of gtk.css
        add_block "$CONFIG_HOME/gtk-$v/gtk.css" TOP "/* " " */" "@import url(\"$NAME.css\");"
    done
fi

# ---- desktop ----------------------------------------------------------------
if wants desktop; then
    info "Desktop: dark mode, red accent, fonts${WALLPAPER:+, wallpaper}"
    gset org.gnome.desktop.interface color-scheme "'prefer-dark'"
    gset org.gnome.desktop.interface accent-color "'red'"
    if [ -d /usr/share/themes/Yaru-red-dark ]; then
        gset org.gnome.desktop.interface gtk-theme "'Yaru-red-dark'"
        gset org.gnome.desktop.interface icon-theme "'Yaru-red-dark'"
    fi
    if [ -n "$FONT" ]; then
        gset org.gnome.desktop.interface font-name "'$FONT $FONT_SIZE'"
        gset org.gnome.desktop.interface document-font-name "'$FONT $FONT_SIZE'"
        gset org.gnome.desktop.wm.preferences titlebar-font "'$FONT Bold $FONT_SIZE'"
    fi
    if [ -n "$WALLPAPER" ]; then
        dest=$DATA_DIR/backgrounds/$(basename "$WALLPAPER")
        install -D -m 644 "$WALLPAPER" "$dest"
        gset org.gnome.desktop.background picture-uri "'file://$dest'"
        gset org.gnome.desktop.background picture-uri-dark "'file://$dest'"
        gset org.gnome.desktop.background picture-options "'zoom'"
    fi
fi

# ---- dock -------------------------------------------------------------------
if wants dock; then
    if have_schema org.gnome.shell.extensions.dash-to-dock; then
        info "Dock: dark background, red running indicators"
        s=org.gnome.shell.extensions.dash-to-dock
        gset $s custom-background-color true
        gset $s background-color "'#1C1A1C'"
        gset $s transparency-mode "'FIXED'"
        gset $s background-opacity 0.95
        gset $s custom-theme-customize-running-dots true
        gset $s custom-theme-running-dots-color "'#E1251B'"
        gset $s custom-theme-running-dots-border-color "'#E1251B'"
    else
        info "Dock: no Ubuntu Dock / Dash to Dock, skipping"
    fi
fi

# ---- shell ------------------------------------------------------------------
if wants shell; then
    info "Shell: top bar, popups and lock screen extension"
    shell_major=$(gnome-shell --version 2>/dev/null | grep -o '[0-9]\+' | head -1 || true)
    if ! grep -q "\"${shell_major:-none}\"" "$REPO/shell/$EXT_UUID/metadata.json"; then
        warn "GNOME Shell ${shell_major:-not found} is untested; the extension targets the versions in metadata.json"
    fi
    ext_dir=${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$EXT_UUID
    mkdir -p "$ext_dir"
    cp "$REPO/shell/$EXT_UUID/"* "$ext_dir/"
    gset org.gnome.shell disable-user-extensions false
    if gnome-extensions enable "$EXT_UUID" 2>/dev/null; then
        # Re-enable so an updated stylesheet is reloaded
        gnome-extensions disable "$EXT_UUID" && gnome-extensions enable "$EXT_UUID"
    else
        python3 - "$EXT_UUID" <<'EOF'
import ast, subprocess, sys
uuid = sys.argv[1]
cur = subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
                     capture_output=True, text=True, check=True).stdout.strip()
exts = ast.literal_eval(cur.removeprefix("@as ")) if cur else []
if uuid not in exts:
    exts.append(uuid)
    subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(exts)], check=True)
EOF
        warn "log out and back in to load the shell extension (GNOME only discovers new extensions at login)"
    fi
fi

# ---- system: login screen and boot splash -----------------------------------
FONT_FILES=""
[ -z "$FONT" ] || FONT_FILES=$(font_files "$FONT")
if [ "$DO_GDM" = 1 ]; then
    info "Login screen (sudo)"
    sudo env FONT="$FONT" FONT_SIZE="$FONT_SIZE" FONT_FILES="$FONT_FILES" WALLPAPER="$WALLPAPER" \
        "$REPO/gdm/gdm.sh" install
fi
if [ "$DO_PLYMOUTH" = 1 ]; then
    info "Boot splash (sudo)"
    sudo env FONT="$FONT" FONT_FILES="$FONT_FILES" WALLPAPER="$WALLPAPER" EARLY_KMS="$EARLY_KMS" \
        "$REPO/plymouth/plymouth.sh" install
fi

info "Done. Restart open apps to pick up GTK changes. Undo with ./uninstall.sh"
