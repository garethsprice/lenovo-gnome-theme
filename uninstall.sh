#!/usr/bin/env bash
# Undo install.sh: restore saved settings, remove installed files and config blocks.
# The login screen and boot splash are reverted too if they were installed (uses sudo).
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$REPO/lib/common.sh"

[ "$(id -u)" -ne 0 ] || die "run as your normal user; it asks for sudo when needed"

info "Restoring GNOME settings"
gsettings_restore

info "Removing shell extension"
gnome-extensions disable "$EXT_UUID" 2>/dev/null || true
python3 - "$EXT_UUID" <<'EOF'
import ast, subprocess, sys
uuid = sys.argv[1]
cur = subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
                     capture_output=True, text=True).stdout.strip()
exts = ast.literal_eval(cur.removeprefix("@as ")) if cur else []
if uuid in exts:
    exts.remove(uuid)
    subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(exts)], check=True)
EOF
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$EXT_UUID"

info "Removing GTK overrides"
for v in 3.0 4.0; do
    remove_block "$CONFIG_HOME/gtk-$v/gtk.css"
    rm -f "$CONFIG_HOME/gtk-$v/$NAME.css"
    # Drop gtk.css if install.sh created it and it is now empty
    [ -s "$CONFIG_HOME/gtk-$v/gtk.css" ] || rm -f "$CONFIG_HOME/gtk-$v/gtk.css"
done

info "Removing terminal themes"
for f in "$CONFIG_HOME/ghostty/config.ghostty" "$CONFIG_HOME/ghostty/config" \
         "$HOME/.tmux.conf" "$CONFIG_HOME/tmux/tmux.conf"; do
    remove_block "$f"
done
rm -f "$CONFIG_HOME/ghostty/themes/Lenovo" "$CONFIG_HOME/btop/themes/lenovo.theme"
btop_cfg=$CONFIG_HOME/btop/btop.conf
if [ -f "$btop_cfg" ] && grep -q '^color_theme = "lenovo"' "$btop_cfg"; then
    orig=$(get_value btop_color_theme)
    sed -i "s/^color_theme = .*/color_theme = ${orig:-\"Default\"}/" "$btop_cfg"
fi

if [ -e /usr/local/share/gnome-shell/theme/"$NAME" ] ||
   grep -q "$MARK_BEGIN" /etc/gdm3/greeter.dconf-defaults 2>/dev/null; then
    info "Reverting login screen (sudo)"
    sudo "$REPO/gdm/gdm.sh" uninstall
fi
if [ -e /usr/share/plymouth/themes/"$NAME" ]; then
    info "Reverting boot splash (sudo)"
    sudo "$REPO/plymouth/plymouth.sh" uninstall
fi

rm -rf "$DATA_DIR" "$STATE_DIR"
info "Done. Log out and back in to fully unload the shell extension."
