#!/bin/sh
# Each seed gets its own emulated lab state and a matching ROM hash.
cd "${IRONMON_ROOT:-/mnt/SDCARD/App/IronMON}" || exit 1
mkdir -p data/cache
if [ -d data/cache/worker.lock ];then
    owner=0;[ ! -f data/cache/worker.lock/pid ] || read -r owner <data/cache/worker.lock/pid
    case "$owner" in ''|*[!0-9]*) owner=0 ;; esac
    if [ "$owner" -gt 1 ] && [ -r "/proc/$owner/cmdline" ] && grep -q seed-cache.sh "/proc/$owner/cmdline";then exit 0;fi
    rm -f data/cache/worker.lock/pid
    rmdir data/cache/worker.lock 2>/dev/null || exit 1
fi
mkdir data/cache/worker.lock 2>/dev/null || exit 0
echo "$$" >data/cache/worker.lock/pid
trap 'rm -f data/cache/worker.lock/pid; rmdir data/cache/worker.lock 2>/dev/null' EXIT
trap 'exit 1' INT TERM HUP
for number in 1 2; do
    [ -s "data/cache/ready-$number/current.gba" ] && continue
    stage="data/cache/build-$number"
    mkdir -p "$stage/data" "$stage/tracker"
    # The SD card is FAT32, so stage helpers are real copies rather than symlinks.
    cp prepare.lua "$stage/prepare.lua"
    cp ironmon "$stage/ironmon"
    ./runtime/bin/java -Xmx64m -Djava.awt.headless=true -jar PokeRandoZX.jar cli \
        -s standard.rnqs -i source-qol.gba -o "$stage/data/current.gba" -l >data/cache/randomizer.log 2>&1 || exit 1
    absolute="$PWD/$stage"
    (cd "$absolute/tracker" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        IRONMON_BOOTSTRAP=../prepare.lua IRONMON_PREPARING=1 \
        ../ironmon /mnt/SDCARD/RetroArch/.retroarch/cores/gpsp_libretro.so \
        ../data/current.gba 15000 >../prepare.log 2>&1)
    result=$?
    if [ "$result" -ne 43 ] || [ ! -s "$stage/data/lab.state" ]; then
        echo "Lab preparation failed ($result)" >>data/cache/randomizer.log
        exit 1
    fi
    hash=$(sha1sum "$stage/data/current.gba");hash=${hash%% *}
    read -r statehash <"$stage/data/lab.sha1"
    [ "$hash" = "$statehash" ] || exit 1
    mv "$stage/data/lab.state" "$stage/data/current.state"
    mv "$stage/data/lab.sha1" "$stage/data/rom.sha1"
    mv "$stage/data" "data/cache/ready-$number"
done
