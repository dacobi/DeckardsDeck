#!/bin/sh

# Helper for shell.qml: the wallpaper that ships with the shell, for a first run.
#
#   default-wallpaper.sh seed <bundled-file> <wallpaper-folder>
#
# Copies the bundled picture into the wallpaper folder (the one the picker
# lists, ~/Pictures/Wallpapers by default) so it shows up in the picker with a
# thumbnail like any other wallpaper, and prints the path to use. An existing
# copy is never overwritten (you may have edited or renamed over it). If the
# folder can't be made or written to, it prints the bundled file's own path
# instead, so the desktop still gets a wallpaper. Prints nothing (exit 1) only
# when the bundled file itself is missing.

mode="$1"

seed_one() {
    f="$1"
    d="$2"
    [ -f "$f" ] || return 1
    n=$(basename "$f")
    if [ -f "$d/$n" ]; then
        return 0
    fi
    # Copied under a temp name and moved into place, so the folder
    # watcher never sees (and the picker never lists) half a picture.
    if cp "$f" "$d/.$n.tmp" 2>/dev/null && mv "$d/.$n.tmp" "$d/$n" 2>/dev/null; then
        return 0
    fi
    rm -f "$d/.$n.tmp" 2>/dev/null
    return 1
}

case "$mode" in
    seed)
        src="$2"
        dir="$3"
        [ -f "$src" ] || exit 1
        name=$(basename "$src")
        if [ -n "$dir" ] && mkdir -p "$dir" 2>/dev/null; then
            srcdir=$(dirname "$src")
            repodir=$(cd "$(dirname "$0")/../../.." 2>/dev/null && pwd)
            for extra in "$srcdir"/*.jpg "$repodir"/assets/*.jpg; do
                [ -f "$extra" ] && seed_one "$extra" "$dir"
            done
            if seed_one "$src" "$dir"; then
                printf '%s' "$dir/$name"
                exit 0
            fi
        fi
        printf '%s' "$src"
        ;;
    *)
        echo "usage: $0 seed <bundled-file> <wallpaper-folder>" >&2
        exit 2
        ;;
esac
