#!/bin/sh
# Only the verified release archives listed in store/dependencies.tsv are used.
# Run/Tracker files and user-supplied ROM/BIOS are never overwritten here.
cd "$(dirname "$0")/.." || exit 1
root="$PWD"
sd=/mnt/SDCARD
curl="$sd/.tmp_update/bin/curl"
fail() { printf '%s\n' "$1" >&2; exit 1; }
sha_matches() {
    [ -f "$1" ] || return 1
    digest=$($2 "$1") || return 1
    [ "${digest%% *}" = "$3" ]
}
[ -s source.gba ] || fail 'Copy your unmodified FireRed USA Rev 1 ROM to App/IronMON-Mixtape/source.gba.'
[ -s "$sd/BIOS/gba_bios.bin" ] || fail 'Copy your GBA BIOS to BIOS/gba_bios.bin on the SD card.'
sha_matches source.gba sha1sum dd5945db9b930750cb39d00c84da8571feebf417 || fail 'source.gba must be unmodified FireRed USA Rev 1 (v1.1).'
sha_matches "$sd/BIOS/gba_bios.bin" sha1sum 300c20df6731a33952ded8c436f7f186d25d3492 || fail 'BIOS/gba_bios.bin is not the required GBA BIOS.'
for file in 'RetroArch/.retroarch/cores/gpsp_libretro.so' '.tmp_update/lib/parasyte/libatomic.so.1' '.tmp_update/bin/infoPanel' '.tmp_update/bin/curl'; do
    [ -s "$sd/$file" ] || fail "Missing Onion file: $file. See INSTALL.md in this app's folder."
done
available=$(df -k "$sd" | awk 'END {print $4}')
case "$available" in ''|*[!0-9]*) fail 'Could not check free space on the SD card.' ;; esac
[ "$available" -ge 358400 ] || fail 'IronMON setup needs at least 350 MiB free on the SD card.'

cache="$root/data/store-downloads"
lock="$root/data/.store-setup-lock"
stage="$root/data/.store-setup-stage"
mkdir -p "$cache" || fail 'Could not create the setup download folder.'
if ! mkdir "$lock" 2>/dev/null; then
    owner=
    [ ! -f "$lock/pid" ] || read -r owner < "$lock/pid"
    case "$owner" in
        ''|*[!0-9]*) ;;
        *) if [ -r "/proc/$owner/cmdline" ] && grep -q 'store/setup.sh' "/proc/$owner/cmdline"; then
               fail 'IronMON setup is already running.'
           fi ;;
    esac
    rm -f "$lock/pid"
    rmdir "$lock" && mkdir "$lock" || fail 'Could not reopen the setup staging folder.'
fi
printf '%s\n' "$$" > "$lock/pid"
cleanup() {
    rm -rf "$stage"
    rm -f "$lock/pid"
    rmdir "$lock" 2>/dev/null
}
trap 'cleanup' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$stage"
mkdir -p "$stage" || fail 'Could not create the setup staging folder.'

while read -r key name digest url; do
    dest="$cache/$name"
    if ! sha_matches "$dest" sha256sum "$digest"; then
        printf 'Downloading %s\n' "$name"
        "$curl" --fail --location --silent --show-error --retry 2 \
            --proto '=https' --proto-redir '=https' --cacert "$root/store/cacert.pem" \
            --connect-timeout 15 --max-time 240 --max-filesize 104857600 \
            --output "$dest.part" "$url" || fail 'Setup download failed. Check Wi-Fi, device date/time and data/store-setup.log.'
        sha_matches "$dest.part" sha256sum "$digest" || fail "Checksum failed for $name. Reopen IronMON to retry."
        mv "$dest.part" "$dest" || fail 'Could not keep the verified download.'
    fi
    case "$key" in
        tracker) tracker="$dest" ;;
        randomizer) randomizer="$dest" ;;
        randomizer_license) upr_license="$dest" ;;
        java) java="$dest" ;;
        font) font="$dest" ;;
        patch) patch="$dest" ;;
        *) fail 'Unexpected setup dependency.' ;;
    esac
