# shellcheck shell=bash
# Shared helpers for install.sh / uninstall.sh. Sourced, not executed.
# shellcheck disable=SC2034  # variables are used by the scripts that source this

NAME=lenovo-gnome-theme
EXT_UUID=lenovo-gnome-theme@lenovo-gnome-theme
MARK_BEGIN=">>> $NAME >>>"
MARK_END="<<< $NAME <<<"

STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/$NAME
DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/$NAME
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
GSETTINGS_BACKUP=$STATE_DIR/gsettings.bak     # "schema key value" per line, first value wins
VALUES_BACKUP=$STATE_DIR/values.bak           # "name value" per line for non-gsettings values

info() { printf '\033[1;31m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have_schema() { gsettings list-schemas 2>/dev/null | grep -qx "$1"; }

# gset SCHEMA KEY VALUE: back up the current value (once), then set it.
gset() {
    local schema=$1 key=$2 value=$3
    have_schema "$schema" || { warn "skipping $schema $key (schema not installed)"; return 0; }
    mkdir -p "$STATE_DIR"
    if ! grep -q "^$schema $key " "$GSETTINGS_BACKUP" 2>/dev/null; then
        echo "$schema $key $(gsettings get "$schema" "$key")" >> "$GSETTINGS_BACKUP"
    fi
    gsettings set "$schema" "$key" "$value"
}

gsettings_restore() {
    [ -f "$GSETTINGS_BACKUP" ] || return 0
    local schema key value
    while read -r schema key value; do
        have_schema "$schema" && gsettings set "$schema" "$key" "$value"
    done < "$GSETTINGS_BACKUP"
    rm -f "$GSETTINGS_BACKUP"
}

# save_value NAME VALUE / get_value NAME: remember a non-gsettings original (once).
save_value() {
    mkdir -p "$STATE_DIR"
    grep -q "^$1 " "$VALUES_BACKUP" 2>/dev/null || echo "$1 $2" >> "$VALUES_BACKUP"
}
get_value() { sed -n "s/^$1 //p" "$VALUES_BACKUP" 2>/dev/null | head -1; }

# add_block FILE TOP|BOTTOM COMMENT_OPEN COMMENT_CLOSE CONTENT
# Wraps CONTENT in marker comments; replaces any existing block so re-running is idempotent.
add_block() {
    local file=$1 where=$2 open=$3 close=$4 content=$5 tmp
    mkdir -p "$(dirname "$file")"
    touch "$file"
    remove_block "$file"
    tmp=$(mktemp)
    {
        [ "$where" = BOTTOM ] && cat "$file"
        echo "$open$MARK_BEGIN$close"
        echo "$content"
        echo "$open$MARK_END$close"
        [ "$where" = TOP ] && cat "$file"
    } > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

remove_block() {
    [ -f "$1" ] || return 0
    sed -i "\#$MARK_BEGIN#,\#$MARK_END#d" "$1"
}

# Pick the brand font: Gotham ScreenSmart > Gotham > Montserrat (the guide's free web alternate).
pick_font() {
    local families
    families=$(fc-list : family | tr ',' '\n')
    if grep -qx 'GothamSSm' <<< "$families"; then echo GothamSSm
    elif grep -qx 'Gotham' <<< "$families"; then echo Gotham
    elif grep -qx 'Montserrat' <<< "$families"; then echo Montserrat
    else echo ""
    fi
}

# font_files FAMILY: regular and bold files, space-separated.
font_files() {
    local regular bold
    regular=$(fc-match -f '%{file}' "$1")
    bold=$(fc-match -f '%{file}' "$1:bold")
    if [ "$regular" = "$bold" ]; then echo "$regular"; else echo "$regular $bold"; fi
}

is_ubuntu_like() {
    [ -r /etc/os-release ] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in *" ubuntu "*|*" debian "*) return 0 ;; esac
    return 1
}
