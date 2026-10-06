-- Read/advance only an isolated copy of the user's failed Old Man checkpoint.
assert(os.getenv('IRONMON_TUTORIAL_QA')=='1','tutorial test requires isolated QA')
local marker=assert(io.open('../data/.qa-allow','r'));marker:close()
local original=dofile
local inspected=false
dofile=function(path)
    local result=original(path)
    if path:match('Program%.lua$') then
        local mainLoop=Program.mainLoop
        Program.mainLoop=function()
            mainLoop()
            local R=MiyooRules
            if not inspected and R.loaded then
                inspected=true
                console.log('TUTORIAL SNAPSHOT',string.format('flags=%x outcome=%d callback=%08x map=%s inBattle=%s tutorial=%s',
                    memory.read_u32_le(GameSettings.gBattleTypeFlags),memory.read_u8(GameSettings.gBattleOutcome),
                    memory.read_u32_le(0x030030f4),tostring(Program.GameData.mapId),tostring(Battle.inBattleScreen),tostring(Program.inCatchingTutorial)))
                for slot=1,6 do
                    local p=TrackerAPI.getPlayerPokemon(slot)
                    if p then console.log('PARTY',slot,p.pokemonID,p.curHP,p.stats.hp) end
                end
                assert((memory.read_u32_le(GameSettings.gBattleTypeFlags)&0x200)~=0 and
                    memory.read_u8(GameSettings.gBattleOutcome)==7,'checkpoint is not the failed Old Man catch')
                assert(R.routeName():find('Viridian',1,true),'checkpoint is outside Viridian')
                assert(not R.ended and not R.pending,'repaired copy remains blocked')
            end
            if miyoo.frame()==290 then
                assert(inspected and not R.ended and not R.pending,'resume retriggered the capture guard')
                console.log('PASS: repaired Old Man checkpoint resumes without changing routes or creating a capture')
            end
            -- Close post-demo text with actual buttons, without moving the player.
            miyoo.setButtons(miyoo.frame()%30<3 and 256 or 0)
        end
    end
    return result
end
original('../bootstrap.lua')