done < store/dependencies.tsv

unzip -q "$tracker" -d "$stage" || fail 'Could not extract Ironmon Tracker.'
unzip -q "$randomizer" -d "$stage" || fail 'Could not extract the randomizer.'
unzip -q "$font" -d "$stage" || fail 'Could not extract the font.'
# FAT32 cannot store the two links in the pinned ARM JRE. Extract their
# targets normally, then create copies at the original link paths.
tar -xzf "$java" -C "$stage" -X "$root/store/java-excludes.txt" || fail 'Could not extract the ARM Java runtime.'
read -r java_dir < store/java-root.txt
while read -r link target; do
    cp -R "$stage/$target" "$stage/$link" || fail 'Could not prepare Java files for FAT32.'
done < store/java-links.tsv
mv "$stage/$java_dir" "$stage/runtime" || fail 'Could not stage Java.'
mkdir "$stage/licenses" || fail 'Could not stage dependency notices.'
cp "$upr_license" "$stage/licenses/UPR-ZX-LICENSE.txt" &&
cp "$stage/README.txt" "$stage/licenses/UPR-ZX-README.txt" &&
cp "$stage/dejavu-sans-ttf-2.37/LICENSE" "$stage/licenses/DejaVu-LICENSE.txt" &&
cp "$stage/dejavu-sans-ttf-2.37/AUTHORS" "$stage/licenses/DejaVu-AUTHORS.txt" &&
cp "$stage/dejavu-sans-ttf-2.37/ttf/DejaVuSans.ttf" "$stage/font.ttf" || fail 'Could not stage font and notices.'
settings=settings.ini
[ -s "$settings" ] || settings=store/settings.default.ini
if [ ! -s source-qol.gba ]; then
    cp source.gba "$stage/source-qol.gba" &&
    ./store/ironmon-setup-lua store/prepare.lua "$stage/source-qol.gba" "$patch" store/rom-spec.lua "$settings" ||
        fail 'Could not prepare your ROM. Check settings.ini and data/store-setup.log.'
    sha256sum "$stage/source-qol.gba"
fi
chmod +x "$stage/runtime/bin/java" || fail 'Could not enable ARM Java.'
for file in Ironmon-Tracker/Ironmon-Tracker.lua Ironmon-Tracker/LICENSE.txt PokeRandoZX.jar runtime/LICENSE runtime/bin/java font.ttf; do
    [ -s "$stage/$file" ] || fail "Unexpected dependency archive layout: $file"
done

# Publish only absent paths. If power was lost between moves, retrying can
# finish the installation without replacing the files already put in place.
publish() {
    if [ ! -e "$2" ]; then
        mv "$1" "$2" || fail "Could not install $2. Reopen IronMON to retry."
    fi
}
publish "$stage/Ironmon-Tracker" tracker
for file in runtime PokeRandoZX.jar font.ttf licenses; do publish "$stage/$file" "$file"; done
if [ -s "$stage/source-qol.gba" ]; then publish "$stage/source-qol.gba" source-qol.gba; fi
if [ ! -e settings.ini ]; then
    cp store/settings.default.ini "$stage/settings.ini" || fail 'Could not prepare default settings.'
    publish "$stage/settings.ini" settings.ini
fi
for file in tracker/Ironmon-Tracker.lua runtime/bin/java PokeRandoZX.jar font.ttf source-qol.gba settings.ini; do
    [ -s "$file" ] || fail "Existing setup is incomplete: $file. See INSTALL.md in this app's folder."
done
sync
printf '1\n' > "$stage/ready" && mv "$stage/ready" data/store-ready-v1 || fail 'Could not finish setup.'
sync
printf 'IronMON setup completed.\n'
