#!/bin/sh

# Helper for LauncherBarService.qml: remembers the Launcher bar's visibility,
# monitor and pinned application icons across restarts, and parses dropped
# .desktop or executable files.
#
#   launcherbar-state.sh save <json>            save state JSON
#   launcherbar-state.sh load                   print saved state JSON
#   launcherbar-state.sh parse-desktop <path>.. print id|name|icon|exec lines

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/launcher-bar.json"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    parse-desktop)
        shift
        for p in "$@"; do
            p="${p#file://}"
            [ -e "$p" ] || continue
            base=$(basename "$p")
            case "$base" in
                *.desktop)
                    id="${base%.desktop}"
                    name=$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Name=//p;}' "$p" | head -n 1 | tr -d '\r')
                    icon=$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Icon=//p;}' "$p" | head -n 1 | tr -d '\r')
                    exec_cmd=$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Exec=//p;}' "$p" | head -n 1 | tr -d '\r' | sed 's/ *%[fFuUdDnNickvm]//g')
                    [ -n "$name" ] || name="$id"
                    printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$icon" "$exec_cmd"
                    ;;
                *)
                    if [ -f "$p" ] && [ -x "$p" ]; then
                        printf '%s\t%s\t%s\t%s\n' "$base" "$base" "application-x-executable" "\"$p\""
                    fi
                    ;;
            esac
        done
        ;;
    *)
        echo "usage: $0 save <json>|load|parse-desktop <path>..." >&2
        exit 2
        ;;
esac
