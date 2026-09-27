# lenovo-gnome-theme

A dark GNOME desktop theme in the Lenovo brand palette: Signature Red accents on neutral dark greys. It covers the terminal, GTK apps, the top bar, the dock, the lock screen, the login screen and the boot splash.

> **Unofficial.** This project is not affiliated with, endorsed by, or supported by Lenovo. "Lenovo" and "Think" are trademarks of Lenovo. The repo contains colour values only: no logos, fonts or images.

<!-- ![Desktop](docs/screenshots/desktop.png) — add screenshots, see docs/screenshots/README.md -->

## What's included

| Component | What it does | Works on |
|---|---|---|
| `terminal` | [Ghostty](https://ghostty.org) theme, tmux colours, [btop](https://github.com/aristocratos/btop) theme | Anywhere |
| `gtk` | Accent and surface colours for GTK4/libadwaita and GTK3 apps | Any GNOME (GTK ≥ 4.20) |
| `shell` | GNOME Shell extension: dark top bar with a red Activities pill, popups, lock screen | GNOME Shell 50 |
| `desktop` | Dark mode, red accent, brand font, optional wallpaper | Any GNOME |
| `dock` | Dark dock with red running-app dots | Ubuntu Dock / Dash to Dock |
| `--gdm` | Login screen: same colours, font and wallpaper | Ubuntu / Debian with Yaru |
| `--plymouth` | Boot splash: wallpaper or dark background, red progress bar | Any Plymouth distro; tested on Ubuntu |

Tested on **Ubuntu 26.04 LTS** (GNOME 50, Yaru). The core components should work on other GNOME distros but haven't been tested there.

## Install

```sh
git clone https://github.com/garethsprice/lenovo-gnome-theme
cd lenovo-gnome-theme
./install.sh                                   # user-level components, no sudo
./install.sh --wallpaper ~/Pictures/think.jpg  # also set a wallpaper
./install.sh --gdm --plymouth --wallpaper ~/Pictures/think.jpg   # everything (asks for sudo)
```

Log out and back in once so GNOME loads the shell extension. After that, running `./install.sh` again applies updates without logging out.

### Options

```
--only LIST          Comma-separated subset: terminal,gtk,shell,desktop,dock
--wallpaper PATH     Image for the desktop, login screen and boot splash
--font NAME          Font family (default: GothamSSm, then Gotham, then Montserrat)
--font-size N        Interface font size (default: 10)
--install-deps       apt install fonts-montserrat if no brand font is found
--gdm                Also theme the login screen (uses sudo)
--plymouth           Also theme the boot splash (uses sudo, rebuilds the initramfs)
--early-kms MODULE   With --plymouth: load a GPU driver early (see below)
```

### Fonts

Lenovo's guidelines use **Gotham**: Bold for headlines and Book for body text. Gotham is a commercial typeface from Hoefler&Co, so it isn't included; licences are sold at [typography.com](https://www.typography.com/fonts/gotham). A copy labelled "personal use" is also available from [dfonts.org](https://www.dfonts.org/fonts/gotham-font-family/), but its licence status is unclear: the site doesn't show permission from Hoefler&Co to distribute it, so check before relying on it. If you have a licensed copy installed, preferably the ScreenSmart cut (`GothamSSm`), the installer uses it. Otherwise it falls back to **Montserrat**, which is free, in Ubuntu's repos as `fonts-montserrat`, and the guidelines' own alternate for web applications. Monospace and terminal fonts aren't changed.

### Wallpaper

None is bundled. Pass any image with `--wallpaper`. Without one, the login screen and boot splash use a plain dark grey background.

- **Official:** Lenovo publishes desktop wallpapers and virtual backgrounds on its [Branded Screens](https://brandworld.lenovo.com/templates-resources/branded-screens/) page. It's intended for Lenovo employees and agencies and needs a sign-in.
- **Elsewhere:** Lenovo and ThinkPad wallpapers, often at higher resolutions such as 4K, are shared on various wallpaper sites. Check the terms for any image you download.

### Boot splash doesn't appear, or appears late?

On some multi-GPU machines, the firmware treats a card with no monitor attached as the boot display. The splash then has nothing to draw on until the real GPU driver loads, which can be the last few seconds of boot. Adding the driver to the initramfs fixes it:

```sh
./install.sh --plymouth --early-kms amdgpu   # or i915, nouveau, …
```

This makes the initramfs bigger (by about 35 MB for amdgpu). The previous initramfs is kept as `/boot/initrd.img-<kernel>.lenovo-gnome-theme.bak`. If the machine won't boot, press `e` in GRUB, add that suffix to the `initrd` line, and boot with Ctrl-X.

## Uninstall

```sh
./uninstall.sh
```

This restores every GNOME setting the installer changed and removes the files and config blocks it added. If the login screen or boot splash were installed, it reverts those too (asks for sudo).

## How it works

- **Nothing is overwritten.** The installer adds clearly marked blocks (`>>> lenovo-gnome-theme >>>`) to `gtk.css`, `~/.tmux.conf` and the Ghostty config, and `uninstall.sh` removes only those blocks. It saves the original value of each GNOME setting to `~/.local/state/lenovo-gnome-theme/`.
- **The top bar** is styled by a tiny extension that only contains CSS, because GNOME Shell has no user stylesheet. It also runs on the lock screen, where extensions are off by default.
- **The login screen** theme is built on your machine from the installed Yaru theme with `lenovo-gdm.css` added on top, then selected through `update-alternatives`. After a major GNOME or Yaru upgrade, re-run `./install.sh --gdm` to rebuild it.
- **The boot splash** is a Plymouth `two-step` theme. The installer adds the font (and an optional GPU driver) to the initramfs, using either dracut or initramfs-tools, whichever the system uses.
- **Desktop icons fix:** on Ubuntu, the desktop icons extension (DING) draws a transparent GTK3 window over the wallpaper. `gtk-3.0.css` keeps that window transparent so the wallpaper still shows.

## Releases

```sh
make release   # builds dist/lenovo-gnome-theme-<version>.tar.gz and dist/lenovo-gnome-theme-plymouth-<version>.tar.gz
make lint      # shellcheck
```

The version comes from `VERSION`. The full archive is `git archive` of `HEAD` when the tree is clean, otherwise the working tree. The Plymouth archive is a self-contained boot-splash theme (generic font, dark background, stock spinner images under GPL-2+) for anyone who only wants the splash. It needs `plymouth-theme-spinner` installed on the machine that builds it.

## Palette

See [palette.md](palette.md) for the brand colours, the derived ones, and contrast notes.

## Licence

MIT, see [LICENSE](LICENSE). The login screen theme is built from Yaru on your machine, and no Yaru files are included here; see [NOTICE](NOTICE).
