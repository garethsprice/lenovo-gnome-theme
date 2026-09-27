#!/usr/bin/env bash
# Build release archives into dist/:
#   <name>-<version>.tar.gz           the full repo (installer + theme files), for GitHub / gnome-look
#   <name>-plymouth-<version>.tar.gz  a self-contained Plymouth theme for gnome-look's Plymouth category
# The Plymouth archive bundles the stock spinner images (GPL-2+), so run this on a system with
# plymouth-theme-spinner installed. No fonts, wallpapers or logos go into either archive.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$REPO/lib/common.sh"

VERSION=$(cat "$REPO/VERSION")
DIST=$REPO/dist
SPINNER=/usr/share/plymouth/themes/spinner
[ -d "$SPINNER" ] || die "needs $SPINNER (apt install plymouth-theme-spinner)"

rm -rf "$DIST"; mkdir -p "$DIST"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# ---- full repo ----------------------------------------------------------------
full=$NAME-$VERSION
if git -C "$REPO" rev-parse --verify -q HEAD >/dev/null && [ -z "$(git -C "$REPO" status --porcelain)" ]; then
    git -C "$REPO" archive --format=tar.gz --prefix="$full/" -o "$DIST/$full.tar.gz" HEAD
else
    warn "uncommitted changes or no commits: archiving the working tree instead of HEAD"
    mkdir -p "$work/$full"
    tar -C "$REPO" --exclude=./.git --exclude=./dist -cf - . | tar -C "$work/$full" -xf -
    tar -C "$work" --owner=0 --group=0 -czf "$DIST/$full.tar.gz" "$full"
fi

# ---- standalone Plymouth theme -------------------------------------------------
ply=$work/$NAME
mkdir -p "$ply"
# Generic font and dark background: no bundled font or wallpaper
sed -e 's|@FONT@|Sans|g' -e 's|@BGCOLOR@|0x1C1A1C|g' "$REPO/plymouth/lenovo.plymouth" > "$ply/$NAME.plymouth"
for f in "$SPINNER"/*.png; do
    case $(basename "$f") in watermark.png|bgrt-fallback.png) continue ;; esac
    cp -L "$f" "$ply/"
done
cat > "$ply/README.md" <<EOF
# $NAME Plymouth theme $VERSION

Unofficial boot splash in the Lenovo brand palette: dark grey background, white spinner,
Signature Red (#E1251B) progress bar. Not affiliated with Lenovo.

## Install

\`\`\`sh
sudo cp -r $NAME /usr/share/plymouth/themes/
# Debian / Ubuntu
sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \\
    /usr/share/plymouth/themes/$NAME/$NAME.plymouth 100
sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/$NAME/$NAME.plymouth
sudo update-initramfs -u
# Fedora / Arch
sudo plymouth-set-default-theme -R $NAME
\`\`\`

Optional: put a \`background.png\` in the theme folder to use it as a full-screen background
(it's scaled to fit), then rebuild the initramfs.

The full theme (GTK, GNOME Shell, login screen, terminal) and an installer that also handles
fonts and early GPU drivers: https://github.com/garethsprice/$NAME
EOF
cat > "$ply/COPYING" <<EOF
$NAME Plymouth theme

$NAME.plymouth: MIT licence, see LICENSE in the full $NAME repository.

The spinner, prompt and keyboard images (*.png) are from Plymouth's "spinner" theme:
  Copyright 2006-2008 Red Hat, Inc.; 2007-2008 Ray Strode; 2003 University of Southern
  California; 2003 Charlie Brej.
  License: GPL-2.0-or-later (https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
  Source: https://gitlab.freedesktop.org/plymouth/plymouth
EOF
tar -C "$work" --owner=0 --group=0 -czf "$DIST/$NAME-plymouth-$VERSION.tar.gz" "$NAME"

info "Built:"
ls -lh "$DIST"
