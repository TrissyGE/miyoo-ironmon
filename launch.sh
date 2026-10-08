#!/bin/sh
cd "${IRONMON_ROOT:-/mnt/SDCARD/App/IronMON}" || exit 1
root="$PWD"
export LD_LIBRARY_PATH=/customer/lib:/config/lib:/mnt/SDCARD/miyoo/lib:/mnt/SDCARD/.tmp_update/lib:/mnt/SDCARD/.tmp_update/lib/parasyte
export LD_PRELOAD=/mnt/SDCARD/miyoo/lib/libpadsp.so
start_cache() {
    IRONMON_ROOT="$root" nohup nice -n 19 sh "$root/seed-cache.sh" >"$root/data/cache-worker.log" 2>&1 </dev/null &
}
status_pid=
stop_status() {
    [ -z "$status_pid" ] || { kill "$status_pid" 2>/dev/null; wait "$status_pid" 2>/dev/null; }
    status_pid=
}
trap 'stop_status' EXIT
trap 'exit 1' INT TERM HUP
prepare_new_run() {
    (cd "$root/tracker" && exec ../ironmon --status 'Preparing a new IronMON run...' >../data/status.log 2>&1) &
    status_pid=$!
    new_run
    result=$?
    stop_status
    return "$result"
}
recover_transition() {
    [ -f data/transition.txt ] || return 0
    phase=;archive=;attempt=
    { read -r phase;read -r archive;read -r attempt; } <data/transition.txt
    case "$archive" in data/runs/run-*) ;; *) return 1 ;; esac
    case "$attempt" in ''|*[!0-9]*) return 1 ;; esac
    if [ "$phase" = installing ];then
        mkdir -p data/interrupted
        for extension in gba gba.log srm state tdat rules;do
            if [ -f "data/current.$extension" ];then mv "data/current.$extension" "data/interrupted/current.$extension" || return 1;fi
            if [ -f "$archive/current.$extension" ];then cp "$archive/current.$extension" "data/current.$extension" || return 1;fi
        done
        if [ -d data/cache/ready-1 ];then mv data/cache/ready-1 "data/cache/interrupted-$(date +%Y%m%d-%H%M%S)" || return 1;fi
    elif [ "$phase" = archiving ];then
        for extension in gba gba.log srm state tdat rules;do
            if [ -f "$archive/current.$extension" ];then mv "$archive/current.$extension" "data/current.$extension" || return 1;fi
        done
    else return 1;fi
    echo "$attempt" >data/attempt.txt
    sync
    rm -f data/transition.txt
}
set_transition() {
    { echo "$1";echo "$archive";echo "$attempt"; } >data/transition.tmp
    mv data/transition.tmp data/transition.txt
    sync
}
new_run() {
    while [ ! -s data/cache/ready-1/current.gba ];do
        if [ -s data/cache/ready-2/current.gba ];then mv data/cache/ready-2 data/cache/ready-1;break;fi
        if [ ! -d data/cache/worker.lock ];then IRONMON_ROOT="$root" sh ./seed-cache.sh || return 1
        else
            owner=0;[ ! -f data/cache/worker.lock/pid ] || read -r owner <data/cache/worker.lock/pid
            if [ "$owner" -gt 1 ] 2>/dev/null && [ -r "/proc/$owner/cmdline" ] && grep -q seed-cache.sh "/proc/$owner/cmdline";then sleep 1
            else IRONMON_ROOT="$root" sh ./seed-cache.sh || return 1;fi
        fi
    done
    read -r expected <data/cache/ready-1/rom.sha1
    actual=$(sha1sum data/cache/ready-1/current.gba);actual=${actual%% *}
    [ "$expected" = "$actual" ] || return 1
    attempt=0;[ ! -f data/attempt.txt ] || read -r attempt <data/attempt.txt
    case "$attempt" in ''|*[!0-9]*) attempt=0 ;; esac
    mkdir -p data/runs
    archive="data/runs/run-$attempt-$(date +%Y%m%d-%H%M%S)"
    mkdir "$archive" || return 1
    set_transition archiving || return 1
    for extension in gba gba.log srm state tdat rules;do
        if [ -f "data/current.$extension" ];then mv "data/current.$extension" "$archive/current.$extension" || return 1;fi
    done
    set_transition installing || return 1
    for extension in gba gba.log state;do mv "data/cache/ready-1/current.$extension" "data/current.$extension" || return 1;done
    rm -f data/cache/ready-1/rom.sha1
    rmdir data/cache/ready-1
    if [ -d data/cache/ready-2 ];then mv data/cache/ready-2 data/cache/ready-1;fi
    echo "$((attempt+1))" >data/attempt.txt
    sync
    rm -f data/transition.txt
    # Only our fixed archive subtree is pruned; retain eight completed runs.
    keep=8
    configured=$(sed -n 's/^backup_count=//p' settings.ini)
    case "$configured" in ''|*[!0-9]*) ;; *) if [ "$configured" -gt 0 ] && [ "$configured" -le 50 ];then keep="$configured";fi ;; esac
    for dir in $(ls -1dt data/runs/run-* 2>/dev/null);do
        if [ "$keep" -gt 0 ];then keep=$((keep-1));else
            case "$dir" in data/runs/run-*) rm -rf "$dir" ;; esac
        fi
    done
    sync
}
recover_transition || exit 1
if [ "$1" = '--recover-only' ];then exit 0;fi
if [ "$1" = '--prepare-cache' ];then IRONMON_ROOT="$root" sh ./seed-cache.sh;exit $?;fi
if [ "$1" = '--new-run' ] || [ ! -s data/current.gba ];then prepare_new_run || exit 1;fi
[ -f data/attempt.txt ] || echo 1 >data/attempt.txt
start_cache
while :;do
    cd "$root/tracker" || exit 1
    ../ironmon /mnt/SDCARD/RetroArch/.retroarch/cores/gpsp_libretro.so ../data/current.gba >../data/frontend.log 2>&1
    result=$?
    cd "$root" || exit 1
    if [ "$result" -eq 42 ];then prepare_new_run || break;start_cache
    else
        sync
        if [ "$result" -ne 0 ];then /mnt/SDCARD/.tmp_update/bin/infoPanel --title IronMON --message 'IronMON stopped. See App/IronMON/data/frontend.log';fi
        start_cache;exit "$result"
    fi
done
/mnt/SDCARD/.tmp_update/bin/infoPanel --title IronMON --message 'Seed preparation failed. See App/IronMON/data/cache-worker.log'
exit 1
