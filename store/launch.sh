#!/bin/sh
# Launcher installed by Mixtape. The normal PC installation has its own folder.
cd "$(dirname "$0")" || exit 1
root="$PWD"
export IRONMON_ROOT="$root"
export LD_LIBRARY_PATH=/customer/lib:/config/lib:/mnt/SDCARD/miyoo/lib:/mnt/SDCARD/.tmp_update/lib:/mnt/SDCARD/.tmp_update/lib/parasyte
export LD_PRELOAD=/mnt/SDCARD/miyoo/lib/libpadsp.so
panel=/mnt/SDCARD/.tmp_update/bin/infoPanel
mkdir -p data || exit 1

if [ ! -s data/store-ready-v1 ] || [ ! -s source-qol.gba ] || [ ! -s settings.ini ] ||
   [ ! -s tracker/Ironmon-Tracker.lua ] || [ ! -x runtime/bin/java ] || [ ! -s PokeRandoZX.jar ] || [ ! -s font.ttf ]; then
    # Keep the same Onion launcher screen while the first-run files are prepared.
    status_pid=
    stop_status() {
        if [ -n "$status_pid" ]; then
            kill "$status_pid" 2>/dev/null
            wait "$status_pid" 2>/dev/null
            status_pid=
        fi
    }
    trap 'stop_status' EXIT
    trap 'exit 1' HUP INT TERM
    if [ "$1" != '--setup-only' ] && [ -s source.gba ] && [ -s /mnt/SDCARD/BIOS/gba_bios.bin ]; then
        ./ironmon --status 'Setting up IronMON. Keep Wi-Fi on.' >data/store-status.log 2>&1 &
        status_pid=$!
    fi
    sh store/setup.sh >data/store-setup.log 2>&1
    result=$?
    stop_status
    if [ "$result" -ne 0 ]; then
        if [ "$1" != '--setup-only' ] && [ -x "$panel" ]; then
            "$panel" --title 'IronMON Setup' --message "$(tail -n 1 data/store-setup.log)"
        fi
        exit "$result"
    fi
fi
[ "$1" != '--setup-only' ] || exit 0
exec sh ./launch.sh "$@"
